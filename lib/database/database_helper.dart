import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Единая точка доступа к локальной SQLite-базе приложения.
///
/// На Android/iOS используется обычный sqflite, а в Chrome/Web —
/// sqflite_common_ffi_web. Основная функциональность после сохранения слов
/// полностью доступна офлайн.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();

  DatabaseHelper._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    String path;

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      path = 'word_trainer.db';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = join(dir.path, 'word_trainer.db');
    }

    _database = await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE dictionaries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE words(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            dictionary_id INTEGER NOT NULL,
            word TEXT NOT NULL,
            translation TEXT NOT NULL,
            FOREIGN KEY(dictionary_id)
              REFERENCES dictionaries(id)
              ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE progress(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER UNIQUE NOT NULL,
            ease_factor REAL NOT NULL DEFAULT 2.5,
            interval_days INTEGER NOT NULL DEFAULT 0,
            repetitions INTEGER NOT NULL DEFAULT 0,
            next_review_date TEXT,
            FOREIGN KEY(word_id)
              REFERENCES words(id)
              ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE study_sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER NOT NULL,
            studied_at TEXT NOT NULL,
            rating TEXT NOT NULL,
            FOREIGN KEY(word_id)
              REFERENCES words(id)
              ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS progress(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER UNIQUE,
              ease_factor REAL DEFAULT 2.5,
              interval_days INTEGER DEFAULT 0,
              repetitions INTEGER DEFAULT 0,
              next_review_date TEXT,
              FOREIGN KEY(word_id) REFERENCES words(id)
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS study_sessions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word_id INTEGER,
              studied_at TEXT,
              rating TEXT,
              FOREIGN KEY(word_id) REFERENCES words(id)
            )
          ''');
        }
      },
    );

    return _database!;
  }

  // =========================================================
  // СЛОВАРИ
  // =========================================================

  Future<List<Map<String, dynamic>>> getDictionaries() async {
    final db = await database;
    return db.query('dictionaries', orderBy: 'id DESC');
  }

  Future<int> addDictionary(String name) async {
    final db = await database;
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw ArgumentError('Название словаря не может быть пустым.');
    }

    return db.insert(
      'dictionaries',
      {'name': cleanName},
    );
  }

  Future<int> getWordCountForDictionary(int dictionaryId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM words
      WHERE dictionary_id = ?
      ''',
      [dictionaryId],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  // =========================================================
  // СЛОВА
  // =========================================================

  Future<List<Map<String, dynamic>>> getWordsForDictionary(
    int dictionaryId,
  ) async {
    final db = await database;
    return db.query(
      'words',
      where: 'dictionary_id = ?',
      whereArgs: [dictionaryId],
      orderBy: 'id DESC',
    );
  }

  Future<int> addWord(
    int dictionaryId,
    String word,
    String translation,
  ) async {
    final db = await database;
    final cleanWord = word.trim();
    final cleanTranslation = translation.trim();

    if (cleanWord.isEmpty || cleanTranslation.isEmpty) {
      throw ArgumentError('Слово и перевод должны быть заполнены.');
    }

    return db.insert(
      'words',
      {
        'dictionary_id': dictionaryId,
        'word': cleanWord,
        'translation': cleanTranslation,
      },
    );
  }

  Future<bool> wordExists(
    int dictionaryId,
    String word,
    String translation,
  ) async {
    final db = await database;
    final result = await db.query(
      'words',
      columns: ['id'],
      where: 'dictionary_id = ? AND word = ? AND translation = ?',
      whereArgs: [dictionaryId, word.trim(), translation.trim()],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  // =========================================================
  // СТАТИСТИКА ЗА ТЕКУЩУЮ НЕДЕЛЮ
  // =========================================================

  Future<List<int>> getWeeklyStudyStats() async {
    final db = await database;
    final counts = List<int>.filled(7, 0);
    final now = DateTime.now();

    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    // DISTINCT нужен, чтобы несколько нажатий «Снова» на одном слове
    // не увеличивали показатель изученных слов за день.
    final result = await db.rawQuery(
      '''
      SELECT
        date(studied_at) AS study_date,
        COUNT(DISTINCT word_id) AS count
      FROM study_sessions
      WHERE datetime(studied_at) >= datetime(?)
      GROUP BY date(studied_at)
      ORDER BY study_date
      ''',
      [monday.toIso8601String()],
    );

    for (final row in result) {
      final dateString = row['study_date'] as String?;
      if (dateString == null) continue;

      final date = DateTime.parse(dateString);
      final index = date.weekday - 1;

      if (index >= 0 && index < 7) {
        counts[index] = (row['count'] as num).toInt();
      }
    }

    return counts;
  }

  // =========================================================
  // ИНТЕРВАЛЬНОЕ ПОВТОРЕНИЕ
  // =========================================================

  Future<List<Map<String, dynamic>>> getDueWords() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    return db.rawQuery(
      '''
      SELECT
        words.id,
        words.dictionary_id,
        words.word,
        words.translation,
        progress.next_review_date,
        progress.ease_factor,
        progress.interval_days,
        progress.repetitions
      FROM words
      LEFT JOIN progress ON words.id = progress.word_id
      WHERE
        progress.id IS NULL
        OR datetime(progress.next_review_date) <= datetime(?)
      ORDER BY words.id
      ''',
      [now],
    );
  }

  Future<int> getDueWordCount() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM words
      LEFT JOIN progress ON words.id = progress.word_id
      WHERE
        progress.id IS NULL
        OR datetime(progress.next_review_date) <= datetime(?)
      ''',
      [now],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Сохраняет результат ответа и рассчитывает дату следующего повторения.
  ///
  /// Оценки:
  /// 0 — «Снова»: повторить это же слово сейчас;
  /// 1 — «Тяжело»: первый интервал 1 день, затем растёт медленно;
  /// 2 — «Нормально»: первый интервал 3 дня, затем умножается на easeFactor;
  /// 3 — «Легко»: первый интервал 7 дней, затем растёт быстрее.
  Future<void> updateWordProgress(
    int wordId,
    int rating,
  ) async {
    if (rating < 0 || rating > 3) {
      throw ArgumentError.value(rating, 'rating', 'Допустимы оценки от 0 до 3.');
    }

    final db = await database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      final result = await txn.query(
        'progress',
        where: 'word_id = ?',
        whereArgs: [wordId],
      );

      double easeFactor = 2.5;
      int previousInterval = 0;
      int repetitions = 0;

      if (result.isNotEmpty) {
        easeFactor =
            (result.first['ease_factor'] as num?)?.toDouble() ?? 2.5;
        previousInterval =
            (result.first['interval_days'] as num?)?.toInt() ?? 0;
        repetitions =
            (result.first['repetitions'] as num?)?.toInt() ?? 0;
      }

      int newInterval;

      switch (rating) {
        case 0:
          repetitions = 0;
          newInterval = 0;
          easeFactor -= 0.20;
          break;

        case 1:
          repetitions++;
          if (previousInterval <= 0) {
            newInterval = 1;
          } else {
            final multiplied = (previousInterval * 1.2).ceil();
            newInterval = multiplied > previousInterval
                ? multiplied
                : previousInterval + 1;
          }
          easeFactor -= 0.15;
          break;

        case 2:
          repetitions++;
          if (previousInterval <= 0) {
            newInterval = 3;
          } else {
            newInterval = (previousInterval * easeFactor).round();
            if (newInterval < 3) newInterval = 3;
          }
          break;

        case 3:
          repetitions++;
          if (previousInterval <= 0) {
            newInterval = 7;
          } else {
            newInterval = (previousInterval * easeFactor * 1.3).round();
            if (newInterval < 7) newInterval = 7;
          }
          easeFactor += 0.15;
          break;

        default:
          // Проверка выше гарантирует, что сюда выполнение не попадёт.
          newInterval = 0;
      }

      if (easeFactor < 1.3) {
        easeFactor = 1.3;
      }

      final nextReviewDate = now
          .add(Duration(days: newInterval))
          .toIso8601String();

      await txn.insert(
        'progress',
        {
          'word_id': wordId,
          'ease_factor': easeFactor,
          'interval_days': newInterval,
          'repetitions': repetitions,
          'next_review_date': nextReviewDate,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.insert(
        'study_sessions',
        {
          'word_id': wordId,
          'studied_at': now.toIso8601String(),
          'rating': rating.toString(),
        },
      );
    });
  }
}
