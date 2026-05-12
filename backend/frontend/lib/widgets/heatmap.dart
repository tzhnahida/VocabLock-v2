import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Heatmap extends StatelessWidget {
  final Map<String, int> data;

  const Heatmap({super.key, required this.data});

  static Color cellColor(double score) {
    if (score == 0) return const Color(0xFFEBEDF0);
    if (score >= 0.95) return const Color(0xFF216E39);
    if (score >= 0.85) return const Color(0xFF30A14E);
    if (score >= 0.70) return const Color(0xFF40C463);
    if (score >= 0.40) return const Color(0xFF9BE9A8);
    return const Color(0xFFC6E48B);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final startDate = today.subtract(const Duration(days: 364));
    final weeks = <List<_Day>>[];
    var currentWeek = <_Day>[];
    var cursor = DateTime(startDate.year, startDate.month, startDate.day);

    for (var i = 0; i < 365; i++) {
      final key =
          '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      currentWeek.add(_Day(
        date: DateTime(cursor.year, cursor.month, cursor.day),
        value: data[key] ?? 0,
        isToday: cursor.year == today.year &&
            cursor.month == today.month &&
            cursor.day == today.day,
      ));
      if (cursor.weekday == 7 || i == 364) {
        weeks.add(currentWeek);
        currentWeek = [];
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    final dayLabels = ['', '一', '', '三', '', '五', ''];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: dayLabels.map((l) => SizedBox(
                  height: 14,
                  width: 20,
                  child: Text(l, style: TextStyle(fontSize: 9, color: AppTheme.textHint, height: 1.3)),
                )).toList(),
              ),
              ...weeks.map((week) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Column(
                    children: List.generate(7, (dayIndex) {
                      final entry = week.where((d) => d.date.weekday == (dayIndex + 1));
                      if (entry.isEmpty) {
                        return const SizedBox(width: 14, height: 14);
                      }
                      final d = entry.first;
                      return Tooltip(
                        message: d.isToday
                            ? '今天: ${d.value}题'
                            : d.value > 0
                                ? '${d.date.month}/${d.date.day}: ${d.value}题'
                                : '${d.date.month}/${d.date.day}: 未打卡',
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: cellColor(_score(d.value)),
                            borderRadius: BorderRadius.circular(2),
                            border: d.isToday
                                ? Border.all(color: AppTheme.primary, width: 2)
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('少', style: TextStyle(fontSize: 9, color: AppTheme.textHint)),
              const SizedBox(width: 4),
              ...[0.0, 0.4, 0.7, 0.85, 0.95].map((s) => Container(
                width: 12, height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: cellColor(s),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(width: 4),
              Text('多', style: TextStyle(fontSize: 9, color: AppTheme.textHint)),
            ],
          ),
        ],
      ),
    );
  }

  double _score(int value) {
    if (value <= 0) return 0;
    if (value >= 20) return 1.0;
    return value / 20.0;
  }
}

class _Day {
  final DateTime date;
  final int value;
  final bool isToday;
  const _Day({required this.date, required this.value, required this.isToday});
}
