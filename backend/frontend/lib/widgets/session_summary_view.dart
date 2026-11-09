import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/session_summary.dart';
import '../models/training_plan.dart';
import '../theme/app_theme.dart';

class SessionSummaryView extends StatelessWidget {
  final SessionSummary? summary;
  final bool loading;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const SessionSummaryView({
    super.key,
    this.summary,
    this.loading = false,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppTheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(l10n.aiSessionSummary, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const Spacer(),
                  TextButton(onPressed: onDismiss, child: Text(l10n.close, style: TextStyle(color: AppTheme.textHint))),
                ],
              ),
              const SizedBox(height: 8),
              Text(l10n.aiAnalyzingSession,
                  style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
              const SizedBox(height: 20),
              if (loading)
                SizedBox(
                  height: 200,
                  child: Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(l10n.analyzing),
                    ],
                  )),
                )
              else if (summary == null)
                SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppTheme.textHint),
                        const SizedBox(height: 12),
                        Text(l10n.aiAnalysisFailed, style: TextStyle(fontSize: 16, color: AppTheme.textHint)),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (summary!.summary != null) _SummaryBlock(data: summary!.summary!),
                        if (summary!.plan != null) ...[
                          const SizedBox(height: 20),
                          _PlanBlock(plan: summary!.plan!),
                        ],
                        if (summary!.warning != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Expanded(child: Text(summary!.warning!, style: TextStyle(fontSize: 13, color: Colors.orange.shade800))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: onDismiss,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(l10n.gotIt, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SummaryBlock({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final today = data['today_summary'] as Map<String, dynamic>?;
    final suggestions = data['suggestions'] as List<dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sessionAnalysis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        if (today != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.isDark ? const Color(0xFF232438) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (today['overall'] != null)
                  Text(today['overall'].toString(), style: TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.5)),
                if (today['strengths'] != null) ...[
                  const SizedBox(height: 8),
                  Text(l10n.labelStrengths + ' ' + today['strengths'].toString(), style: TextStyle(fontSize: 13, color: Colors.green)),
                ],
                if (today['weaknesses'] != null) ...[
                  const SizedBox(height: 4),
                  Text(l10n.labelWeaknesses + ' ' + today['weaknesses'].toString(), style: TextStyle(fontSize: 13, color: Colors.orange)),
                ],
              ],
            ),
          ),
        if (suggestions != null && suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(l10n.labelSuggestions, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          ...suggestions.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.warm),
                const SizedBox(width: 8),
                Expanded(child: Text(s.toString(), style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4))),
              ],
            ),
          )),
        ],
      ],
    );
  }
}

class _PlanBlock extends StatelessWidget {
  final TrainingPlan plan;
  const _PlanBlock({required this.plan});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.track_changes, size: 18, color: AppTheme.accent),
            const SizedBox(width: 8),
            Text(l10n.labelUpdatedPlan, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.isDark ? const Color(0xFF232438) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlanRow(l10n.labelPlanDirection, plan.direction),
              _PlanRow(l10n.labelPlanConfidence, '${(plan.directionConfidence * 100).toInt()}%'),
              if (plan.planJson.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(plan.planJson, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  final String label;
  final String value;
  const _PlanRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textHint))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
        ],
      ),
    );
  }
}
