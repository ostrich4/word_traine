class Word {
  final int? id;
  final int dictionaryId;
  final String word;
  final String translation;

  const Word({
    this.id,
    required this.dictionaryId,
    required this.word,
    required this.translation,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dictionary_id': dictionaryId,
      'word': word,
      'translation': translation,
    };
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: (map['id'] as num?)?.toInt(),
      dictionaryId: (map['dictionary_id'] as num).toInt(),
      word: map['word']?.toString() ?? '',
      translation: map['translation']?.toString() ?? '',
    );
  }
}
