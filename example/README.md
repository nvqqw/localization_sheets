# localization_sheets example

Shows how to turn a Google-Sheets-style localization export into per-language
JSON files with the [`localization_sheets`](../) tool.

## Layout

- [`localization_sheets.yaml`](localization_sheets.yaml) — the CLI config. It is
  read automatically when you run the tool from this directory.
- [`input/localizations.csv`](input/localizations.csv) — a bundled sample CSV,
  used by the commented-out `type: file` config and by `bin/example.dart`.
- [`bin/example.dart`](bin/example.dart) — the same conversion done with the
  library API, so you can run it offline.
- `assets/translations/` — where the generated `<language>.json` files land.

## Run the CLI (reads the config file)

```sh
dart pub get
dart run localization_sheets
```

With no flags the tool reads `localization_sheets.yaml`, which by default
**downloads** this public sheet:

```
https://docs.google.com/spreadsheets/d/1sdF7zHtyTCoxlX5DPTxtRde2N6Y1fxgQKilAcSA-WU8/export?format=csv
```

and writes `assets/translations/en.json`, `assets/translations/de.json`, …

### Input types

The config supports two input types; switch between them by editing
`localization_sheets.yaml`:

```yaml
input:
  type: url                       # download a remote CSV before parsing
  url: https://…/export?format=csv

# or:
# input:
#   type: file                    # read a local CSV from disk
#   path: input/localizations.csv
```

Command-line flags override the config file:

```sh
# Convert a local file:
dart run localization_sheets --input input/localizations.csv --output assets/translations

# Convert a URL:
dart run localization_sheets --url "https://…/export?format=csv" --output assets/translations
```

## Run the library example (offline)

```sh
dart pub get
dart run bin/example.dart
```
