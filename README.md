# Claude Code Settings

Claude Codeのカスタム設定ファイル集です。

## インストール

```bash
# クローン
git clone https://github.com/westtail/claude_setting.git
cd claude_setting
```

### シンボリックリンク（推奨）

リポジトリの変更が即座に反映されます。

```bash
ln -sf $(pwd)/agents ~/.claude/agents
ln -sf $(pwd)/rules ~/.claude/rules
ln -sf $(pwd)/skills ~/.claude/skills
ln -sf $(pwd)/settings.json ~/.claude/settings.json
```

### コピー

シンボリックリンクが動作しない場合や、設定をスナップショットとして固定したい場合。

```bash
cp -r agents ~/.claude/agents
cp -r rules ~/.claude/rules
cp -r skills ~/.claude/skills
cp settings.json ~/.claude/settings.json
```

## 構成

```
.
├── agents/      # カスタムエージェント
├── rules/       # コーディングルール
├── skills/      # カスタムスキル
└── settings.json
```

## エージェント一覧

| エージェント         | 用途             |
| -------------------- | ---------------- |
| planner              | 実装計画         |
| architect            | システム設計     |
| tdd-guide            | テスト駆動開発   |
| code-reviewer        | コードレビュー   |
| security-reviewer    | セキュリティ分析 |
| build-error-resolver | ビルドエラー解決 |
| e2e-runner           | E2Eテスト        |
| refactor-cleaner     | リファクタリング |
| doc-updater          | ドキュメント更新 |

## ライセンス

MIT
