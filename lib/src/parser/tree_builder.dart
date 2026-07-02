/// Builds the nested translation trees from classified rows.
///
/// This module implements the "YAML-in-CSV" nesting logic, the most delicate
/// part of the parser. See [TreeBuilder.build] for a full description of the
/// algorithm.
library;

import '../exceptions.dart';
import '../parser_config.dart';
import 'anchor_locator.dart';
import 'column_schema.dart';

/// Constructs one nested `Map` per language from the data region of the grid.
class TreeBuilder {
  /// Creates a tree builder driven by [config].
  const TreeBuilder(this.config);

  /// The active configuration.
  final ParserConfig config;

  /// Builds the translation trees.
  ///
  /// Returns a map from language code to that language's nested object. Every
  /// value in the tree is either a `String` (a leaf translation) or a nested
  /// `Map<String, Object?>`.
  ///
  /// ## The algorithm
  ///
  /// Rows are processed top to bottom while a *carry-down* stack remembers the
  /// most recent value seen in each key/nested-key column — this is what makes
  /// the format behave like an indented YAML document flattened into a grid.
  ///
  /// For each row:
  ///
  /// 1. The path columns (key + nested keys) are read into `rawPath`.
  /// 2. If every path cell is blank the row is a visual separator and is
  ///    skipped without disturbing the carry-down stack.
  /// 3. Otherwise the *effective path* is resolved up to the deepest non-empty
  ///    path cell:
  ///    * A non-empty cell sets the carry-down value at its level and
  ///      invalidates every deeper level (we have moved to a new branch).
  ///    * A leading empty cell inherits the carry-down value at its level. If
  ///      there is nothing to inherit (the branch was reset by a shallower new
  ///      key, or this is the first row) the row is malformed.
  ///    * Trailing empty cells simply mean "this entry is a leaf here", so they
  ///      are not part of the path.
  /// 4. If any path segment is a comment ([ParserConfig.commentPattern]) or an
  ///    ignored key ([ParserConfig.ignoreKeyPattern]) the row is skipped.
  /// 5. Otherwise each language cell is inserted into that language's tree at
  ///    the resolved path.
  ///
  /// Throws [InvalidRowException], [KeyConflictException] and
  /// [MaxDepthExceededException] as described on those types.
  Map<String, Map<String, Object?>> build(
    List<List<String>> grid,
    ColumnSchema schema,
    Anchor anchor,
  ) {
    final trees = <String, Map<String, Object?>>{
      for (final language in schema.languageColumns)
        language.code: <String, Object?>{},
    };

    final pathColumns = schema.pathColumnIndices;
    // Carry-down stack, one slot per path column. `null` means "nothing to
    // inherit at this level".
    final carried = List<String?>.filled(pathColumns.length, null);

    for (var rowIndex = anchor.row + 1; rowIndex < grid.length; rowIndex++) {
      final row = grid[rowIndex];
      final rowNumber = rowIndex + 1; // 1-based, matches the source file

      final rawPath = [for (final col in pathColumns) _cell(row, col)];

      final path = _resolvePath(rawPath, carried, rowNumber);
      if (path == null) continue; // separator row

      if (_isIgnored(path)) continue;

      if (path.length > config.maxDepth) {
        throw MaxDepthExceededException(path.join('.'), config.maxDepth);
      }

      for (final language in schema.languageColumns) {
        final value = _cell(row, language.index);
        if (value.isEmpty && !config.includeEmptyValues) continue;
        _insert(trees[language.code]!, path, value, language.code);
      }
    }

    return trees;
  }

  /// Reads the cell at [col], tolerating ragged rows, and applies trimming.
  String _cell(List<String> row, int col) {
    if (col >= row.length) return '';
    final raw = row[col];
    return config.trimValues ? raw.trim() : raw;
  }

  /// Resolves the effective key path for a row, mutating the [carried] stack.
  ///
  /// Returns `null` for a fully-blank separator row.
  List<String>? _resolvePath(
    List<String> rawPath,
    List<String?> carried,
    int rowNumber,
  ) {
    var lastNonEmpty = -1;
    for (var i = 0; i < rawPath.length; i++) {
      if (rawPath[i].isNotEmpty) lastNonEmpty = i;
    }
    if (lastNonEmpty == -1) return null;

    final path = <String>[];
    for (var i = 0; i <= lastNonEmpty; i++) {
      final cell = rawPath[i];
      if (cell.isNotEmpty) {
        carried[i] = cell;
        // Moving to a new value at this level invalidates deeper branches.
        for (var deeper = i + 1; deeper < carried.length; deeper++) {
          carried[deeper] = null;
        }
        path.add(cell);
      } else {
        final inherited = carried[i];
        if (inherited == null) {
          throw InvalidRowException(
            rowNumber,
            'Path column ${i + 1} is empty and there is no parent row to '
            'inherit its value from.',
          );
        }
        path.add(inherited);
      }
    }
    return path;
  }

  /// Whether any segment of [path] marks the row as skippable.
  bool _isIgnored(List<String> path) {
    for (final segment in path) {
      if (config.commentPattern.hasMatch(segment)) return true;
      if (config.ignoreKeyPattern.hasMatch(segment)) return true;
    }
    return false;
  }

  /// Inserts [value] into [root] at [path], creating intermediate objects and
  /// detecting structural conflicts.
  void _insert(
    Map<String, Object?> root,
    List<String> path,
    String value,
    String languageCode,
  ) {
    var node = root;
    for (var i = 0; i < path.length - 1; i++) {
      final segment = path[i];
      final existing = node[segment];
      switch (existing) {
        case null:
          final child = <String, Object?>{};
          node[segment] = child;
          node = child;
        case final Map<String, Object?> child:
          node = child;
        default:
          throw KeyConflictException(
            path.join('.'),
            'Key "${path.take(i + 1).join('.')}" is used both as a translation '
            'value and as a parent object (language: $languageCode).',
          );
      }
    }

    final leaf = path.last;
    final existing = node[leaf];
    if (existing is Map) {
      throw KeyConflictException(
        path.join('.'),
        'Key "${path.join('.')}" is used both as a nested object and as a leaf '
        'value (language: $languageCode).',
      );
    }
    if (existing != null) {
      throw KeyConflictException(
        path.join('.'),
        'Duplicate key "${path.join('.')}" (language: $languageCode).',
      );
    }
    node[leaf] = value;
  }
}
