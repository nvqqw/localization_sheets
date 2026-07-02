import 'dart:convert';
import 'dart:io';

import 'package:localization_sheets/localization_sheets.dart';
import 'package:test/test.dart';

void main() {
  group('LocalizationConverter.convertFile', () {
    late Directory tempDir;

    setUp(() => tempDir = Directory.systemTemp.createTempSync('l10n_test_'));
    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
      'writes one pretty JSON file per language, reloadable as JSON',
      () async {
        final input = File('${tempDir.path}/in.csv')
          ..writeAsStringSync('''
metadata,,,
key,nested_key,en,#note
app,,"Hi, there",ignore me
plural,one,{} item,
,other,{} items,
''');
        final outDir = '${tempDir.path}/out';

        final result = await LocalizationConverter().convertFile(
          input.path,
          outDir,
        );

        expect(result.languageCodes, ['en']);
        expect(result.outputPaths.single, endsWith('en.json'));
        expect(result.bundle.leafCountFor('en'), 3);

        final decoded = jsonDecode(
          File(result.outputPaths.single).readAsStringSync(),
        );
        expect(decoded, {
          'app': 'Hi, there',
          'plural': {'one': '{} item', 'other': '{} items'},
        });
      },
    );

    test('throws InputReadException for a missing input file', () {
      expect(
        () => LocalizationConverter().convertFile(
          'does/not/exist.csv',
          tempDir.path,
        ),
        throwsA(isA<InputReadException>()),
      );
    });

    test('creates the output directory if it does not exist', () async {
      final input = File('${tempDir.path}/in.csv')
        ..writeAsStringSync('key,en\na,Hello\n');
      final nested = '${tempDir.path}/a/b/c';

      await LocalizationConverter().convertFile(input.path, nested);

      expect(File('$nested/en.json').existsSync(), isTrue);
    });
  });
}
