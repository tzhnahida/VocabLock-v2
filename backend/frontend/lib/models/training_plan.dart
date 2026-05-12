class TrainingPlan {
  final int? id;
  final String direction;
  final double directionConfidence;
  final String planJson;
  final DateTime? createdAt;

  const TrainingPlan({
    this.id,
    this.direction = 'general',
    this.directionConfidence = 0.0,
    this.planJson = '',
    this.createdAt,
  });

  factory TrainingPlan.fromJson(Map<String, dynamic> json) => TrainingPlan(
        id: (json['id'] as num?)?.toInt(),
        direction: json['direction'] ?? 'general',
        directionConfidence: (json['direction_confidence'] as num?)?.toDouble() ?? 0.0,
        planJson: json['plan_json'] ?? '',
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      );
}
