import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/database.dart';

// Talks to a local Ollama model through a same-origin proxy exposed by the
// StudyFlow launcher (and by the dev server) at /ai/*. Going through the proxy
// keeps the browser happy (no cross-origin request straight to Ollama).
class OllamaService {
  OllamaService({this.model = 'qwen2.5:0.5b'});

  final String model;

  Uri _u(String path) => Uri.base.resolve(path);

  // Is a local model reachable right now?
  Future<bool> available() async {
    try {
      final res = await http
          .get(_u('ai/health'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body);
      return body is Map && body['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  // Raw text completion.
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

  // Ask the model to turn notes into question/answer flashcards.
  Future<List<({String question, String answer})>> makeFlashcards(
      String notes,
      {int count = 6}) async {
    final prompt = '''
You are a study assistant. From the notes below, write $count concise flashcards.
Respond with ONLY a JSON array, no prose, in exactly this shape:
[{"q":"question","a":"answer"}]

NOTES:
$notes
''';
    final raw = await generate(prompt);
    return _parseCards(raw);
  }

  // Pull structured fields out of a free-text assignment description.
  Future<Map<String, dynamic>?> parseQuickAdd(
      String text, List<Course> courses) async {
    final names = courses.map((c) => c.name).join(', ');
    final prompt = '''
Extract an assignment from this text: "$text".
Known courses: $names.
Respond with ONLY JSON in this shape:
{"title":"...","course":"one of the known courses or empty","priority":"low|medium|high","dueInDays":number}
''';
    final raw = await generate(prompt);
    final obj = _extractJsonObject(raw);
    return obj;
  }

  List<({String question, String answer})> _parseCards(String raw) {
    final start = raw.indexOf('[');
    final end = raw.lastIndexOf(']');
    if (start < 0 || end <= start) return [];
    try {
      final list = jsonDecode(raw.substring(start, end + 1));
      if (list is! List) return [];
      final out = <({String question, String answer})>[];
      for (final item in list) {
        if (item is Map && item['q'] != null && item['a'] != null) {
          out.add((
            question: item['q'].toString().trim(),
            answer: item['a'].toString().trim(),
          ));
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic>? _extractJsonObject(String raw) {
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
}
