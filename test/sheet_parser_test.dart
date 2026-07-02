import 'package:localization_sheets/localization_sheets.dart';
import 'package:test/test.dart';

/// Parses [csv] with [config] and returns the per-language trees.
Map<String, TranslationTree> parse(String csv, {ParserConfig? config}) =>
    LocalizationConverter(config: config).parseString(csv).translations;

void main() {
  group('anchoring & metadata', () {
    test('ignores rows above and columns left of the "key" anchor', () {
      const csv = '''
free text note,,,
,ignored metadata,,
notes,key,en,de
notes,app_title,Hello,Hallo
''';
      final trees = parse(csv);
      expect(trees['en'], {'app_title': 'Hello'});
      expect(trees['de'], {'app_title': 'Hallo'});
    });

    test('throws AnchorNotFoundException when no key cell exists', () {
      expect(
        () => parse('a,b,c\n1,2,3'),
        throwsA(isA<AnchorNotFoundException>()),
      );
    });

    test('throws NoLanguageColumnsException when only key/nested exist', () {
      expect(
        () => parse('key,nested_key\napp,x'),
        throwsA(isA<NoLanguageColumnsException>()),
      );
    });
  });

  group('nesting (YAML-in-CSV)', () {
    const csv = '''
key,nested_key,en
app_title,,My App
money,zero,no apples
,one,one apple
,other,{} apples
next,,done
''';

    test('builds nested objects and carries the parent key down', () {
      final trees = parse(csv);
      expect(trees['en'], {
        'app_title': 'My App',
        'money': {
          'zero': 'no apples',
          'one': 'one apple',
          'other': '{} apples',
        },
        'next': 'done',
      });
    });

    test('supports three levels of nesting with carry-down', () {
      const deep = '''
key,nested_key,nested_key_2,en
a,b,c,leaf1
,,d,leaf2
,e,f,leaf3
g,,,leaf4
''';
      final trees = parse(deep);
      expect(trees['en'], {
        'a': {
          'b': {'c': 'leaf1', 'd': 'leaf2'},
          'e': {'f': 'leaf3'},
        },
        'g': 'leaf4',
      });
    });
  });

  group('ignore rules', () {
    test('ignores comment rows (# in the key column)', () {
      const csv = '''
key,nested_key,en
#section note,,
real,,value
''';
      expect(parse(csv)['en'], {'real': 'value'});
    });

    test('ignores keys starting with # (default ignore marker)', () {
      const csv = '''
key,nested_key,en
#draft,,skip me
keep,,keep me
''';
      expect(parse(csv)['en'], {'keep': 'keep me'});
    });

    test('the ignore marker is configurable (e.g. ~ instead of #)', () {
      final config = ParserConfig(ignoreKeyPattern: RegExp(r'^~'));
      const csv = '''
key,nested_key,en
~draft,,skip me
keep,,keep me
''';
      expect(parse(csv, config: config)['en'], {'keep': 'keep me'});
    });

    test('ignores #-prefixed nested value rows', () {
      const csv = '''
key,nested_key,en
parent,#note,skip
parent,real,keep
''';
      expect(parse(csv)['en'], {
        'parent': {'real': 'keep'},
      });
    });

    test('comment column wins over nested-key detection (#nested_key)', () {
      const csv = '''
key,#nested_key,en,de
app,ignored,Hello,Hallo
''';
      // The #nested_key column is dropped, so there is no nesting and the
      // "ignored" cell is not treated as a key path segment.
      final trees = parse(csv);
      expect(trees['en'], {'app': 'Hello'});
      expect(trees['de'], {'app': 'Hallo'});
    });

    test('drops #comment language/description columns from output', () {
      const csv = '''
key,en,#description
app,Hello,translator note
''';
      final trees = parse(csv);
      expect(trees.keys, ['en']);
      expect(trees['en'], {'app': 'Hello'});
    });
  });

  group('configuration', () {
    test('nestedKeyColumnCount forces nesting regardless of header name', () {
      const csv = '''
key,sub,en
a,b,leaf
''';
      final trees = parse(csv, config: ParserConfig(nestedKeyColumnCount: 1));
      expect(trees['en'], {
        'a': {'b': 'leaf'},
      });
    });

    test('includeEmptyValues:false omits empty translations', () {
      const csv = '''
key,en,de
a,Hello,
''';
      final trees = parse(csv, config: ParserConfig(includeEmptyValues: false));
      expect(trees['en'], {'a': 'Hello'});
      expect(trees['de'], <String, Object?>{});
    });

    test('a custom comment marker can be configured', () {
      final config = ParserConfig(commentPattern: RegExp(r'^//'));
      const csv = '''
key,en
//a comment row,
a,Hello
''';
      expect(parse(csv, config: config)['en'], {'a': 'Hello'});
    });
  });

  group('error handling', () {
    test('throws KeyConflictException on duplicate keys', () {
      const csv = '''
key,en
a,first
a,second
''';
      expect(() => parse(csv), throwsA(isA<KeyConflictException>()));
    });

    test('throws KeyConflictException when a leaf is reused as a parent', () {
      const csv = '''
key,nested_key,en
a,,leaf
a,child,oops
''';
      expect(() => parse(csv), throwsA(isA<KeyConflictException>()));
    });

    test('throws InvalidRowException when the first data row has no key', () {
      const csv = '''
key,nested_key,en
,child,orphan
''';
      expect(() => parse(csv), throwsA(isA<InvalidRowException>()));
    });

    test('throws MaxDepthExceededException past the configured depth', () {
      const csv = '''
key,nested_key,nested_key_2,en
a,b,c,leaf
''';
      expect(
        () => parse(csv, config: ParserConfig(maxDepth: 2)),
        throwsA(isA<MaxDepthExceededException>()),
      );
    });
  });
}
