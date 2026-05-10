import 'package:flutter/material.dart';
import '../models/word.dart';

class ReviewList extends StatelessWidget {
  final List<Word> words;

  const ReviewList({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Recent Mistakes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        ...words.map((w) => _MistakeRow(word: w)),
      ],
    );
  }
}

class _MistakeRow extends StatelessWidget {
  final Word word;
  const _MistakeRow({required this.word});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade100,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.error_outline, size: 16, color: Colors.orange.shade400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(word.word, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(word.meaning, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(word.pos, style: TextStyle(fontSize: 10, color: Colors.red.shade400)),
          ),
        ],
      ),
    );
  }
}
