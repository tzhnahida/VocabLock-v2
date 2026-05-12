import 'package:flutter/material.dart';
import '../models/language.dart';
import '../theme/app_theme.dart';

class LanguageSwitcher extends StatelessWidget {
  final List<LanguageInfo> languages;
  final int activeIndex;
  final ValueChanged<int> onSwitch;

  const LanguageSwitcher({
    super.key,
    required this.languages,
    required this.activeIndex,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Quick Switch', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        Row(
          children: List.generate(languages.length, (i) {
            final lang = languages[i];
            final isActive = i == activeIndex;
            final palette = AppTheme.palettes[i % AppTheme.palettes.length];
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => onSwitch(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [palette.primary, palette.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: isActive ? Border.all(color: Colors.white, width: 2.5) : null,
                    boxShadow: isActive
                        ? [BoxShadow(color: palette.primary.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    lang.code.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
