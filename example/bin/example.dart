// A runnable example for the localization_sheets package.
//
// PRIMARY USAGE — the CLI driven by `localization_sheets.yaml`.
// The main way to use this tool is the command line reading the config file in
// this directory, ../localization_sheets.yaml. It declares the input (a remote
// Google Sheet URL by default, or a local file), the output directory and the
// options, so the whole conversion is just:
//
//   dart pub get
//   dart run localization_sheets
//
// That downloads the configured sheet and writes one JSON file per language
// into `assets/translations/` — no code required. Edit the YAML to change the
// input, output or options. See ../localization_sheets.yaml and ../README.md.
//
// OPTIONAL — importing the library in your own Dart/Flutter project.
// If you'd rather run the conversion from code (e.g. a build step), import the
// package and call it directly, as below. This program converts the bundled
// sample CSV so it runs offline; the remote-URL variant is shown in comments at
// the end.
import 'package:localization_sheets/localization_sheets.dart';

Future<void> main() async {
  final converter = LocalizationConverter();

  // Convert a local CSV file straight to disk. Mirrors the commented-out
  // `type: file` block in localization_sheets.yaml.
  final result = await converter.convertFile(
    'input/localizations.csv',
    'assets/translations',
  );

  print('Parsed ${result.inputPath}');
  print('Languages: ${result.languageCodes.join(', ')}');
  for (final path in result.outputPaths) {
    print('  → $path');
  }

  // To convert the remote Google Sheet instead (the active `type: url` config),
  // download the CSV first and hand the text to `convertText`. This is exactly
  // what `dart run localization_sheets` does under the hood:
  //
  // import 'dart:convert';
  // import 'dart:io';
  //
  // const url =
  //     'https://docs.google.com/spreadsheets/d/1sdF7zHtyTCoxlX5DPTxtRde2N6Y1fxgQKilAcSA-WU8/export?format=csv';
  // final client = HttpClient();
  // final response = await (await client.getUrl(Uri.parse(url))).close();
  // final csv = await response.transform(utf8.decoder).join();
  // client.close();
  // final remote = await converter.convertText(
  //   csv,
  //   'assets/translations',
  //   inputLabel: url,
  // );
  // print('Wrote: ${remote.outputPaths}');
}
