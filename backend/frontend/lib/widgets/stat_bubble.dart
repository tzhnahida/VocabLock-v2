import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatBubble extends StatelessWidget {
  final String label;
  final double value;
  final List<Color> gradientColors;

  const StatBubble({
    super.key,
    required this.label,
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
            color: gradientColors.first.withOpacity(0.3),
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
            '${(value * 100).toInt()}%',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, height: 1.1),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.85)),
          ),
        ],
      ),
    );
  }
}
