/// Configuration for the localization sheet parser.
library;

/// Immutable configuration that controls how a localization sheet is parsed.
///
/// Every knob has a sensible default, so most callers can simply use
/// `const ParserConfig()`. Each field is documented with the behaviour it
/// controls; the defaults match the conventions described in the package
/// README (anchor on `key`, `#` for comments, `$` for ignored keys).
class ParserConfig {
  /// Creates a parser configuration.
  ///
  /// [RegExp] values cannot be compile-time constants, so any omitted pattern
  /// falls back to the package default in the initializer list.
  ///
  /// The assertions guard against a non-positive [maxDepth], a negative
  /// [nestedKeyColumnCount] and a [fieldDelimiter] that is not exactly one
  /// character.
  ParserConfig({
    this.keyLabel = 'key',
    this.caseSensitiveAnchor = true,
    RegExp? nestedKeyPattern,
    this.nestedKeyColumnCount,
    RegExp? commentPattern,
    RegExp? ignoreKeyPattern,
    this.maxDepth = 8,
    this.fieldDelimiter = ',',
    this.trimValues = true,
    this.includeEmptyValues = true,
  }) : nestedKeyPattern = nestedKeyPattern ?? _defaultNestedKeyPattern,
       commentPattern = commentPattern ?? _defaultCommentPattern,
       ignoreKeyPattern = ignoreKeyPattern ?? _defaultIgnoreKeyPattern,
       assert(maxDepth > 0, 'maxDepth must be greater than zero'),
       assert(
         nestedKeyColumnCount == null || nestedKeyColumnCount >= 0,
         'nestedKeyColumnCount must be null or >= 0',
       ),
       assert(
         fieldDelimiter.length == 1,
         'fieldDelimiter must be a single character',
       );

  /// Matches nested-key column headers: `nested_key`, optionally with a numeric
  /// suffix for additional levels (`nested_key_1`, `nested_key_2`, …).
  static final RegExp _defaultNestedKeyPattern = RegExp(
    r'^nested_key(_\d+)?$',
    caseSensitive: false,
  );

  /// Matches comment cells/headers — anything starting with `#`.
  static final RegExp _defaultCommentPattern = RegExp(r'^\s*#');

  /// Matches ignored keys — anything starting with `#`.
  static final RegExp _defaultIgnoreKeyPattern = RegExp(r'^\s*#');

  /// The exact (trimmed) text of the anchor cell that marks the top-left of the
  /// data region. Everything above this row and to the left of this column is
  /// treated as free-form metadata and ignored.
  final String keyLabel;

  /// Whether the search for [keyLabel] is case sensitive.
  final bool caseSensitiveAnchor;

  /// Pattern used to recognise nested-key columns by their header text.
  ///
  /// Only consulted when [nestedKeyColumnCount] is `null` (the default,
  /// "auto-detect" mode). A column counts as a nested-key column when its
  /// header matches this pattern **and** it does not match [commentPattern]
  /// (comments always win — so a header like `#nested_key` is ignored).
  final RegExp nestedKeyPattern;

  /// Explicit number of nested-key columns immediately following the key
  /// column.
  ///
  /// When non-null this overrides [nestedKeyPattern]: the first
  /// [nestedKeyColumnCount] non-comment columns to the right of the key column
  /// are treated as nested-key columns regardless of their header text, and all
  /// remaining non-comment columns are treated as languages. Use this when your
  /// nested-key columns do not follow a recognisable naming convention.
  final int? nestedKeyColumnCount;

  /// Pattern that marks a comment column (by header) or a comment row (by key
  /// cell). Matching columns are dropped entirely; matching keys drop the row.
  ///
  /// Exposed as configuration so the comment marker can be changed without code
  /// edits — e.g. `RegExp(r'^//')` to use `//` instead of `#`.
  final RegExp commentPattern;

  /// Pattern that marks an ignored key. A row is skipped when any of its key or
  /// nested-key path segments match this pattern. Defaults to keys starting
  /// with `#`.
  final RegExp ignoreKeyPattern;

  /// Maximum allowed nesting depth (number of path segments). Defaults to 8,
  /// which comfortably covers real localization sheets while guarding against
  /// runaway structures and accidental misconfiguration.
  final int maxDepth;

  /// The field delimiter used by the CSV reader. Defaults to a comma.
  final String fieldDelimiter;

  /// Whether leading/trailing whitespace is stripped from every cell before it
  /// is interpreted.
  final bool trimValues;

  /// Whether keys whose translation value is empty are still emitted (with an
  /// empty string). When `true` (the default) every language file shares the
  /// same set of keys, which most localization frameworks expect. When `false`
  /// empty translations are omitted from that language's file.
  final bool includeEmptyValues;

  /// Returns a copy of this configuration with the given fields replaced.
  ParserConfig copyWith({
    String? keyLabel,
    bool? caseSensitiveAnchor,
    RegExp? nestedKeyPattern,
    int? nestedKeyColumnCount,
    RegExp? commentPattern,
    RegExp? ignoreKeyPattern,
    int? maxDepth,
    String? fieldDelimiter,
    bool? trimValues,
    bool? includeEmptyValues,
  }) {
    return ParserConfig(
      keyLabel: keyLabel ?? this.keyLabel,
      caseSensitiveAnchor: caseSensitiveAnchor ?? this.caseSensitiveAnchor,
      nestedKeyPattern: nestedKeyPattern ?? this.nestedKeyPattern,
      nestedKeyColumnCount: nestedKeyColumnCount ?? this.nestedKeyColumnCount,
      commentPattern: commentPattern ?? this.commentPattern,
      ignoreKeyPattern: ignoreKeyPattern ?? this.ignoreKeyPattern,
      maxDepth: maxDepth ?? this.maxDepth,
      fieldDelimiter: fieldDelimiter ?? this.fieldDelimiter,
      trimValues: trimValues ?? this.trimValues,
      includeEmptyValues: includeEmptyValues ?? this.includeEmptyValues,
    );
  }
}
