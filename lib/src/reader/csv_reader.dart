/// File-loading front end for the CSV tokenizer.
library;

import 'dart:convert';
import 'dart:io';

import '../exceptions.dart';
import 'csv_parser.dart';

/// Reads a CSV file from disk and returns its contents as a grid of cells.
///
/// This is the "reader" role in the pipeline: it is concerned only with turning
/// a file path into `List<List<String>>`. It performs no interpretation of the
/// data — that is the job of the structural parser.
class CsvReader {
  /// Creates a reader that decodes files using [encoding] (default UTF-8) and
  /// tokenizes them with a [CsvParser] configured for [delimiter].
  CsvReader({this.encoding = utf8, String delimiter = ','})
    : _parser = CsvParser(delimiter: delimiter);

  /// The text encoding used to decode the file bytes.
  final Encoding encoding;

  final CsvParser _parser;

  /// Reads and tokenizes the file at [path].
  ///
  /// Throws [InputReadException] if the file does not exist, is a directory, or
  /// cannot be read; throws [CsvFormatException] if the contents are malformed.
  Future<List<List<String>>> readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw InputReadException(path, 'Input file does not exist.');
    }
    final String contents;
    try {
      contents = await file.readAsString(encoding: encoding);
    } on FileSystemException catch (error) {
      throw InputReadException(
        path,
        'Could not read input file: ${error.message}',
      );
    }
    return _parser.parse(_stripBom(contents));
  }

  /// Tokenizes already-loaded CSV [text]. Useful for tests and for callers that
  /// obtain the CSV from somewhere other than the local filesystem.
  List<List<String>> readString(String text) => _parser.parse(_stripBom(text));

  /// Removes a leading UTF-8/UTF-16 byte-order mark if present. Spreadsheet
  /// exports frequently include one, which would otherwise corrupt the very
  /// first (anchor) cell.
  String _stripBom(String text) =>
      text.startsWith('﻿') ? text.substring(1) : text;
}
