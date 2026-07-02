/// Data structures describing how the columns of a sheet are classified.
library;

/// The role a single column plays in the data region.
enum ColumnRole {
  /// The anchor column that holds the top-level JSON keys.
  key,

  /// A column that contributes an additional level of nesting.
  nested,

  /// A language column whose cells become translation values.
  language,

  /// A column that is ignored entirely (e.g. a `#comment` column).
  ignored,
}

/// A language column together with the language code taken from its header.
class LanguageColumn {
  /// Creates a language column at absolute [index] with the given [code].
  const LanguageColumn(this.index, this.code);

  /// The absolute column index within the source grid.
  final int index;

  /// The language code (the trimmed header text, e.g. `en` or `en-US`). This
  /// becomes the output file name `{code}.json`.
  final String code;

  @override
  String toString() => 'LanguageColumn(index: $index, code: $code)';
}

/// The result of classifying the header row: which columns are keys, nested
/// keys, languages, or ignored.
///
/// All indices are absolute columns within the original grid, so the schema can
/// be applied directly to un-cropped rows.
class ColumnSchema {
  /// Creates a column schema.
  ColumnSchema({
    required this.keyColumnIndex,
    required this.nestedColumnIndices,
    required this.languageColumns,
    required this.ignoredColumnIndices,
  });

  /// The absolute index of the key (anchor) column.
  final int keyColumnIndex;

  /// The absolute indices of the nested-key columns, ordered left to right
  /// (shallowest first). Empty when the sheet has no nesting.
  final List<int> nestedColumnIndices;

  /// The detected language columns, ordered left to right.
  final List<LanguageColumn> languageColumns;

  /// The absolute indices of columns that are ignored.
  final List<int> ignoredColumnIndices;

  /// The columns, ordered shallow-to-deep, that together form a key path:
  /// the key column followed by every nested-key column.
  List<int> get pathColumnIndices => [keyColumnIndex, ...nestedColumnIndices];

  /// The maximum possible depth of a key path given this schema.
  int get pathDepth => pathColumnIndices.length;
}
