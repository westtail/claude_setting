# セキュリティガイドライン

## 必須セキュリティチェック

すべてのコミット前に：

- [ ] ハードコードされたシークレットがない（APIキー、パスワード、トークン）
- [ ] すべてのユーザー入力が検証されている
- [ ] SQLインジェクション対策（パラメータ化クエリ）
- [ ] XSS対策（サニタイズされたHTML）
- [ ] CSRF保護が有効
- [ ] 認証/認可が検証されている
- [ ] すべてのエンドポイントにレート制限
- [ ] エラーメッセージが機密データを漏洩しない
- [ ] 依存パッケージに既知の脆弱性がない
- [ ] パスワードが適切にハッシュ化されている（bcrypt, argon2等）
- [ ] HTTPS強制（本番環境）

## シークレット管理

# 絶対NG: ハードコードされたシークレット

api_key = "sk-proj-xxxxx"

# 常にこうする: 環境変数から取得

api_key = get_env("OPENAI_API_KEY")

if api_key is empty:
raise Error("OPENAI_API_KEY not configured")

**言語別の環境変数取得方法：**

| 言語                  | 取得方法                           |
| --------------------- | ---------------------------------- |
| Ruby                  | `ENV['OPENAI_API_KEY']`            |
| Python                | `os.environ.get('OPENAI_API_KEY')` |
| JavaScript/TypeScript | `process.env.OPENAI_API_KEY`       |
| Go                    | `os.Getenv("OPENAI_API_KEY")`      |
| Java                  | `System.getenv("OPENAI_API_KEY")`  |
| PHP                   | `getenv('OPENAI_API_KEY')`         |

## セキュリティ対応プロトコル

セキュリティ問題が見つかった場合：

1. 即座に停止
2. **security-reviewer**エージェントを使用
3. 続行前にCRITICAL問題を修正
4. 露出したシークレットをローテーション
5. 同様の問題がないかコードベース全体をレビュー
