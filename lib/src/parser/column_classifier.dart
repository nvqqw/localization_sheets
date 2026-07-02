/// Classifies header columns into key / nested / language / ignored roles.
library;

import '../exceptions.dart';
import '../parser_config.dart';
import 'anchor_locator.dart';
import 'column_schema.dart';

/// Turns the header row into a [ColumnSchema].
///
/// Classification starts at the anchor column and scans rightwards. The rules,
/// in priority order, are:
///
/// 1. **Comment wins.** A header matching [ParserConfig.commentPattern] (e.g.
///    `#description`) is ignored, even if it would otherwise look like a nested
///    key. This is why `#nested_key` is dropped rather than nested.
/// 2. **Nested keys.** In auto mode (the default) a non-comment header that
///    matches [ParserConfig.nestedKeyPattern] is a nested-key column. When
///    [ParserConfig.nestedKeyColumnCount] is set, the first *N* non-comment
///    columns after the key column are nested-key columns instead, regardless
///    of their header text.
/// 3. **Everything else is a language.** Any remaining non-comment column is
///    treated as a language column; its header (trimmed) becomes the code.
class ColumnClassifier {
  /// Creates a classifier driven by [config].
  const ColumnClassifier(this.config);

  /// The active configuration.
  final ParserConfig config;

  /// Builds the [ColumnSchema] for the header row located at [anchor] within
  /// [grid].
  ///
  /// Throws [NoLanguageColumnsException] when there is no language column to the
  /// right of the key/nested-key columns.
  ColumnSchema classify(List<List<String>> grid, Anchor anchor) {
    final header = grid[anchor.row];
    final keyColumnIndex = anchor.col;

    final nested = <int>[];
    final languages = <LanguageColumn>[];
    final ignored = <int>[];

    // Columns to the left of the anchor are metadata and never considered.
    final nestedBudget = config.nestedKeyColumnCount;
    var acceptingNested = true;

    for (var col = keyColumnIndex + 1; col < header.length; col++) {
      final raw = header[col];
      final text = config.trimValues ? raw.trim() : raw;

      // Rule 1: comment columns are always ignored.
      if (config.commentPattern.hasMatch(text)) {
        ignored.add(col);
        continue;
      }

      // A blank header cannot name a language and carries no nesting label;
      // treat it as ignored so trailing empty export columns are harmless.
      if (text.isEmpty) {
        ignored.add(col);
        continue;
      }

      // Rule 2: nested-key detection.
      final bool isNested;
      if (nestedBudget != null) {
        isNested = acceptingNested && nested.length < nestedBudget;
      } else {
        isNested = acceptingNested && config.nestedKeyPattern.hasMatch(text);
      }

      if (isNested) {
        nested.add(col);
        continue;
      }

      // Rule 3: the first non-nested, non-comment column starts the language
      // region. Once languages begin, no further nested columns are accepted so
      // the key path stays contiguous.
      acceptingNested = false;
      languages.add(LanguageColumn(col, text));
    }

    if (languages.isEmpty) {
      throw const NoLanguageColumnsException();
    }

    return ColumnSchema(
      keyColumnIndex: keyColumnIndex,
      nestedColumnIndices: nested,
      languageColumns: languages,
      ignoredColumnIndices: ignored,
    );
  }
}
