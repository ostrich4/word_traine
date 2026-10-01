import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../utils/word_count_text.dart';
import 'repetition_screen.dart';
import 'words_screen.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this.database);
  final DatabaseHelper database;

  List<Map<String, dynamic>> dictionaries = [];
  Map<int, int> wordCounts = {};
  List<int> weeklyStats = List.filled(7, 0);
  int dueWordCount = 0;
  bool isLoading = false;
  String? error;

  int get totalWords => wordCounts.values.fold(0, (a, b) => a + b);
  int get weeklyTotal => weeklyStats.fold(0, (a, b) => a + b);

  Future<void> loadData() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      dictionaries = await database.getDictionaries().timeout(const Duration(seconds: 15));
      wordCounts = {};
      for (final dictionary in dictionaries) {
        final id = (dictionary['id'] as num).toInt();
        wordCounts[id] = await database
            .getWordCountForDictionary(id)
            .timeout(const Duration(seconds: 15));
      }
      weeklyStats = await database.getWeeklyStudyStats().timeout(const Duration(seconds: 15));
      dueWordCount = await database.getDueWordCount().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      error = 'Локальная база данных не ответила вовремя.';
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> addDictionary(String name) async {
    final value = name.trim();
    if (value.isEmpty) return false;
    try {
      await database.addDictionary(value);
      await loadData();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _purple = Color(0xFF6750A4);
  late final HomeViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = HomeViewModel(DatabaseHelper.instance)..loadData();
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
            title: const Text('Word Trainer', style: TextStyle(fontWeight: FontWeight.w800)),
            backgroundColor: const Color(0xFFF7F5FA),
            surfaceTintColor: Colors.transparent,
            actions: [IconButton(tooltip: 'Обновить', onPressed: vm.loadData, icon: const Icon(Icons.refresh_rounded))],
          ),
          body: _body(),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addDictionary,
            backgroundColor: _purple,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Словарь', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      );

  Widget _body() {
    if (vm.isLoading) return const Center(child: CircularProgressIndicator());
    if (vm.error != null) {
      return _ErrorState(message: vm.error!, onRetry: vm.loadData);
    }
    return RefreshIndicator(
      onRefresh: vm.loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
        children: [
          _welcome(),
          const SizedBox(height: 16),
          _statistics(),
          const SizedBox(height: 16),
          _studyCard(),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Мои словари', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              Text('${vm.dictionaries.length}', style: const TextStyle(color: _purple, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          if (vm.dictionaries.isEmpty) _emptyDictionaries() else ...vm.dictionaries.map(_dictionaryTile),
        ],
      ),
    );
  }

  Widget _welcome() => _Panel(
        child: Row(
          children: [
            const _IconBox(icon: Icons.school_rounded),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Продолжайте обучение', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(
                  vm.totalWords == 0
                      ? 'Создайте словарь и добавьте первые слова.'
                      : 'В ваших словарях уже ${wordCountText(vm.totalWords)}.',
                  style: const TextStyle(color: Colors.grey),
                ),
              ]),
            ),
          ],
        ),
      );

  Widget _statistics() {
    final maxValue = vm.weeklyStats.fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = maxValue < 4 ? 5.0 : maxValue.toDouble() + 2;
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_purple, Color(0xFF9274D2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: _purple.withValues(alpha: .20), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Статистика', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Изучено за неделю', style: TextStyle(color: Colors.white70)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(24)),
            child: Text(wordCountText(vm.weeklyTotal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 22),
        SizedBox(
          height: 150,
          child: BarChart(BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            barTouchData: BarTouchData(enabled: false),
            gridData: FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(days[value.toInt()], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              )),
            ),
            barGroups: List.generate(7, (i) => BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: vm.weeklyStats[i].toDouble(),
                    width: 15,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: Colors.white.withValues(alpha: .08)),
                  )
                ])),
          )),
        ),
      ]),
    );
  }

  Widget _studyCard() {
    final due = vm.dueWordCount;
    return _Panel(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const RepetitionScreen()));
          await vm.loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            _IconBox(icon: due > 0 ? Icons.play_arrow_rounded : Icons.check_rounded, success: due == 0),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Начать повторение', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(due > 0 ? 'Сегодня ожидают ${wordCountText(due)}' : 'На сегодня всё выполнено', style: const TextStyle(color: Colors.grey)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  Widget _emptyDictionaries() => const _Panel(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Column(children: [
            Icon(Icons.menu_book_outlined, size: 54, color: Color(0xFFAAA4B0)),
            SizedBox(height: 12),
            Text('Словарей пока нет', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 5),
            Text('Нажмите «Словарь», чтобы создать первый.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ]),
        ),
      );

  Widget _dictionaryTile(Map<String, dynamic> dictionary) {
    final id = (dictionary['id'] as num).toInt();
    final name = dictionary['name']?.toString() ?? 'Словарь';
    final count = vm.wordCounts[id] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Panel(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => WordsScreen(dictionaryId: id, dictionaryName: name)));
            await vm.loadData();
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(children: [
              const _IconBox(icon: Icons.translate_rounded, size: 50),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(wordCountText(count), style: const TextStyle(color: Colors.grey)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _addDictionary() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новый словарь'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Название', hintText: 'Например: Английский')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              final success = await vm.addDictionary(controller.text);
              if (success && dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE9E5EF)), borderRadius: BorderRadius.circular(24)),
          child: child,
        ),
      );
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.success = false, this.size = 56});
  final IconData icon;
  final bool success;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: success ? const Color(0xFFEAF6ED) : const Color(0xFFEDE7F6),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Icon(icon, color: success ? const Color(0xFF3E8E57) : _HomeScreenState._purple, size: 29),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 68, color: Color(0xFFD64545)),
            const SizedBox(height: 16),
            const Text('Не удалось загрузить данные', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Повторить')),
          ]),
        ),
      );
}
