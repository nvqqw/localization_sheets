/// Writes a [LocalizationBundle] out as one JSON file per language.
library;

import 'dart:convert';
import 'dart:io';

import '../exceptions.dart';
import '../model/localization_bundle.dart';

/// The set of files produced by a single write.
typedef WriteResult = ({List<String> paths});

/// Serializes a [LocalizationBundle] to `{language_code}.json` files inside a
/// target directory.
///
/// This is the "writer" role in the pipeline. It is the only part of the
/// package (besides the reader) that touches the filesystem.
class JsonWriter {
  /// Creates a writer.
  ///
  /// When [pretty] is `true` (the default) output is indented with [indent];
  /// otherwise it is written compactly on a single line. When [trailingNewline]
  /// is `true` a final newline is appended, which plays nicely with diff tools
  /// and POSIX conventions.
  const JsonWriter({
    this.pretty = true,
    this.indent = '  ',
    this.trailingNewline = true,
  });

  /// Whether to pretty-print the JSON.
  final bool pretty;

  /// The indent unit used when [pretty] is `true`.
  final String indent;

  /// Whether to append a trailing newline to each file.
  final bool trailingNewline;

  /// Writes every language in [bundle] to `<outputDirectory>/<code>.json`.
  ///
  /// The directory (and any missing parents) is created if necessary. Returns
  /// the list of file paths written, in language order.
  ///
  /// Throws [OutputWriteException] if the directory cannot be created or a file
  /// cannot be written.
  Future<WriteResult> write(
    LocalizationBundle bundle,
    String outputDirectory,
  ) async {
    final directory = Directory(outputDirectory);
    try {
      await directory.create(recursive: true);
    } on FileSystemException catch (error) {
      throw OutputWriteException(
        outputDirectory,
        'Could not create output directory: ${error.message}',
      );
    }

    final encoder = pretty
        ? JsonEncoder.withIndent(indent)
        : const JsonEncoder();

    final written = <String>[];
    for (final entry in bundle.translations.entries) {
      final path = _joinPath(outputDirectory, '${entry.key}.json');
      final body = encoder.convert(entry.value);
      final contents = trailingNewline ? '$body\n' : body;
      try {
        await File(path).writeAsString(contents);
      } on FileSystemException catch (error) {
        throw OutputWriteException(
          path,
          'Could not write output file: ${error.message}',
        );
      }
      written.add(path);
    }
    return (paths: written);
  }

  /// Joins a directory and file name without pulling in the `path` package,
  /// keeping this tool dependency-free. Normalizes a single trailing separator.
  String _joinPath(String directory, String fileName) {
    final separator = Platform.pathSeparator;
    if (directory.isEmpty) return fileName;
    final trimmed = directory.endsWith(separator) || directory.endsWith('/')
        ? directory.substring(0, directory.length - 1)
        : directory;
    return '$trimmed$separator$fileName';
  }
}
