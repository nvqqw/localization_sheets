@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// Integration tests for the `--run-after` / `run_after:` post-write command
/// hook.
///
/// The hook lives entirely in the CLI entry point ([bin/localization_sheets.dart]),
/// wiring private option/config classes to `Process.start`, so it is exercised
/// by running the compiled CLI as a subprocess rather than through the library.
void main() {
  // A tiny, self-contained sheet so the tests do not depend on the bundled
  // example fixture layout.
  const csv =
      'key,en,de\n'
      'hello,Hello,Hallo\n';

  late Directory work;

  setUp(() {
    work = Directory.systemTemp.createTempSync('locsheets_after_test');
    File('${work.path}/in.csv').writeAsStringSync(csv);
  });

  tearDown(() {
    if (work.existsSync()) work.deleteSync(recursive: true);
  });

  // `sh -c` / `cmd /c` differ, so build a command that appends a marker line to
  // a file the test can read back — portable across the shells the CLI uses.
  String appendTo(String file, String text) {
    return Platform.isWindows
        ? 'echo $text>>"$file"'
        : "printf '%s\\n' '$text' >> '$file'";
  }

  Future<ProcessResult> runCli(List<String> args) {
    // `dart run bin/localization_sheets.dart` from the package root.
    return Process.run('dart', [
      'run',
      'bin/localization_sheets.dart',
      ...args,
    ]);
  }

  test('runs a single --run-after command after a successful write', () async {
    final marker = '${work.path}/marker.txt';
    final result = await runCli([
      '--input',
      '${work.path}/in.csv',
      '--output',
      '${work.path}/out',
      '--run-after',
      appendTo(marker, 'ran'),
    ]);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File('${work.path}/out/en.json').existsSync(), isTrue);
    expect(File(marker).readAsStringSync().trim(), 'ran');
  });

  test('runs multiple --run-after commands in order', () async {
    final marker = '${work.path}/marker.txt';
    final result = await runCli([
      '--input',
      '${work.path}/in.csv',
      '--output',
      '${work.path}/out',
      '--run-after',
      appendTo(marker, 'first'),
      '--run-after',
      appendTo(marker, 'second'),
    ]);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File(marker).readAsLinesSync().where((l) => l.isNotEmpty).toList(), [
      'first',
      'second',
    ]);
  });

  test(
    'a failing command stops the rest and fails with its exit code',
    () async {
      final marker = '${work.path}/marker.txt';
      final result = await runCli([
        '--input',
        '${work.path}/in.csv',
        '--output',
        '${work.path}/out',
        '--run-after',
        'exit 3',
        '--run-after',
        appendTo(marker, 'should-not-run'),
      ]);

      expect(result.exitCode, 3);
      // The output was still written before the hooks ran…
      expect(File('${work.path}/out/en.json').existsSync(), isTrue);
      // …but the second hook never executed.
      expect(File(marker).existsSync(), isFalse);
    },
  );

  test('reads a run_after: list from the config file', () async {
    final marker = '${work.path}/marker.txt';
    File('${work.path}/cfg.yaml').writeAsStringSync('''
input:
  type: file
  path: ${work.path}/in.csv
output: ${work.path}/out
run_after:
  - ${appendTo(marker, 'A')}
  - ${appendTo(marker, 'B')}
''');

    final result = await runCli(['--config', '${work.path}/cfg.yaml']);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File(marker).readAsLinesSync().where((l) => l.isNotEmpty).toList(), [
      'A',
      'B',
    ]);
  });

  test('a config run_after: string is treated as a single command', () async {
    final marker = '${work.path}/marker.txt';
    File('${work.path}/cfg.yaml').writeAsStringSync('''
input:
  type: file
  path: ${work.path}/in.csv
output: ${work.path}/out
run_after: ${appendTo(marker, 'solo')}
''');

    final result = await runCli(['--config', '${work.path}/cfg.yaml']);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File(marker).readAsStringSync().trim(), 'solo');
  });

  test('--run-after on the CLI overrides the config run_after: list', () async {
    final marker = '${work.path}/marker.txt';
    File('${work.path}/cfg.yaml').writeAsStringSync('''
input:
  type: file
  path: ${work.path}/in.csv
output: ${work.path}/out
run_after: ${appendTo(marker, 'from-config')}
''');

    final result = await runCli([
      '--config',
      '${work.path}/cfg.yaml',
      '--run-after',
      appendTo(marker, 'from-cli'),
    ]);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File(marker).readAsStringSync().trim(), 'from-cli');
  });
}
