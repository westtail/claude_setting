# Claude Code Settings

Claude Codeのカスタム設定ファイル集です。

## インストール

```bash
# クローン
git clone https://github.com/westtail/claude_setting.git

# シンボリックリンクを作成
ln -sf $(pwd)/claude_setting/agents ~/.claude/agents
ln -sf $(pwd)/claude_setting/rules ~/.claude/rules
ln -sf $(pwd)/claude_setting/skills ~/.claude/skills
ln -sf $(pwd)/claude_setting/settings.json ~/.claude/settings.json
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
