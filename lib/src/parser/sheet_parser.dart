/// The structural parser: grid in, [LocalizationBundle] out.
library;

import '../model/localization_bundle.dart';
import '../parser_config.dart';
import 'anchor_locator.dart';
import 'column_classifier.dart';
import 'column_schema.dart';
import 'tree_builder.dart';

/// Orchestrates the three structural steps — anchoring, column classification
/// and tree building — into a single call.
///
/// This class holds no IO. It turns a raw grid (`List<List<String>>`, typically
/// produced by a `CsvReader`) into a [LocalizationBundle]. Splitting the work
/// into [AnchorLocator], [ColumnClassifier] and [TreeBuilder] keeps each concern
/// independently testable; [SheetParser] simply wires them together.
class SheetParser {
  /// Creates a parser using [config] (or defaults when omitted).
  factory SheetParser([ParserConfig? config]) =>
      SheetParser._(config ?? ParserConfig());

  SheetParser._(this.config)
    : _locator = AnchorLocator(config),
      _classifier = ColumnClassifier(config),
      _builder = TreeBuilder(config);

  /// The active configuration.
  final ParserConfig config;

  final AnchorLocator _locator;
  final ColumnClassifier _classifier;
  final TreeBuilder _builder;

  /// Parses [grid] into a [LocalizationBundle].
  ///
  /// Throws any of the [LocalizationSheetsException] subtypes — see
  /// [AnchorLocator], [ColumnClassifier] and [TreeBuilder] for the specific
  /// failure conditions.
  LocalizationBundle parse(List<List<String>> grid) {
    final anchor = _locator.locate(grid);
    final ColumnSchema schema = _classifier.classify(grid, anchor);
    final translations = _builder.build(grid, schema, anchor);
    return LocalizationBundle(
      translations: translations,
      nestedKeyDepth: schema.nestedColumnIndices.length,
    );
  }
}
