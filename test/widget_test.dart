import 'package:flutter_test/flutter_test.dart';
import 'package:word_trainer/models/word.dart';

void main() {
  test('Word model maps SQLite data correctly', () {
    final word = Word.fromMap({
      'id': 7,
      'dictionary_id': 2,
      'word': 'apple',
      'translation': 'яблоко',
    });

    expect(word.id, 7);
    expect(word.dictionaryId, 2);
    expect(word.word, 'apple');
    expect(word.translation, 'яблоко');
    expect(word.toMap()['dictionary_id'], 2);
  });
}
