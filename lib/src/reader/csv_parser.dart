/// A small, dependency-free RFC 4180 CSV tokenizer.
library;

import '../exceptions.dart';

/// Parses raw CSV text into a rectangular-ish grid of string cells.
///
/// This tokenizer follows [RFC 4180](https://www.rfc-editor.org/rfc/rfc4180):
///
/// * Fields are separated by a configurable single-character [delimiter].
/// * Records are separated by `\n` or `\r\n`.
/// * A field may be wrapped in double quotes (`"`). Inside a quoted field the
///   delimiter, carriage returns, line feeds and doubled quotes (`""`, an
///   escaped quote) are all treated as literal content.
///
/// The parser is deliberately independent of file IO so it can be unit tested
/// with in-memory strings; see [CsvReader] for the file-loading wrapper.
class CsvParser {
  /// Creates a parser using [delimiter] (default comma) to separate fields.
  const CsvParser({this.delimiter = ','})
    : assert(delimiter.length == 1, 'delimiter must be a single character');

  /// The single character that separates fields within a record.
  final String delimiter;

  /// Converts [input] into a list of records, each a list of field values.
  ///
  /// Blank physical lines are preserved as single-empty-cell rows so that row
  /// numbers reported in errors line up with the source file. Callers that do
  /// not care about blank rows can filter them out afterwards.
  ///
  /// Throws [CsvFormatException] if a quoted field is never closed.
  List<List<String>> parse(String input) {
    final rows = <List<String>>[];
    final field = StringBuffer();
    var record = <String>[];
    var inQuotes = false;
    var lineNumber = 1;
    final delimiterChar = delimiter.codeUnitAt(0);

    const quote = 0x22; // "
    const cr = 0x0d; // \r
    const lf = 0x0a; // \n

    void endField() {
      record.add(field.toString());
      field.clear();
    }

    void endRecord() {
      endField();
      rows.add(record);
      record = <String>[];
    }

    final units = input.codeUnits;
    for (var i = 0; i < units.length; i++) {
      final char = units[i];

      if (inQuotes) {
        if (char == quote) {
          final isEscapedQuote = i + 1 < units.length && units[i + 1] == quote;
          if (isEscapedQuote) {
            field.writeCharCode(quote);
            i++; // consume the second quote of the "" escape sequence
          } else {
            inQuotes = false; // closing quote
          }
        } else {
          if (char == lf) lineNumber++;
          field.writeCharCode(char);
        }
        continue;
      }

      switch (char) {
        case quote:
          inQuotes = true;
        case final c when c == delimiterChar:
          endField();
        case cr:
          // Swallow \r; the following \n (if any) closes the record.
          final nextIsLf = i + 1 < units.length && units[i + 1] == lf;
          if (!nextIsLf) {
            endRecord(); // lone CR line ending
            lineNumber++;
          }
        case lf:
          endRecord();
          lineNumber++;
        default:
          field.writeCharCode(char);
      }
    }

    if (inQuotes) {
      throw CsvFormatException(
        lineNumber,
        'Unterminated quoted field — a closing double quote is missing.',
      );
    }

    // Flush the trailing record unless the input ended with a newline (which
    // already flushed it) and produced no dangling content.
    final endedWithNewline =
        units.isNotEmpty && (units.last == lf || units.last == cr);
    if (!endedWithNewline || field.isNotEmpty || record.isNotEmpty) {
      endRecord();
    }

    return rows;
  }
}
