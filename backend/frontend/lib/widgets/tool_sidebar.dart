import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ToolSidebar extends StatelessWidget {
  final int activeToolIndex;
  final ValueChanged<int> onToolSelected;
  final String activeLangCode;
  final List<String> langCodes;
  final ValueChanged<int> onLangChanged;

  const ToolSidebar({
    super.key,
    required this.activeToolIndex,
    required this.onToolSelected,
    required this.activeLangCode,
    required this.langCodes,
    required this.onLangChanged,
  });

  static const _tools = [
    (Icons.auto_stories, 'Quiz'),
    (Icons.library_books, 'Words'),
    (Icons.headphones, 'Audio'),
    (Icons.insights, 'Stats'),
    (Icons.settings, 'Config'),
    (Icons.smart_toy, 'AI'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: AppTheme.sidebarBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _Brand(),
          const SizedBox(height: 28),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: List.generate(_tools.length, (i) => _ToolIcon(
                icon: _tools[i].$1,
                label: _tools[i].$2,
                isActive: i == activeToolIndex,
                onTap: () => onToolSelected(i),
              )),
            ),
          ),
          _LanguageDial(
            activeCode: activeLangCode,
            codes: langCodes,
            onChanged: onLangChanged,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: AppTheme.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.lock_outline, color: Colors.white, size: 22),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolIcon({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isActive ? AppTheme.primary : AppTheme.textHint,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppTheme.primary : AppTheme.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageDial extends StatelessWidget {
  final String activeCode;
  final List<String> codes;
  final ValueChanged<int> onChanged;

  const _LanguageDial({
    required this.activeCode,
    required this.codes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final activeIndex = codes.indexOf(activeCode);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, width: 32, color: Colors.grey.shade200),
        const SizedBox(height: 12),
        ...List.generate(codes.length, (i) {
          final isActive = i == activeIndex;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 14),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primary.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                codes[i].toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppTheme.primary : AppTheme.textHint,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
