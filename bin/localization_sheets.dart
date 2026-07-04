/// Command-line entry point for the `localization_sheets` tool.
///
/// Run `dart run localization_sheets --help` for usage.
library;

import 'dart:convert';
import 'dart:io';

import 'package:localization_sheets/localization_sheets.dart';
import 'package:yaml/yaml.dart';

/// The package version, kept in sync with `pubspec.yaml`.
const String _version = '0.1.0';

/// The config file the tool looks for in the current working directory when
/// `--config` is not given.
const String _defaultConfigFile = 'localization_sheets.yaml';

/// Standard `sysexits.h` exit codes used to signal the failure category.
const int _exitUsage = 64; // EX_USAGE — bad command line
const int _exitDataError = 65; // EX_DATAERR — malformed input data
const int _exitNoInput = 66; // EX_NOINPUT — input file missing/unreadable
const int _exitSoftware = 70; // EX_SOFTWARE — unexpected internal error
const int _exitCantCreate = 73; // EX_CANTCREAT — cannot create output

Future<void> main(List<String> arguments) async {
  final _Options options;
  try {
    options = _Options.parse(arguments);
  } on _UsageException catch (error) {
    stderr.writeln('Error: ${error.message}\n');
    stderr.writeln(_usage);
    exitCode = _exitUsage;
    return;
  }

  if (options.showHelp) {
    stdout.writeln(_usage);
    return;
  }
  if (options.showVersion) {
    stdout.writeln('localization_sheets $_version');
    return;
  }

  // Resolve the effective settings from CLI flags layered over the optional
  // config file (CLI wins).
  final _Settings settings;
  try {
    final config = _loadConfig(options);
    settings = _Settings.resolve(options, config);
  } on _UsageException catch (error) {
    stderr.writeln('Error: ${error.message}\n');
    stderr.writeln(_usage);
    exitCode = _exitUsage;
    return;
  } on LocalizationSheetsException catch (error) {
    stderr.writeln('Error: ${error.message}');
    exitCode = _exitDataError;
    return;
  }

  try {
    final converter = LocalizationConverter(config: ParserConfig());
    final source = settings.input;
    final ConversionResult result;
    if (source.isUrl) {
      stdout.writeln('Downloading ${source.location} …');
      final csv = await _download(source.location);
      result = await converter.convertText(
        csv,
        settings.outputDirectory,
        inputLabel: source.location,
      );
    } else {
      result = await converter.convertFile(
        source.location,
        settings.outputDirectory,
      );
    }
    _reportSuccess(result);
    if (settings.checkMissing) _reportMissing(result);
  } on LocalizationSheetsException catch (error) {
    stderr.writeln('Error: ${error.message}');
    exitCode = _exitCodeFor(error);
    return;
  } catch (error) {
    // Anything not modelled by the package is an internal error.
    stderr.writeln('Unexpected error: $error');
    exitCode = _exitSoftware;
    return;
  }

  // The conversion succeeded; run any post-write hook commands in order.
  await _runAfterCommands(settings.afterCommands);
}

/// Runs each command in [commands] through the platform shell, in order, after
/// a successful conversion. Output is inherited so the commands write directly
/// to the terminal.
///
/// Stops at the first command that exits non-zero and sets [exitCode] to that
/// command's exit code, so a failing hook fails the whole run.
Future<void> _runAfterCommands(List<String> commands) async {
  for (final command in commands) {
    stdout.writeln('\nRunning: $command');
    final Process process;
    try {
      process = Platform.isWindows
          ? await Process.start('cmd', [
              '/c',
              command,
            ], mode: ProcessStartMode.inheritStdio)
          : await Process.start('/bin/sh', [
              '-c',
              command,
            ], mode: ProcessStartMode.inheritStdio);
    } on ProcessException catch (error) {
      stderr.writeln('Error: could not run "$command": ${error.message}');
      exitCode = _exitSoftware;
      return;
    }

    final code = await process.exitCode;
    if (code != 0) {
      stderr.writeln('Error: command "$command" exited with code $code.');
      exitCode = code;
      return;
    }
  }
}

/// Downloads the CSV at [url] using `dart:io`'s [HttpClient], following the
/// redirects that spreadsheet-export URLs (e.g. Google Sheets) rely on.
///
/// Throws [InputReadException] on any network or HTTP error so the failure is
/// reported the same way a missing local file would be.
Future<String> _download(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    throw InputReadException(url, 'Input URL is not a valid absolute URL.');
  }

  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw InputReadException(
        url,
        'Download failed with HTTP ${response.statusCode}.',
      );
    }
    return await response.transform(utf8.decoder).join();
  } on SocketException catch (error) {
    throw InputReadException(url, 'Could not reach the URL: ${error.message}');
  } on HttpException catch (error) {
    throw InputReadException(url, 'HTTP error: ${error.message}');
  } finally {
    client.close();
  }
}

/// Reads and parses the config file, or returns `null` when none applies.
///
/// The file is read when `--config` names it, or — when `--config` is absent —
/// when the default [_defaultConfigFile] exists in the current directory. An
/// explicit `--config` that points at a missing file is an error; the implicit
/// default simply being absent is not.
_Config? _loadConfig(_Options options) {
  final explicit = options.configPath != null;
  final path = options.configPath ?? _defaultConfigFile;
  final file = File(path);
  if (!file.existsSync()) {
    if (explicit) {
      throw InputReadException(path, 'Config file does not exist.');
    }
    return null;
  }

  final YamlNode doc;
  try {
    doc = loadYamlNode(file.readAsStringSync(), sourceUrl: Uri.file(path));
  } on YamlException catch (error) {
    throw InputReadException(path, 'Could not parse config: ${error.message}');
  }
  return _Config.fromYaml(path, doc);
}

/// Prints a concise summary of a successful conversion to stdout.
void _reportSuccess(ConversionResult result) {
  stdout.writeln('Parsed ${result.inputPath}');
  stdout.writeln(
    'Nested-key depth: ${result.bundle.nestedKeyDepth}  '
    'Languages: ${result.languageCodes.length}',
  );
  for (final path in result.outputPaths) {
    final code = _languageOf(path);
    stdout.writeln('  → $path  (${result.bundle.leafCountFor(code)} keys)');
  }
}

/// Warns about keys translated in the primary (first) language but missing or
/// empty in the other languages. Prints to stderr so warnings stand out from
/// the normal success summary and can be redirected independently.
void _reportMissing(ConversionResult result) {
  final missing = result.bundle.findMissingTranslations();
  final primary = result.bundle.primaryLanguageCode;
  if (missing.isEmpty) {
    stdout.writeln('All languages cover the primary language "$primary".');
    return;
  }

  stderr.writeln(
    '\nWarning: keys present in the primary language "$primary" are missing '
    'or empty in other languages:',
  );
  for (final entry in missing.entries) {
    stderr.writeln('  ${entry.key} — ${entry.value.length} missing:');
    for (final path in entry.value) {
      stderr.writeln('    - $path');
    }
  }
}

/// Extracts the `en` from `.../en.json` for the per-file key count.
String _languageOf(String path) {
  final slash = path.lastIndexOf(RegExp(r'[/\\]'));
  final file = slash == -1 ? path : path.substring(slash + 1);
  return file.endsWith('.json')
      ? file.substring(0, file.length - '.json'.length)
      : file;
}

/// Maps a package exception to the appropriate process exit code.
int _exitCodeFor(LocalizationSheetsException error) => switch (error) {
  InputReadException() => _exitNoInput,
  OutputWriteException() => _exitCantCreate,
  _ => _exitDataError,
};

/// An input source: either a local file path or a remote URL to download.
class _InputSource {
  const _InputSource.file(this.location) : isUrl = false;
  const _InputSource.url(this.location) : isUrl = true;

  /// The file path (when [isUrl] is false) or full URL (when true).
  final String location;

  /// Whether [location] is a URL that must be downloaded before parsing.
  final bool isUrl;
}

/// The effective settings after layering CLI flags over the config file.
class _Settings {
  const _Settings({
    required this.input,
    required this.outputDirectory,
    required this.checkMissing,
    required this.afterCommands,
  });

  final _InputSource input;
  final String outputDirectory;
  final bool checkMissing;

  /// Shell commands to run, in order, after a successful conversion.
  final List<String> afterCommands;

  /// Resolves the input source and output directory from [options] (CLI) and
  /// [config] (file), with CLI values taking precedence.
  ///
  /// Throws [_UsageException] when no input is specified or when conflicting
  /// inputs (both a file and a URL) are given on the command line.
  factory _Settings.resolve(_Options options, _Config? config) {
    if (options.inputPath != null && options.inputUrl != null) {
      throw _UsageException(
        'Specify only one of --input (file) or --url (remote).',
      );
    }

    final _InputSource input;
    if (options.inputUrl != null) {
      input = _InputSource.url(options.inputUrl!);
    } else if (options.inputPath != null) {
      input = _InputSource.file(options.inputPath!);
    } else if (config?.input != null) {
      input = config!.input!;
    } else {
      throw _UsageException(
        'Missing input. Provide --input <path> or --url <url>, or add an '
        '"input:" section to $_defaultConfigFile.',
      );
    }

    final output = options.outputDirectory ?? config?.output ?? _defaultOutput;
    final checkMissing =
        options.checkMissing || (config?.checkMissing ?? false);
    // CLI --after flags override the config's "after:" list when given;
    // otherwise fall back to the config (or nothing).
    final afterCommands = options.afterCommands.isNotEmpty
        ? options.afterCommands
        : (config?.afterCommands ?? const <String>[]);
    return _Settings(
      input: input,
      outputDirectory: output,
      checkMissing: checkMissing,
      afterCommands: afterCommands,
    );
  }

  static const String _defaultOutput = 'output';
}

/// The subset of the config file the CLI understands.
///
/// Schema (all fields optional):
///
/// ```yaml
/// input:
///   type: url            # "file" or "url"
///   url: https://…       # required when type: url
///   path: input/x.csv    # required when type: file
/// output: assets/translations
/// check_missing: true
/// run_after: dart format assets/translations   # or a list of commands
/// ```
class _Config {
  const _Config({
    this.input,
    this.output,
    this.checkMissing,
    this.afterCommands,
  });

  final _InputSource? input;
  final String? output;
  final bool? checkMissing;

  /// Shell commands to run after a successful conversion, or `null` when the
  /// config omits the `after:` key.
  final List<String>? afterCommands;

  /// Parses a config document loaded from [path]. Throws [InputReadException]
  /// (tagged with [path]) on any structural problem so the message points the
  /// user at the file to fix.
  factory _Config.fromYaml(String path, YamlNode doc) {
    if (doc is YamlScalar && doc.value == null) {
      // An empty file parses to a null scalar — treat it as an empty config.
      return const _Config();
    }
    if (doc is! YamlMap) {
      throw InputReadException(path, 'Config root must be a mapping.');
    }

    _InputSource? input;
    final rawInput = doc['input'];
    if (rawInput != null) {
      if (rawInput is! YamlMap) {
        throw InputReadException(path, '"input" must be a mapping.');
      }
      input = _inputFrom(path, rawInput);
    }

    return _Config(
      input: input,
      output: _stringOr(path, doc['output'], 'output'),
      checkMissing: _boolOr(path, doc['check_missing'], 'check_missing'),
      afterCommands: _commandsOr(path, doc['run_after'], 'run_after'),
    );
  }

  /// Parses the `run_after:` key, accepting either a single command string or a
  /// list of command strings. Returns `null` when the key is absent.
  static List<String>? _commandsOr(String path, Object? value, String field) {
    if (value == null) return null;
    if (value is String) return [value];
    if (value is YamlList) {
      final commands = <String>[];
      for (final item in value.nodes) {
        final command = item.value;
        if (command is! String) {
          throw InputReadException(
            path,
            '"$field" list entries must be strings.',
          );
        }
        commands.add(command);
      }
      return commands;
    }
    throw InputReadException(
      path,
      '"$field" must be a string or a list of strings.',
    );
  }

  static _InputSource _inputFrom(String path, YamlMap node) {
    final type = _stringOr(path, node['type'], 'input.type');
    switch (type) {
      case 'url':
        final url = _stringOr(path, node['url'], 'input.url');
        if (url == null || url.isEmpty) {
          throw InputReadException(
            path,
            'input.url is required when type: url.',
          );
        }
        return _InputSource.url(url);
      case 'file':
        final filePath = _stringOr(path, node['path'], 'input.path');
        if (filePath == null || filePath.isEmpty) {
          throw InputReadException(
            path,
            'input.path is required when type: file.',
          );
        }
        return _InputSource.file(filePath);
      case null:
        throw InputReadException(path, 'input.type is required (file or url).');
      default:
        throw InputReadException(
          path,
          'input.type must be "file" or "url", got "$type".',
        );
    }
  }

  static String? _stringOr(String path, Object? value, String field) {
    if (value == null) return null;
    if (value is String) return value;
    throw InputReadException(path, '"$field" must be a string.');
  }

  static bool? _boolOr(String path, Object? value, String field) {
    if (value == null) return null;
    if (value is bool) return value;
    throw InputReadException(path, '"$field" must be a boolean.');
  }
}

/// Parsed command-line options (raw CLI flags, before merging with config).
class _Options {
  _Options({
    this.inputPath,
    this.inputUrl,
    this.outputDirectory,
    this.configPath,
    this.showHelp = false,
    this.showVersion = false,
    this.checkMissing = false,
    this.afterCommands = const [],
  });

  final String? inputPath;
  final String? inputUrl;
  final String? outputDirectory;
  final String? configPath;
  final bool showHelp;
  final bool showVersion;

  /// Whether to warn about keys present in the primary (first) language column
  /// but missing or empty in the other languages.
  final bool checkMissing;

  /// Shell commands to run, in order, after a successful conversion. Repeat
  /// `--run-after` on the command line to queue more than one.
  final List<String> afterCommands;

  /// Parses [arguments] into an [_Options], throwing [_UsageException] on any
  /// malformed flag or value.
  factory _Options.parse(List<String> arguments) {
    String? input;
    String? url;
    String? output;
    String? config;
    var help = false;
    var version = false;
    var checkMissing = false;
    final afterCommands = <String>[];

    // Reads the value for a flag, supporting both `--flag value` and
    // `--flag=value` forms.
    final iterator = arguments.iterator;
    String next(String flag, String? inlineValue) {
      if (inlineValue != null) return inlineValue;
      if (!iterator.moveNext()) {
        throw _UsageException('Option "$flag" expects a value.');
      }
      return iterator.current;
    }

    while (iterator.moveNext()) {
      final arg = iterator.current;
      final equals = arg.indexOf('=');
      final hasInline = arg.startsWith('--') && equals != -1;
      final name = hasInline ? arg.substring(0, equals) : arg;
      final inline = hasInline ? arg.substring(equals + 1) : null;

      switch (name) {
        case '-h' || '--help':
          help = true;
        case '-v' || '--version':
          version = true;
        case '-i' || '--input':
          input = next(name, inline);
        case '-u' || '--url':
          url = next(name, inline);
        case '-o' || '--output':
          output = next(name, inline);
        case '-c' || '--config':
          config = next(name, inline);
        case '--check-missing':
          checkMissing = true;
        case '-a' || '--run-after':
          afterCommands.add(next(name, inline));
        default:
          throw _UsageException('Unknown option "$arg".');
      }
    }

    return _Options(
      inputPath: input,
      inputUrl: url,
      outputDirectory: output,
      configPath: config,
      showHelp: help,
      showVersion: version,
      checkMissing: checkMissing,
      afterCommands: afterCommands,
    );
  }
}

/// Raised for command-line usage errors.
class _UsageException implements Exception {
  _UsageException(this.message);

  final String message;
}

const String _usage =
    '''
localization_sheets — CSV → per-language JSON converter

The first language column in the sheet is the primary language: it is the
source of truth for which keys must be translated.

The input can be a local CSV file (--input) or a remote CSV URL (--url) such as
a Google Sheets "export?format=csv" link, which is downloaded before parsing.
When no flags are given, settings are read from a "$_defaultConfigFile" file in
the current directory if it exists. Command-line flags override the config file.

USAGE:
  dart run localization_sheets [--input <csv> | --url <url>] [--output <dir>]
  dart run localization_sheets            # use ./$_defaultConfigFile

INPUT (one of; overrides the config file):
  -i, --input <path>          Path to a local source CSV file.
  -u, --url <url>             URL of a CSV to download and convert.

OPTIONS:
  -o, --output <dir>          Output directory (default: ./output).
  -c, --config <path>         Config file (default: ./$_defaultConfigFile).
      --check-missing         Warn about keys present in the primary (first)
                              language but missing/empty in other languages.
  -a, --run-after <command>   Shell command to run after a successful write.
                              Repeat to run several, in order. Overrides the
                              config file's "run_after:" list when given. A hook
                              that fails stops the rest and fails the run.
  -h, --help                  Show this help.
  -v, --version               Show the version.

CONFIG FILE ($_defaultConfigFile):
  input:
    type: url                 # "file" or "url"
    url: https://docs.google.com/spreadsheets/d/{YOUR_ID}/export?format=csv
    # type: file
    # path: input/localizations.csv
  output: assets/translations
  check_missing: true
  run_after: dart format assets/translations   # a string, or a list:
  # run_after:
  #   - dart format assets/translations
  #   - git add assets/translations

EXAMPLES:
  dart run localization_sheets -i input/localizations.csv -o build/l10n
  dart run localization_sheets -u "https://docs.google.com/spreadsheets/d/{YOUR_ID}/export?format=csv" -o assets/translations
  dart run localization_sheets -i input/localizations.csv -a "dart format output" --run-after "git add output"
''';
