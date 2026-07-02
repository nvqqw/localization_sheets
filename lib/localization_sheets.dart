/// Convert Google-Sheets-style localization CSV exports into per-language JSON.
///
/// The package is organised around three single-responsibility roles that can
/// be used together via [LocalizationConverter] or independently:
///
/// * **Read** — [CsvReader] turns a CSV file (or string) into a grid of cells.
/// * **Parse** — [SheetParser] anchors on the `key` cell, classifies the
///   columns and builds one nested [TranslationTree] per language.
/// * **Write** — [JsonWriter] serializes the result to `{code}.json` files.
///
/// Typical usage:
///
/// ```dart
/// import 'package:localization_sheets/localization_sheets.dart';
///
/// Future<void> main() async {
///   final result = await LocalizationConverter().convertFile(
///     'input/localizations.csv',
///     'build/localizations',
///   );
///   print('Exported: ${result.languageCodes.join(', ')}');
/// }
/// ```
///
/// Every knob (anchor label, comment marker, ignored-key marker, nesting depth,
/// delimiter, …) lives on [ParserConfig].
library;

export 'src/exceptions.dart';
export 'src/localization_converter.dart'
    show ConversionResult, LocalizationConverter;
export 'src/model/localization_bundle.dart'
    show LocalizationBundle, TranslationTree;
export 'src/parser/column_schema.dart'
    show ColumnRole, ColumnSchema, LanguageColumn;
export 'src/parser/sheet_parser.dart' show SheetParser;
export 'src/parser_config.dart' show ParserConfig;
export 'src/reader/csv_parser.dart' show CsvParser;
export 'src/reader/csv_reader.dart' show CsvReader;
export 'src/writer/json_writer.dart' show JsonWriter, WriteResult;
