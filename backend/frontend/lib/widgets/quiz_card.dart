import 'package:flutter/material.dart';
import '../models/question.dart';

class QuizCard extends StatelessWidget {
  final Question question;
  final String? selectedAnswer;
  final bool? isCorrect;
  final ValueChanged<String>? onAnswer;

  const QuizCard({
    super.key,
    required this.question,
    this.selectedAnswer,
    this.isCorrect,
    this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(question.type.displayName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _typeColor)),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 20),
          Text(question.prompt, style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5)),
          if (question.options != null && question.options!.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...question.options!.map((opt) => _OptionTile(
                  text: opt,
                  isSelected: selectedAnswer == opt,
                  isCorrect: selectedAnswer == opt ? isCorrect : null,
                  onTap: onAnswer != null ? () => onAnswer!(opt) : null,
                )),
          ],
        ],
      ),
    );
  }

  Color get _typeColor {
    switch (question.type) {
      case QuestionType.choice:
        return Colors.blue;
      case QuestionType.fill:
        return Colors.orange;
      case QuestionType.spelling:
        return Colors.purple;
      case QuestionType.reading:
        return Colors.teal;
      case QuestionType.listening:
        return Colors.pink;
      case QuestionType.readingComp:
        return Colors.indigo;
      case QuestionType.grammar:
        return Colors.red;
    }
  }
}

class _OptionTile extends StatelessWidget {
  final String text;
  final bool isSelected;
  final bool? isCorrect;
  final VoidCallback? onTap;

  const _OptionTile({required this.text, this.isSelected = false, this.isCorrect, this.onTap});

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    Color? borderColor;
    if (isSelected && isCorrect == true) {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade300;
    } else if (isSelected && isCorrect == false) {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade300;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor ?? Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor ?? Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(child: Text(text, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400))),
              if (isSelected && isCorrect == true) const Icon(Icons.check_circle, color: Colors.green, size: 20),
              if (isSelected && isCorrect == false) const Icon(Icons.cancel, color: Colors.red, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
