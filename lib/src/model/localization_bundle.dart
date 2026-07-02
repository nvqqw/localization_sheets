/// The parsed, in-memory representation of a localization sheet.
library;

/// A single language's nested translation object: keys map to either a `String`
/// leaf or another [TranslationTree].
typedef TranslationTree = Map<String, Object?>;

/// The complete result of parsing a sheet: one [TranslationTree] per language,
/// plus a little metadata about the parse.
///
/// This is what the structural parser hands to the writer. It is a plain data
/// object with no IO, so it can be inspected, transformed or serialized however
/// a caller likes.
class LocalizationBundle {
  /// Creates a bundle from the per-language [translations].
  LocalizationBundle({
    required this.translations,
    required this.nestedKeyDepth,
  });

  /// Map from language code to that language's nested translation tree, in the
  /// column order they appeared in the sheet.
  final Map<String, TranslationTree> translations;

  /// The number of nested-key columns detected (0 when the sheet is flat).
  final int nestedKeyDepth;

  /// The language codes present in this bundle, in sheet order.
  Iterable<String> get languageCodes => translations.keys;

  /// The primary language code — the first language column in the sheet.
  ///
  /// This is the source of truth for [findMissingTranslations]: every key that
  /// has a value here is expected to have one in every other language. Returns
  /// `null` when the bundle contains no languages.
  String? get primaryLanguageCode =>
      translations.isEmpty ? null : translations.keys.first;

  /// Finds keys that are translated in the [primaryLanguageCode] but missing or
  /// empty in another language.
  ///
  /// A key counts as *present* when its leaf value in the primary language is a
  /// non-empty string. For every other language, that key is reported when it
  /// is absent from that language's tree or its value is empty.
  ///
  /// Returns a map from language code to the sorted list of dotted key paths
  /// missing for that language. Languages that fully cover the primary language
  /// are omitted, so an empty result means nothing is missing.
  Map<String, List<String>> findMissingTranslations() {
    final primary = primaryLanguageCode;
    if (primary == null) return const {};

    final primaryLeaves = <String, String>{};
    _collectLeaves(translations[primary]!, const [], primaryLeaves);
    final expected = [
      for (final entry in primaryLeaves.entries)
        if (entry.value.isNotEmpty) entry.key,
    ];

    final missing = <String, List<String>>{};
    for (final entry in translations.entries) {
      if (entry.key == primary) continue;
      final leaves = <String, String>{};
      _collectLeaves(entry.value, const [], leaves);
      final gaps = [
        for (final path in expected)
          if ((leaves[path] ?? '').isEmpty) path,
      ]..sort();
      if (gaps.isNotEmpty) missing[entry.key] = gaps;
    }
    return missing;
  }

  /// Flattens [tree] into `out`, mapping each leaf's dotted path to its value
  /// (non-string leaves, which should not occur, map to the empty string).
  static void _collectLeaves(
    TranslationTree tree,
    List<String> prefix,
    Map<String, String> out,
  ) {
    for (final entry in tree.entries) {
      final path = [...prefix, entry.key];
      final value = entry.value;
      if (value is TranslationTree) {
        _collectLeaves(value, path, out);
      } else {
        out[path.join('.')] = value is String ? value : '';
      }
    }
  }

  /// The number of leaf translation strings for [languageCode], counting
  /// recursively through nested objects. Returns `0` for an unknown code.
  int leafCountFor(String languageCode) {
    final tree = translations[languageCode];
    return tree == null ? 0 : _countLeaves(tree);
  }

  static int _countLeaves(TranslationTree tree) => tree.values.fold(
    0,
    (sum, value) => sum + (value is TranslationTree ? _countLeaves(value) : 1),
  );
}
