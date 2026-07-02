## 0.1.0

Initial release.

- CSV → per‑language JSON converter, available as a CLI (`localization_sheets`)
  and as a library (`LocalizationConverter`).
- Metadata anchoring on the `key` cell (rows above / columns left are ignored).
- Arbitrarily deep "YAML‑in‑CSV" nested keys with carry‑down inheritance.
- Configurable comment columns/rows and ignored keys (both `#` by default) via
  regex.
- One `{language_code}.json` file per language column, with a configurable
  output directory, pretty‑printing and empty‑value handling.
- Typed exception hierarchy (`LocalizationSheetsException`) and standard CLI
  exit codes.
- Hand‑written, pure‑Dart RFC‑4180 CSV parser. The core library has no runtime
  dependencies; the CLI uses the `yaml` package to read its optional config file.
