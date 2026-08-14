# 検証記録

## この環境で完了した確認

| 確認項目 | 結果 | 内容 |
|---|---|---|
| 必須ファイル | 成功 | SwiftDataモデル、通知サービス、テスト、SwiftLint設定、GitHub Actions設定、XcodeGen設定の存在を確認しました。 |
| 危険な強制記述 | 成功 | `try!`、`as!`、強制アンラップの代表的なパターンがSwiftソースにないことを確認しました。 |
| 行長 | 成功 | `.swiftlint.yml`の警告閾値である140文字を超えるSwiftコード行がないことを確認しました。 |
| ローカライズキー | 成功 | 日本語・英語の各`Localizable.strings`内に重複キーがないことを確認しました。 |
| アーカイブ | 成功 | 実装、設定、テスト、READMEを含むZIPアーカイブを生成しました。 |

## macOSで自動実行される確認

SwiftLintとiOS Simulatorを必要とする完全な検証は、Ubuntuベースの作業環境では実行できません。このため、次の自動品質ゲートをプロジェクトへ設定済みです。

| 実行場所 | 実行内容 |
|---|---|
| Xcodeのビルド前 | SwiftLintを実行します。未導入の場合は警告を表示します。 |
| `make verify` | XcodeGen、SwiftLintの厳格実行、iOS Simulator上のユニットテストを順に実行します。 |
| GitHub Actions（macOS） | pull requestと`main`へのpushでXcodeGen、SwiftLint、`xcodebuild test`を実行します。 |

ローカルMacで初回検証する際は、`brew install xcodegen swiftlint`の後に`make verify`を実行してください。
