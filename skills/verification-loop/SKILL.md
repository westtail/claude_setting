---
name: verification-loop
description: コード変更後の包括的な検証システム。ビルド、型チェック、Lint、テスト、セキュリティスキャンを段階的に実行。
---

# 検証ループスキル

Claude Codeセッション向けの包括的な検証システム。

## 使用タイミング

このスキルを呼び出す場面：

- 機能や重要なコード変更を完了した後
- PRを作成する前
- 品質ゲートの通過を確認したいとき
- リファクタリング後

## 検証フェーズ

### フェーズ1：ビルド検証

プロジェクトがビルドできるか確認：

```bash
# プロジェクトのビルドコマンドを実行
<build-command> 2>&1 | tail -20

# 例：
# npm run build
# go build ./...
# cargo build
# make build
# ./gradlew build
# bundle exec rake build
```

ビルドが失敗した場合、続行前に停止して修正。

### フェーズ2：型チェック

静的型チェックを実行（言語がサポートしている場合）：

```bash
# プロジェクトの型チェックコマンドを実行
<type-check-command> 2>&1 | head -30

# 例：
# npx tsc --noEmit          # TypeScript
# pyright .                  # Python
# mypy .                     # Python
# go vet ./...               # Go
# cargo check                # Rust
# bundle exec srb typecheck  # Ruby (Sorbet)
```

すべての型エラーを報告。続行前に重大なものを修正。

### フェーズ3：Lintチェック

コードスタイルと潜在的な問題をチェック：

```bash
# プロジェクトのLintコマンドを実行
<lint-command> 2>&1 | head -30

# 例：
# npm run lint               # JavaScript/TypeScript
# ruff check .               # Python
# golangci-lint run          # Go
# cargo clippy               # Rust
# bundle exec rubocop        # Ruby
```

### フェーズ4：テストスイート

テストを実行しカバレッジを確認：

```bash
# プロジェクトのテストコマンドを実行
<test-command> 2>&1 | tail -50

# 例：
# npm run test -- --coverage       # JavaScript/TypeScript
# pytest --cov=. --cov-report=term # Python
# go test -cover ./...             # Go
# cargo test                       # Rust
# bundle exec rspec --format doc   # Ruby
```

報告内容：

- 総テスト数：X
- 合格：X
- 失敗：X
- カバレッジ：X%（目標：最低80%）

### フェーズ5：セキュリティスキャン

潜在的なセキュリティ問題をチェック：

```bash
# ハードコードされたシークレットをチェック
grep -rn "sk-" --include="*.<ext>" . 2>/dev/null | head -10
grep -rn "api_key\s*=" --include="*.<ext>" . 2>/dev/null | head -10
grep -rn "password\s*=" --include="*.<ext>" . 2>/dev/null | head -10

# デバッグ用のprint/logをチェック
grep -rn "console.log\|print(" --include="*.<ext>" src/ 2>/dev/null | head -10

# 依存関係の脆弱性をチェック
# npm audit / pip-audit / go mod verify / cargo audit / bundler-audit
```

チェック項目：

- [ ] ハードコードされたAPIキー・トークン
- [ ] 残っているデバッグ出力
- [ ] 既知の脆弱性を持つ依存関係

### フェーズ6：差分レビュー

変更内容を確認：

```bash
# 変更の統計を表示
git diff --stat

# 変更されたファイル一覧
git diff HEAD~1 --name-only

# 変更内容の詳細（必要に応じて）
git diff HEAD~1
```

各変更ファイルを以下の観点でレビュー：

- 意図しない変更
- 不足しているエラーハンドリング
- 潜在的なエッジケース
- テストカバレッジ

## 出力フォーマット

すべてのフェーズ実行後、検証レポートを作成：

```
検証レポート
==================

ビルド:      [PASS/FAIL]
型:          [PASS/FAIL]（X件のエラー）
Lint:        [PASS/FAIL]（X件の警告）
テスト:      [PASS/FAIL]（X/Y合格、Z%カバレッジ）
セキュリティ: [PASS/FAIL]（X件の問題）
差分:        [X件のファイル変更]

総合:        PR [準備完了/未完了]

修正すべき問題：
1. ...
2. ...
```

## 検証フローチャート

```
開始
  │
  ▼
┌─────────────┐
│ ビルド検証   │──FAIL──▶ 修正して再実行
└─────────────┘
  │PASS
  ▼
┌─────────────┐
│ 型チェック   │──FAIL──▶ 修正して再実行
└─────────────┘
  │PASS
  ▼
┌─────────────┐
│ Lintチェック │──FAIL──▶ 修正して再実行
└─────────────┘
  │PASS
  ▼
┌─────────────┐
│ テスト実行   │──FAIL──▶ 修正して再実行
└─────────────┘
  │PASS
  ▼
┌─────────────┐
│ セキュリティ │──FAIL──▶ 修正して再実行
└─────────────┘
  │PASS
  ▼
┌─────────────┐
│ 差分レビュー │
└─────────────┘
  │
  ▼
PR準備完了
```

## 言語別コマンド早見表

| フェーズ   | JavaScript/TS     | Python           | Go                  | Ruby               | Rust           |
| ---------- | ----------------- | ---------------- | ------------------- | ------------------ | -------------- |
| ビルド     | `npm run build`   | -                | `go build ./...`    | `bundle exec rake` | `cargo build`  |
| 型チェック | `tsc --noEmit`    | `pyright`/`mypy` | `go vet ./...`      | `srb typecheck`    | `cargo check`  |
| Lint       | `eslint .`        | `ruff check .`   | `golangci-lint run` | `rubocop`          | `cargo clippy` |
| テスト     | `jest --coverage` | `pytest --cov`   | `go test -cover`    | `rspec`            | `cargo test`   |
| 監査       | `npm audit`       | `pip-audit`      | `go mod verify`     | `bundler-audit`    | `cargo audit`  |

## 継続モード

長いセッションでは、15分ごとまたは大きな変更後に検証を実行：

```markdown
メンタルチェックポイントを設定：

- 各関数の完成後
- モジュール/コンポーネントの完成後
- 次のタスクに移る前

実行: /verify
```

## 重大度による優先順位

問題が見つかった場合の修正優先順位：

1. **ビルドエラー** - 最優先で修正
2. **型エラー** - ビルド後すぐに修正
3. **テスト失敗** - 型エラー後に修正
4. **セキュリティ問題** - PR前に必ず修正
5. **Lint警告** - 可能な限り修正
6. **カバレッジ不足** - 時間があれば改善

## フックとの統合

このスキルはPostToolUseフックを補完しますが、より深い検証を提供。
フックは問題を即座にキャッチ、このスキルは包括的なレビューを提供。
