import 'package:localization_sheets/localization_sheets.dart';
import 'package:test/test.dart';

void main() {
  group('LocalizationBundle.findMissingTranslations', () {
    test('reports keys blank or absent in non-primary languages', () {
      // en is the first (primary) column; de and fr follow.
      final bundle = LocalizationConverter().parseString('''
key,nested_key,en,de,fr
app_title,,My App,Meine App,
money_apple,one,{} apple,{} Apfel,{} pomme
,other,{} apples,,{} pommes
''');

      expect(bundle.primaryLanguageCode, 'en');

      final missing = bundle.findMissingTranslations();
      expect(missing['fr'], ['app_title']);
      expect(missing['de'], ['money_apple.other']);
    });

    test('returns empty when every language covers the primary', () {
      final bundle = LocalizationConverter().parseString('''
key,en,de
a,Hello,Hallo
b,Bye,Tschüss
''');

      expect(bundle.findMissingTranslations(), isEmpty);
    });

    test('a key blank in the primary language is not required elsewhere', () {
      final bundle = LocalizationConverter().parseString('''
key,en,de
a,,Hallo
b,Hi,Hallo
''');

      expect(bundle.findMissingTranslations(), isEmpty);
    });
  });
}
