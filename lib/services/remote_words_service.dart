import 'dart:convert';

import 'package:http/http.dart' as http;

/// Небольшой REST-клиент для демонстрации сетевого слоя лабораторной работы.
///
/// Сетевое подключение используется только для необязательного импорта
/// демонстрационных слов. После импорта слова сохраняются в SQLite и доступны
/// полностью офлайн.
class RemoteWordsService {
  static final Uri _demoWordsUri = Uri.parse(
    'https://raw.githubusercontent.com/ostrich4/word_traine/main/data/demo_words.json',
  );

  Future<List<Map<String, String>>> fetchDemoWords() async {
    final response = await http
        .get(_demoWordsUri)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'REST API вернул код ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! List) {
      throw const FormatException('Ожидался JSON-массив слов.');
    }

    final result = <Map<String, String>>[];

    for (final item in decoded) {
      if (item is! Map) continue;

      final word = item['word']?.toString().trim() ?? '';
      final translation = item['translation']?.toString().trim() ?? '';

      if (word.isEmpty || translation.isEmpty) continue;

      result.add({
        'word': word,
        'translation': translation,
      });
    }

    if (result.isEmpty) {
      throw const FormatException('REST API не вернул корректных слов.');
    }

    return result;
  }
}
