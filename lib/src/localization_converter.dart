/// High-level facade over the read → parse → write pipeline.
library;

import 'model/localization_bundle.dart';
import 'parser/sheet_parser.dart';
import 'parser_config.dart';
import 'reader/csv_reader.dart';
import 'writer/json_writer.dart';

/// A summary of a completed conversion, handy for CLI output and tests.
class ConversionResult {
  /// Creates a conversion result.
  const ConversionResult({
    required this.inputPath,
    required this.outputDirectory,
    required this.outputPaths,
    required this.bundle,
  });

  /// The CSV file that was read.
  final String inputPath;

  /// The directory the JSON files were written to.
  final String outputDirectory;

  /// The JSON files written, in language order.
  final List<String> outputPaths;

  /// The parsed data, exposed so callers can inspect keys/counts.
  final LocalizationBundle bundle;

  /// The language codes that were exported.
  Iterable<String> get languageCodes => bundle.languageCodes;
}

/// The main entry point most callers should use.
///
/// [LocalizationConverter] composes the three single-responsibility components
/// — [CsvReader] (read), [SheetParser] (parse) and [JsonWriter] (write) — into
/// one convenient call while still letting advanced callers swap any stage.
///
/// ```dart
/// final result = await LocalizationConverter().convertFile(
///   'input/localizations.csv',
///   'build/localizations',
/// );
/// print('Wrote ${result.outputPaths.length} files.');
/// ```
class LocalizationConverter {
  /// Creates a converter.
  ///
  /// Any stage can be overridden for testing or customization; sensible
  /// defaults derived from [config] are used otherwise.
  factory LocalizationConverter({
    ParserConfig? config,
    CsvReader? reader,
    SheetParser? parser,
    JsonWriter? writer,
  }) {
    final resolvedConfig = config ?? ParserConfig();
    return LocalizationConverter._(
      resolvedConfig,
      reader ?? CsvReader(delimiter: resolvedConfig.fieldDelimiter),
      parser ?? SheetParser(resolvedConfig),
      writer ?? const JsonWriter(),
    );
  }

  LocalizationConverter._(
    this.config,
    this._reader,
    this._parser,
    this._writer,
  );

  /// The active configuration.
  final ParserConfig config;

  final CsvReader _reader;
  final SheetParser _parser;
  final JsonWriter _writer;

  /// Reads the CSV at [inputPath], parses it and writes one JSON file per
  /// language into [outputDirectory].
  ///
  /// Both paths are parameters — nothing is hardcoded — so the same converter
  /// works for any sheet. Propagates any `LocalizationSheetsException`.
  Future<ConversionResult> convertFile(
    String inputPath,
    String outputDirectory,
  ) async {
    final grid = await _reader.readFile(inputPath);
    return _convertGrid(grid, inputPath, outputDirectory);
  }

  /// Parses already-loaded CSV [text] and writes one JSON file per language
  /// into [outputDirectory].
  ///
  /// Use this when the CSV comes from somewhere other than the local filesystem
  /// — for example a spreadsheet downloaded over the network. [inputLabel] is a
  /// human-readable description of where the text came from (a URL, say) and is
  /// echoed back on the [ConversionResult]; it is never opened as a file.
  Future<ConversionResult> convertText(
    String text,
    String outputDirectory, {
    String inputLabel = '<memory>',
  }) async {
    final grid = _reader.readString(text);
    return _convertGrid(grid, inputLabel, outputDirectory);
  }

  /// Parses in-memory CSV [text] without touching the filesystem for input.
  /// Useful for embedding the parser in other tools or tests.
  LocalizationBundle parseString(String text) =>
      _parser.parse(_reader.readString(text));

  /// Shared parse-and-write tail for [convertFile] and [convertText].
  Future<ConversionResult> _convertGrid(
    List<List<String>> grid,
    String inputLabel,
    String outputDirectory,
  ) async {
    final bundle = _parser.parse(grid);
    final result = await _writer.write(bundle, outputDirectory);
    return ConversionResult(
      inputPath: inputLabel,
      outputDirectory: outputDirectory,
      outputPaths: result.paths,
      bundle: bundle,
    );
  }
}
