import 'dart:async';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../utils/word_count_text.dart';

class RepetitionViewModel extends ChangeNotifier {
  RepetitionViewModel(this.database);
  final DatabaseHelper database;

  List<Map<String, dynamic>> dueWords = [];
  int currentIndex = 0;
  bool showTranslation = false;
  bool isLoading = false;
  bool isSaving = false;
  String? error;

  bool get isCompleted => dueWords.isNotEmpty && currentIndex >= dueWords.length;
  Map<String, dynamic>? get currentWord => currentIndex >= 0 && currentIndex < dueWords.length ? dueWords[currentIndex] : null;

  Future<void> loadWords() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      dueWords = await database.getDueWords().timeout(const Duration(seconds: 15));
      currentIndex = 0;
      showTranslation = false;
    } on TimeoutException {
      error = 'Локальная база данных не ответила вовремя.';
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  void revealTranslation() {
    showTranslation = true;
    notifyListeners();
  }

  Future<void> submitRating(int rating) async {
    if (isSaving || currentWord == null) return;
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      final wordId = (currentWord!['id'] as num).toInt();
      await database.updateWordProgress(wordId, rating).timeout(const Duration(seconds: 15));

      if (rating == 0) {
        // «Снова»: перевод скрывается, но пользователь остаётся на том же слове.
        showTranslation = false;
      } else {
        currentIndex++;
        showTranslation = false;
      }
    } catch (e) {
      error = e.toString();
    }
    isSaving = false;
    notifyListeners();
  }
}

class RepetitionScreen extends StatefulWidget {
  const RepetitionScreen({super.key});
  @override
  State<RepetitionScreen> createState() => _RepetitionScreenState();
}

class _RepetitionScreenState extends State<RepetitionScreen> {
  static const _purple = Color(0xFF6750A4);
  late final RepetitionViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = RepetitionViewModel(DatabaseHelper.instance)..loadWords();
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
          backgroundColor: const Color(0xFFF8F7FB),
          appBar: AppBar(
            title: const Text('Повторение', style: TextStyle(fontWeight: FontWeight.w800)),
            backgroundColor: const Color(0xFFF8F7FB),
            surfaceTintColor: Colors.transparent,
          ),
          body: _body(),
        ),
      );

  Widget _body() {
    if (vm.isLoading) return const Center(child: CircularProgressIndicator());
    if (vm.error != null && vm.currentWord == null) return _errorState();
    if (vm.dueWords.isEmpty) return _emptyState();
    if (vm.isCompleted) return _completionState();
    return _study();
  }

  Widget _study() {
    final word = vm.currentWord!;
    final progress = (vm.currentIndex + 1) / vm.dueWords.length;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            children: [
              Row(children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(20),
                    backgroundColor: const Color(0xFFE6E0EC),
                    color: _purple,
                  ),
                ),
                const SizedBox(width: 14),
                Text('${vm.currentIndex + 1}/${vm.dueWords.length}', style: const TextStyle(color: _purple, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 34),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Container(
                  key: ValueKey('${vm.currentIndex}-${vm.showTranslation}'),
                  constraints: const BoxConstraints(minHeight: 300),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFEAE6F0)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 30, offset: const Offset(0, 12))],
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: const Color(0xFFF0EAF8), borderRadius: BorderRadius.circular(30)),
                      child: const Text('ВСПОМНИТЕ ПЕРЕВОД', style: TextStyle(color: _purple, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .7)),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      word['word']?.toString() ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 40, height: 1.1, fontWeight: FontWeight.w800, color: Color(0xFF28252D)),
                    ),
                    const SizedBox(height: 28),
                    if (!vm.showTranslation)
                      FilledButton.icon(
                        onPressed: vm.revealTranslation,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Показать перевод'),
                        style: FilledButton.styleFrom(backgroundColor: _purple, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                      )
                    else ...[
                      Container(height: 1, width: 80, color: const Color(0xFFE2DCE9)),
                      const SizedBox(height: 20),
                      Text(
                        word['translation']?.toString() ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 27, color: _purple, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ]),
                ),
              ),
              if (vm.showTranslation) ...[
                const SizedBox(height: 30),
                const Text('Насколько хорошо вы вспомнили слово?', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.65,
                  children: [
                    _rating('Снова', 'Повторить сейчас', Icons.refresh, const Color(0xFFD64545), const Color(0xFFFFEEEE), 0),
                    _rating('Тяжело', 'Через 1 день', Icons.sentiment_dissatisfied_outlined, const Color(0xFFE58A19), const Color(0xFFFFF4E5), 1),
                    _rating('Нормально', 'Через 3 дня', Icons.sentiment_satisfied_alt_outlined, const Color(0xFF3E8E57), const Color(0xFFEDF8F0), 2),
                    _rating('Легко', 'Через 7 дней', Icons.sentiment_very_satisfied_outlined, const Color(0xFF3B73C5), const Color(0xFFEDF3FC), 3),
                  ],
                ),
                if (vm.isSaving) const Padding(padding: EdgeInsets.only(top: 22), child: Center(child: CircularProgressIndicator())),
                if (vm.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(vm.error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD64545))),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _rating(String title, String subtitle, IconData icon, Color color, Color background, int rating) => Material(
        color: background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: vm.isSaving ? null : () => vm.submitRating(rating),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color.withValues(alpha: .75), fontSize: 11)),
              ])),
            ]),
          ),
        ),
      );

  Widget _emptyState() => _messageState(
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF3E8E57),
        background: const Color(0xFFEAF6ED),
        title: 'На сегодня всё!',
        text: 'Слов для повторения сейчас нет. Добавьте новые слова или вернитесь позже.',
        button: 'Вернуться к словарям',
      );

  Widget _completionState() => _messageState(
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF3E8E57),
        background: const Color(0xFFEAF6ED),
        title: 'Сессия завершена!',
        text: 'Вы успешно повторили ${wordCountText(vm.dueWords.length)}.',
        button: 'На главный экран',
      );

  Widget _errorState() => _messageState(
        icon: Icons.error_outline_rounded,
        color: const Color(0xFFD64545),
        background: const Color(0xFFFFEEEE),
        title: 'Не удалось загрузить слова',
        text: vm.error ?? 'Неизвестная ошибка',
        button: 'Повторить',
        onPressed: vm.loadWords,
      );

  Widget _messageState({
    required IconData icon,
    required Color color,
    required Color background,
    required String title,
    required String text,
    required String button,
    VoidCallback? onPressed,
  }) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 120, height: 120, decoration: BoxDecoration(color: background, shape: BoxShape.circle), child: Icon(icon, color: color, size: 68)),
              const SizedBox(height: 26),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
              const SizedBox(height: 9),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 15, height: 1.5)),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: onPressed ?? () => Navigator.pop(context),
                icon: Icon(onPressed == null ? Icons.arrow_back_rounded : Icons.refresh_rounded),
                label: Text(button),
                style: FilledButton.styleFrom(backgroundColor: _purple, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15)),
              ),
            ]),
          ),
        ),
      );
}
