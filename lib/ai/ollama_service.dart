import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/database.dart';

// Talks to a local Ollama model through a same-origin proxy exposed by the
// StudyFlow launcher (and by the dev server) at /ai/*. Going through the proxy
// keeps the browser happy (no cross-origin request straight to Ollama).
class OllamaService {
  OllamaService({this.model = 'qwen2.5:0.5b'});

  final String model;

  // Keep prompts bounded so a giant note can't build a runaway request.
  static const int _maxPromptChars = 8000;

  Uri _u(String path) => Uri.base.resolve(path);

  Future<bool> available() async {
    try {
      final res =
          await http.get(_u('ai/health')).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body);
      return body is Map && body['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<String> generate(String prompt) async {
    final res = await http
        .post(_u('ai/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'model': model, 'prompt': prompt}))
        .timeout(const Duration(seconds: 120));
    if (res.statusCode != 200) {
      throw Exception('AI request failed (${res.statusCode})');
    }
    final body = jsonDecode(res.body);
    return (body is Map && body['response'] is String)
        ? body['response'] as String
        : '';
  }

  Future<List<({String question, String answer})>> makeFlashcards(String notes,
      {int count = 6}) async {
    final trimmed = notes.length > _maxPromptChars
        ? notes.substring(0, _maxPromptChars)
        : notes;
    final prompt = '''
You are a study assistant. From the notes below, write $count concise flashcards.
Respond with ONLY a JSON array, no prose, in exactly this shape:
[{"q":"question","a":"answer"}]

NOTES:
$trimmed
''';
    final raw = await generate(prompt);
    return parseFlashcards(raw);
  }

  Future<Map<String, dynamic>?> parseQuickAdd(
      String text, List<Course> courses) async {
    final names = courses.map((c) => c.name).join(', ');
    final trimmed =
        text.length > _maxPromptChars ? text.substring(0, _maxPromptChars) : text;
    final prompt = '''
Extract an assignment from this text: "$trimmed".
Known courses: $names.
Respond with ONLY JSON in this shape:
{"title":"...","course":"one of the known courses or empty","priority":"low|medium|high","dueInDays":number}
''';
    final raw = await generate(prompt);
    return parseQuickAddResponse(raw);
  }
}

// Pull flashcards out of a model response. Tolerant of surrounding prose and
// malformed output, and bounded so an oversized/misconfigured model reply can't
// flood the app: at most [maxCards], each field trimmed to [maxField] chars.
List<({String question, String answer})> parseFlashcards(String raw,
    {int maxCards = 50, int maxField = 2000}) {
  final start = raw.indexOf('[');
  final end = raw.lastIndexOf(']');
  if (start < 0 || end <= start) return [];
  try {
    final decoded = jsonDecode(raw.substring(start, end + 1));
    if (decoded is! List) return [];
    final out = <({String question, String answer})>[];
    for (final item in decoded) {
      if (out.length >= maxCards) break;
      if (item is Map && item['q'] != null && item['a'] != null) {
        final q = item['q'].toString().trim();
        final a = item['a'].toString().trim();
        if (q.isEmpty || a.isEmpty) continue;
        out.add((
          question: q.length > maxField ? q.substring(0, maxField) : q,
          answer: a.length > maxField ? a.substring(0, maxField) : a,
        ));
      }
    }
    return out;
  } catch (_) {
    return [];
  }
}

Map<String, dynamic>? parseQuickAddResponse(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    final obj = jsonDecode(raw.substring(start, end + 1));
    return obj is Map<String, dynamic> ? obj : null;
  } catch (_) {
    return null;
  }
}
