import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/ai/ollama_service.dart';

void main() {
  group('parseFlashcards', () {
    test('reads a clean JSON array', () {
      final cards = parseFlashcards('[{"q":"1+1?","a":"2"},{"q":"cap?","a":"Paris"}]');
      expect(cards.length, 2);
      expect(cards.first.question, '1+1?');
      expect(cards.last.answer, 'Paris');
    });

    test('tolerates prose around the JSON', () {
      final cards = parseFlashcards(
          'Sure! Here you go:\n[{"q":"a","a":"b"}]\nHope that helps.');
      expect(cards.single.question, 'a');
    });

    test('malformed or missing JSON yields no cards, never throws', () {
      expect(parseFlashcards('not json at all'), isEmpty);
      expect(parseFlashcards('[{"q":"only question"}]'), isEmpty);
      expect(parseFlashcards('[{"q":"","a":""}]'), isEmpty);
      expect(parseFlashcards(''), isEmpty);
      expect(parseFlashcards('[garbage,,,]'), isEmpty);
    });

    test('an oversized reply is capped', () {
      final huge = jsonEncode(
          List.generate(500, (i) => {'q': 'q$i', 'a': 'a$i'}));
      final cards = parseFlashcards(huge);
      expect(cards.length, 50);
    });

    test('absurdly long fields are trimmed', () {
      final big = 'x' * 10000;
      final cards = parseFlashcards('[{"q":"$big","a":"$big"}]', maxField: 100);
      expect(cards.single.question.length, 100);
      expect(cards.single.answer.length, 100);
    });
  });

  group('parseQuickAddResponse', () {
    test('reads an object, ignoring surrounding text', () {
      final obj = parseQuickAddResponse(
          'ok: {"title":"Essay","course":"History","priority":"high","dueInDays":5} done');
      expect(obj, isNotNull);
      expect(obj!['title'], 'Essay');
      expect(obj['dueInDays'], 5);
    });

    test('returns null on junk', () {
      expect(parseQuickAddResponse('no braces here'), isNull);
      expect(parseQuickAddResponse('{bad json}'), isNull);
    });
  });
}
