import 'package:flutter/material.dart';

class StatBubble extends StatelessWidget {
  final String label;
  final String display;

  /// Normalized ratio (0.0–1.0) used ONLY for sizing.
  /// The old code multiplied every value by 100 and printed '%' — raw counts
  /// (Remaining/Target) rendered as "1200%". Formatting and sizing are now
  /// decoupled by the caller.
  final double value;
  final List<Color> gradientColors;

  const StatBubble({
    super.key,
    required this.label,
    required this.display,
    required this.value,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final size = 130.0 + (value * 30).clamp(0.0, 40.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.3),
            blurRadius: 18,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            display,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, height: 1.1),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}
