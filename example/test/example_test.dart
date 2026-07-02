import 'package:localization_sheets/localization_sheets.dart';
import 'package:test/test.dart';

void main() {
  test('converts a sample CSV into per-language trees', () {
    final bundle = LocalizationConverter().parseString('''
key,nested_key,en,de,#description
app_title,,My Awesome App,Meine tolle App,note for translators
''');

    expect(bundle.languageCodes, containsAll(['en', 'de']));
    expect(bundle.translations['en']!['app_title'], 'My Awesome App');
    expect(bundle.translations['de']!['app_title'], 'Meine tolle App');
  });
}
