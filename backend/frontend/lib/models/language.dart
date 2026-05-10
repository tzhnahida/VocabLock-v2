class LanguageInfo {
  final String code;
  final String displayName;
  final String nativeName;
  final int index;

  const LanguageInfo({
    required this.code,
    this.displayName = '',
    this.nativeName = '',
    this.index = 0,
  });

  String get label => nativeName.isNotEmpty ? nativeName : (displayName.isNotEmpty ? displayName : code);

  String get displayLabel => displayName.isNotEmpty ? displayName : code;
}
