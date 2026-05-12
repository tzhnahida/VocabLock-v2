import 'training_plan.dart';

class SessionSummary {
  final Map<String, dynamic>? summary;
  final TrainingPlan? plan;
  final String? warning;

  const SessionSummary({this.summary, this.plan, this.warning});

  factory SessionSummary.fromJson(Map<String, dynamic> json) => SessionSummary(
        summary: json['summary'] as Map<String, dynamic>?,
        plan: json['plan'] != null ? TrainingPlan.fromJson(json['plan'] as Map<String, dynamic>) : null,
        warning: json['warning'] as String?,
      );
}
