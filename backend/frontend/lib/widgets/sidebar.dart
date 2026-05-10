import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/language.dart';
import '../theme/app_theme.dart';

class Sidebar extends StatelessWidget {
  final List<LanguageInfo> languages;
  final int activeIndex;
  final ValueChanged<int> onLanguageSelected;

  const Sidebar({
    super.key,
    required this.languages,
    required this.activeIndex,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppTheme.sidebarBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          _Brand(),
          const SizedBox(height: 24),
          _SearchBar(),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Languages', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: languages.length,
              itemBuilder: (_, i) => _LangCard(
                language: languages[i],
                isActive: i == activeIndex,
                paletteIndex: i,
                onTap: () => onLanguageSelected(i),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Tools', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 8),
          _IconGrid(),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: AppTheme.primaryGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.lock_outline, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text('VocabLock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search words...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  final LanguageInfo language;
  final bool isActive;
  final int paletteIndex;
  final VoidCallback onTap;

  const _LangCard({
    required this.language,
    required this.isActive,
    required this.paletteIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.palettes[paletteIndex % AppTheme.palettes.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isActive ? palette.primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius * 0.6),
            border: isActive ? Border.all(color: palette.primary.withOpacity(0.2), width: 1.5) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [palette.primary, palette.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  language.code.toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(language.nativeName.isNotEmpty ? language.nativeName : language.code, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                  const SizedBox(height: 2),
                  Text(language.displayName.isNotEmpty ? language.displayName : language.code, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconGrid extends StatelessWidget {
  final List<({IconData icon, String label})> _items = const [
    (icon: Icons.auto_stories, label: 'Quiz'),
    (icon: Icons.library_books, label: 'Words'),
    (icon: Icons.headphones, label: 'Audio'),
    (icon: Icons.insights, label: 'Stats'),
    (icon: Icons.settings, label: 'Config'),
    (icon: Icons.smart_toy, label: 'AI Chat'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _items.map((item) => _IconItem(icon: item.icon, label: item.label)).toList(),
      ),
    );
  }
}

class _IconItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _IconItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
