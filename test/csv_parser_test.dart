import 'package:localization_sheets/localization_sheets.dart';
import 'package:test/test.dart';

void main() {
  group('CsvParser', () {
    const parser = CsvParser();

    test('parses simple rows', () {
      expect(parser.parse('a,b,c\n1,2,3'), [
        ['a', 'b', 'c'],
        ['1', '2', '3'],
      ]);
    });

    test('keeps commas inside quoted fields', () {
      expect(parser.parse('key,"Welcome {}, you have {} views.",x'), [
        ['key', 'Welcome {}, you have {} views.', 'x'],
      ]);
    });

    test('unescapes doubled quotes', () {
      expect(parser.parse('a,"she said ""hi""",b'), [
        ['a', 'she said "hi"', 'b'],
      ]);
    });

    test('supports newlines inside quoted fields', () {
      expect(parser.parse('a,"line1\nline2",b'), [
        ['a', 'line1\nline2', 'b'],
      ]);
    });

    test('handles CRLF line endings', () {
      expect(parser.parse('a,b\r\nc,d\r\n'), [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });

    test('does not emit a phantom trailing row for a final newline', () {
      expect(parser.parse('a,b\n').length, 1);
    });

    test('throws CsvFormatException on an unterminated quote', () {
      expect(() => parser.parse('a,"oops'), throwsA(isA<CsvFormatException>()));
    });

    test('respects a custom delimiter', () {
      expect(const CsvParser(delimiter: ';').parse('a;b;c'), [
        ['a', 'b', 'c'],
      ]);
    });
  });
}
