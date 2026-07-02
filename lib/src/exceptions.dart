/// Exception types thrown by the localization_sheets pipeline.
///
/// All failures raised by this package extend [LocalizationSheetsException],
/// so callers can catch the whole family with a single `on` clause:
///
/// ```dart
/// try {
///   await LocalizationConverter().convertFile('in.csv', 'out/');
/// } on LocalizationSheetsException catch (error) {
///   stderr.writeln(error);
/// }
/// ```
library;

/// Base type for every error surfaced by this package.
///
/// This is a [sealed] class: the complete set of failure modes is known at
/// compile time, which lets `switch` statements exhaustively match on them.
sealed class LocalizationSheetsException implements Exception {
  /// Creates an exception with a human readable [message].
  const LocalizationSheetsException(this.message);

  /// A description of what went wrong, suitable for showing to a CLI user.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when the input file cannot be read (missing, not a file, etc.).
final class InputReadException extends LocalizationSheetsException {
  /// Creates an [InputReadException] for the file at [path].
  const InputReadException(this.path, String message) : super(message);

  /// The path that could not be read.
  final String path;

  @override
  String toString() => 'InputReadException: $message (path: $path)';
}

/// Thrown when the CSV text is structurally malformed (for example an
/// unterminated quoted field).
final class CsvFormatException extends LocalizationSheetsException {
  /// Creates a [CsvFormatException] pointing at [line] (1-based).
  const CsvFormatException(this.line, String message) : super(message);

  /// The 1-based line number where parsing failed.
  final int line;

  @override
  String toString() => 'CsvFormatException: $message (line: $line)';
}

/// Thrown when the mandatory `key` anchor cell cannot be found in the grid.
final class AnchorNotFoundException extends LocalizationSheetsException {
  /// Creates an [AnchorNotFoundException] describing the [keyLabel] searched for.
  const AnchorNotFoundException(this.keyLabel)
    : super(
        'Could not find the anchor cell "$keyLabel" anywhere in the '
        'sheet. The parser needs exactly one cell whose trimmed value '
        'equals "$keyLabel" to know where the data region begins.',
      );

  /// The anchor label that was searched for (usually `key`).
  final String keyLabel;
}

/// Thrown when no language columns are detected to the right of the key and
/// nested-key columns — there would be nothing to export.
final class NoLanguageColumnsException extends LocalizationSheetsException {
  /// Creates a [NoLanguageColumnsException].
  const NoLanguageColumnsException()
    : super(
        'No language columns were found. Expected at least one '
        'non-comment column to the right of the key/nested-key columns.',
      );
}

/// Thrown when a row cannot be turned into a valid key path — for example when
/// the very first data row leaves the key column empty so there is no parent to
/// inherit from.
final class InvalidRowException extends LocalizationSheetsException {
  /// Creates an [InvalidRowException] for the 1-based [rowNumber].
  const InvalidRowException(this.rowNumber, String message) : super(message);

  /// The 1-based row number (within the original file) that failed.
  final int rowNumber;

  @override
  String toString() => 'InvalidRowException: $message (row: $rowNumber)';
}

/// Thrown when two rows resolve to the same key path, or when a key path would
/// require treating a leaf string as a nested object (or vice versa).
final class KeyConflictException extends LocalizationSheetsException {
  /// Creates a [KeyConflictException] for the dotted [keyPath].
  const KeyConflictException(this.keyPath, String message) : super(message);

  /// The dotted representation of the conflicting key path.
  final String keyPath;

  @override
  String toString() => 'KeyConflictException: $message (key: $keyPath)';
}

/// Thrown when a key path exceeds [maxDepth] configured on the parser.
final class MaxDepthExceededException extends LocalizationSheetsException {
  /// Creates a [MaxDepthExceededException].
  const MaxDepthExceededException(this.keyPath, this.maxDepth)
    : super(
        'Key path "$keyPath" is deeper than the configured maximum '
        'depth of $maxDepth.',
      );

  /// The dotted key path that was too deep.
  final String keyPath;

  /// The configured maximum depth.
  final int maxDepth;
}

/// Thrown when output files cannot be written to the target directory.
final class OutputWriteException extends LocalizationSheetsException {
  /// Creates an [OutputWriteException] for [path].
  const OutputWriteException(this.path, String message) : super(message);

  /// The path that could not be written.
  final String path;

  @override
  String toString() => 'OutputWriteException: $message (path: $path)';
}
