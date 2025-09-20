# analyze_vscode_deps
VSCode拡張機能のnpmパッケージを分析するスクリプト

## 使い方

オプション | 説明
:-- | :--
-e, --extension EXTENSION | 特定の拡張機能のパッケージのみ表示
-d, --days DAYS | 指定した日数以内にインストールされたパッケージのみ表示
-s, --search PATTERN | パッケージ名で検索
-o, --old DAYS | 指定した日数より古いパッケージを表示
-c, --count | 拡張機能別のパッケージ数を表示
-h, --help | ヘルプを表示
