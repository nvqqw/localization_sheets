/// Locates the `key` anchor cell inside a raw grid.
library;

import '../exceptions.dart';
import '../parser_config.dart';

/// The coordinates of the anchor cell within the grid.
typedef Anchor = ({int row, int col});

/// Finds the single anchor cell that marks the top-left corner of the data
/// region.
///
/// The anchor is the cell whose trimmed text equals [ParserConfig.keyLabel]
/// (`key` by default). Everything above the anchor's row and to the left of its
/// column is free-form metadata and is ignored by the rest of the pipeline.
///
/// Scanning is top-to-bottom, left-to-right, so the first match wins — this
/// makes the top-most, left-most `key` cell authoritative if the label happens
/// to appear more than once.
class AnchorLocator {
  /// Creates a locator driven by [config].
  const AnchorLocator(this.config);

  /// The active configuration.
  final ParserConfig config;

  /// Returns the [Anchor] coordinates, or throws [AnchorNotFoundException] if no
  /// matching cell exists.
  Anchor locate(List<List<String>> grid) {
    final target = config.caseSensitiveAnchor
        ? config.keyLabel
        : config.keyLabel.toLowerCase();

    for (var row = 0; row < grid.length; row++) {
      final cells = grid[row];
      for (var col = 0; col < cells.length; col++) {
        var value = cells[col].trim();
        if (!config.caseSensitiveAnchor) value = value.toLowerCase();
        if (value == target) {
          return (row: row, col: col);
        }
      }
    }
    throw AnchorNotFoundException(config.keyLabel);
  }
}
