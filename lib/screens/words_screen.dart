import 'dart:async';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/remote_words_service.dart';
import '../utils/word_count_text.dart';

class WordsViewModel extends ChangeNotifier {
  WordsViewModel({
    required this.database,
    required this.dictionaryId,
    RemoteWordsService? remoteService,
  }) : remoteService = remoteService ?? RemoteWordsService();

  final DatabaseHelper database;
  final int dictionaryId;
  final RemoteWordsService remoteService;

  List<Map<String, dynamic>> words = [];
  bool isLoading = false;
  bool isImporting = false;
  String? error;
  String? importError;

  Future<void> loadWords() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      words = await database.getWordsForDictionary(dictionaryId).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      error = 'Локальная база данных не ответила вовремя.';
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> addWord(String word, String translation) async {
    if (word.trim().isEmpty || translation.trim().isEmpty) return false;
    try {
      await database.addWord(dictionaryId, word, translation);
      await loadWords();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<int?> importDemoWords() async {
    if (isImporting) return 0;
    isImporting = true;
    importError = null;
    notifyListeners();
    try {
      final remoteWords = await remoteService.fetchDemoWords();
      var added = 0;
      for (final item in remoteWords) {
        final word = item['word'] ?? '';
        final translation = item['translation'] ?? '';
        if (!await database.wordExists(dictionaryId, word, translation)) {
          await database.addWord(dictionaryId, word, translation);
          added++;
        }
      }
      words = await database.getWordsForDictionary(dictionaryId);
      return added;
    } catch (e) {
      importError = e.toString();
      return null;
    } finally {
      isImporting = false;
      notifyListeners();
    }
  }
}

class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key, required this.dictionaryId, required this.dictionaryName});
  final int dictionaryId;
  final String dictionaryName;

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  static const _purple = Color(0xFF6750A4);
  late final WordsViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = WordsViewModel(database: DatabaseHelper.instance, dictionaryId: widget.dictionaryId)..loadWords();
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: vm,
        builder: (_, __) => Scaffold(
          backgroundColor: const Color(0xFFF7F5FA),
          appBar: AppBar(
            title: Text(widget.dictionaryName, style: const TextStyle(fontWeight: FontWeight.w800)),
            backgroundColor: const Color(0xFFF7F5FA),
            surfaceTintColor: Colors.transparent,
            actions: [
              vm.isImporting
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    )
                  : IconButton(
                      tooltip: 'Импортировать слова по REST',
                      onPressed: _importDemoWords,
                      icon: const Icon(Icons.cloud_download_outlined),
                    ),
            ],
          ),
          body: _body(),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addWord,
            backgroundColor: _purple,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить слово', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      );

  Widget _body() {
    if (vm.isLoading) return const Center(child: CircularProgressIndicator());
    if (vm.error != null) return _error();
    return RefreshIndicator(
      onRefresh: vm.loadWords,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
        children: [
          _header(),
          const SizedBox(height: 18),
          if (vm.words.isEmpty) _empty() else ...vm.words.map(_wordCard),
        ],
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_purple, Color(0xFF9274D2)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(17)),
            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 29),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.dictionaryName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(wordCountText(vm.words.length), style: const TextStyle(color: Colors.white70)),
          ])),
        ]),
      );

  Widget _wordCard(Map<String, dynamic> word) {
    final original = word['word']?.toString() ?? '';
    final translation = word['translation']?.toString() ?? '';
    final letter = original.isEmpty ? '?' : original[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE9E5EF))),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFEDE7F6), borderRadius: BorderRadius.circular(15)),
            child: Text(letter, style: const TextStyle(color: _purple, fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(original, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(translation, style: const TextStyle(color: Color(0xFF77717D))),
          ])),
          const Icon(Icons.translate_rounded, color: Color(0xFFAAA4B0), size: 20),
        ]),
      ),
    );
  }

  Widget _empty() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 42),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE9E5EF))),
        child: const Column(children: [
          Icon(Icons.translate_outlined, size: 60, color: Color(0xFFAAA4B0)),
          SizedBox(height: 14),
          Text('В словаре пока пусто', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text('Добавьте слово вручную или импортируйте демонстрационный набор через кнопку облака.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.4)),
        ]),
      );

  Widget _error() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 68, color: Color(0xFFD64545)),
            const SizedBox(height: 16),
            Text(vm.error!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: vm.loadWords, icon: const Icon(Icons.refresh_rounded), label: const Text('Повторить')),
          ]),
        ),
      );

  Future<void> _addWord() async {
    final word = TextEditingController();
    final translation = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новое слово'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: word, autofocus: true, decoration: const InputDecoration(labelText: 'Иностранное слово', hintText: 'Apple')),
          const SizedBox(height: 14),
          TextField(controller: translation, decoration: const InputDecoration(labelText: 'Перевод', hintText: 'Яблоко')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              final ok = await vm.addWord(word.text, translation.text);
              if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    word.dispose();
    translation.dispose();
  }

  Future<void> _importDemoWords() async {
    final added = await vm.importDemoWords();
    if (!mounted) return;
    final text = added == null
        ? (vm.importError ?? 'Не удалось импортировать слова.')
        : added == 0
            ? 'Все демонстрационные слова уже есть в словаре.'
            : 'Импорт завершён: добавлено ${wordCountText(added)}.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
