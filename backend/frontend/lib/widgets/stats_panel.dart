import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'heatmap.dart';

class StatsPanel extends StatefulWidget {
  final AppState state;
  const StatsPanel({super.key, required this.state});

  @override
  State<StatsPanel> createState() => _StatsPanelState();
}

class _StatsPanelState extends State<StatsPanel> {
  int _streak = 0;
  Map<String, int> _heatmap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final statsApi = widget.state.statsApi;
    if (statsApi != null) {
      try {
        _streak = await statsApi.getStreak(language: widget.state.activeLangCode);
        _heatmap = await statsApi.getHeatmap(language: widget.state.activeLangCode);
      } catch (_) {}
    }
    if (_heatmap.isEmpty) {
      _heatmap = widget.state.heatmap;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final todayStats = widget.state.todayStats;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Statistics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _StatCard(label: 'Current Streak', value: _streak.toString(), unit: 'days', icon: Icons.local_fire_department, color: AppTheme.warm),
                      const SizedBox(width: 16),
                      _StatCard(label: "Today's Progress", value: '${todayStats?.reviewed ?? 0}', unit: 'of 20', icon: Icons.check_circle, color: AppTheme.primary),
                      const SizedBox(width: 16),
                      _StatCard(label: 'Accuracy', value: '${((todayStats?.accuracy ?? 0) * 100).toInt()}', unit: '%', icon: Icons.trending_up, color: AppTheme.accent),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text('Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Heatmap(data: _heatmap),
                  ),
                  const SizedBox(height: 24),
                  _Legend(),
                ],
              ),
            ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(color: Heatmap.cellColor(0), label: 'No review'),
        const SizedBox(width: 16),
        _LegendItem(color: Heatmap.cellColor(0.45), label: '1-10'),
        const SizedBox(width: 16),
        _LegendItem(color: Heatmap.cellColor(0.75), label: '10-15'),
        const SizedBox(width: 16),
        _LegendItem(color: Heatmap.cellColor(0.90), label: '15-20'),
        const SizedBox(width: 16),
        _LegendItem(color: Heatmap.cellColor(0.99), label: '20+'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(unit, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
