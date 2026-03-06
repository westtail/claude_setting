---
name: security-review
description: 認証の追加、ユーザー入力の処理、シークレットの取り扱い、APIエンドポイントの作成、決済・機密機能の実装時に使用。包括的なセキュリティチェックリストとパターンを提供。
---

# セキュリティレビュースキル

このスキルは、すべてのコードがセキュリティベストプラクティスに従い、潜在的な脆弱性を特定することを保証。

## 起動タイミング

- 認証または認可の実装
- ユーザー入力やファイルアップロードの処理
- 新しいAPIエンドポイントの作成
- シークレットや認証情報の取り扱い
- 決済機能の実装
- 機密データの保存や送信
- サードパーティAPIとの統合

## セキュリティチェックリスト

### 1. シークレット管理

#### 絶対にやってはいけないこと

```
# ハードコードされたシークレット
apiKey = "sk-proj-xxxxx"
dbPassword = "password123"
```

#### 常にやるべきこと

```
# 環境変数から取得
apiKey = getEnv("API_KEY")
dbUrl = getEnv("DATABASE_URL")

# シークレットの存在を確認
if not apiKey:
    throw Error("API_KEYが設定されていません")
```

#### 確認ステップ

- [ ] ハードコードされたAPIキー、トークン、パスワードがない
- [ ] すべてのシークレットが環境変数に
- [ ] `.env`ファイルが.gitignoreに
- [ ] git履歴にシークレットがない
- [ ] 本番シークレットがホスティングプラットフォームに安全に保存

### 2. 入力バリデーション

#### 常にユーザー入力を検証

```
# バリデーションスキーマを定義
CreateUserSchema:
    email: string, format=email
    name: string, minLength=1, maxLength=100
    age: integer, min=0, max=150

# 処理前に検証
function createUser(input):
    try:
        validated = validate(input, CreateUserSchema)
        return db.users.create(validated)
    catch ValidationError as error:
        return { success: false, errors: error.details }
```

#### ファイルアップロードのバリデーション

```
function validateFileUpload(file):
    # サイズチェック（最大5MB）
    maxSize = 5 * 1024 * 1024
    if file.size > maxSize:
        throw Error("ファイルが大きすぎます（最大5MB）")

    # MIMEタイプチェック
    allowedTypes = ["image/jpeg", "image/png", "image/gif"]
    if file.type not in allowedTypes:
        throw Error("無効なファイルタイプ")

    # 拡張子チェック（MIMEタイプと一致確認）
    allowedExtensions = [".jpg", ".jpeg", ".png", ".gif"]
    extension = getExtension(file.name).toLowerCase()
    if extension not in allowedExtensions:
        throw Error("無効なファイル拡張子")

    # マジックバイト確認（オプション：より厳密）
    if not verifyMagicBytes(file):
        throw Error("ファイル内容が拡張子と一致しません")

    return true
```

#### 確認ステップ

- [ ] すべてのユーザー入力がスキーマで検証
- [ ] ファイルアップロードが制限（サイズ、タイプ、拡張子）
- [ ] ユーザー入力がクエリで直接使用されない
- [ ] ホワイトリスト検証（ブラックリストではなく）
- [ ] エラーメッセージが機密情報を漏らさない

### 3. SQLインジェクション防止

#### 絶対にSQLを連結しない

```
# 危険 - SQLインジェクション脆弱性
query = "SELECT * FROM users WHERE email = '" + userEmail + "'"
db.execute(query)
```

#### 常にパラメータ化クエリを使用

```
# 安全 - パラメータ化クエリ
db.query("SELECT * FROM users WHERE email = ?", [userEmail])

# または名前付きパラメータ
db.query("SELECT * FROM users WHERE email = :email", {email: userEmail})

# ORMを使用する場合も安全
db.users.where(email: userEmail).first()
```

#### 確認ステップ

- [ ] すべてのデータベースクエリがパラメータ化クエリを使用
- [ ] SQLに文字列連結がない
- [ ] ORM/クエリビルダーが正しく使用
- [ ] 動的テーブル名・カラム名はホワイトリストで検証

### 4. 認証と認可

#### トークンの安全な保存

```
# 間違い：クライアントサイドストレージ（XSSに脆弱）
localStorage.set("token", token)
sessionStorage.set("token", token)

# 正解：httpOnlyクッキー
setResponseCookie(
    name: "session",
    value: token,
    httpOnly: true,      # JavaScriptからアクセス不可
    secure: true,        # HTTPS必須
    sameSite: "Strict",  # CSRF保護
    maxAge: 3600         # 有効期限
)
```

#### 認可チェック

```
function deleteUser(userId, requesterId):
    # 常に最初に認可を確認
    requester = db.users.find(requesterId)

    # ロールベースのアクセス制御
    if requester.role != "admin":
        return errorResponse(403, "権限がありません")

    # オブジェクトレベルのアクセス制御
    if requester.role == "user" AND userId != requesterId:
        return errorResponse(403, "他のユーザーは削除できません")

    # 削除を実行
    db.users.delete(userId)
```

#### Row Level Security（データベースレベル）

```sql
-- すべてのテーブルでRLSを有効化
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分のデータのみ閲覧可能
CREATE POLICY "Users view own data"
  ON users FOR SELECT
  USING (current_user_id() = id);

-- ユーザーは自分のデータのみ更新可能
CREATE POLICY "Users update own data"
  ON users FOR UPDATE
  USING (current_user_id() = id);
```

#### 確認ステップ

- [ ] トークンがhttpOnlyクッキーに保存（localStorageではない）
- [ ] 機密操作前に認可チェック
- [ ] データベースでRow Level Securityが有効
- [ ] ロールベースのアクセス制御が実装
- [ ] セッション管理がセキュア
- [ ] パスワードは安全にハッシュ化（bcrypt、argon2）

### 5. XSS（クロスサイトスクリプティング）防止

#### HTMLのサニタイズ

```
# 常にユーザー提供のHTMLをサニタイズ
function renderUserContent(html):
    clean = sanitizeHtml(html,
        allowedTags: ["b", "i", "em", "strong", "p", "a"],
        allowedAttributes: {
            "a": ["href"]  # hrefのみ許可
        },
        allowedSchemes: ["http", "https"]  # javascript:を除外
    )
    return renderHtml(clean)

# または完全にエスケープ
function displayUserText(text):
    return escapeHtml(text)  # <>&"' をエンティティに変換
```

#### Content Security Policy

```
# HTTPヘッダーで設定
Content-Security-Policy:
    default-src 'self';
    script-src 'self';
    style-src 'self' 'unsafe-inline';
    img-src 'self' data: https:;
    font-src 'self';
    connect-src 'self' https://api.example.com;
    frame-ancestors 'none';
```

#### 確認ステップ

- [ ] ユーザー提供のHTMLがサニタイズ
- [ ] CSPヘッダーが設定
- [ ] 未検証の動的コンテンツレンダリングがない
- [ ] テンプレートエンジンの自動エスケープが有効

### 6. CSRF（クロスサイトリクエストフォージェリ）保護

#### CSRFトークン

```
# フォーム送信時
function handlePostRequest(request):
    token = request.headers.get("X-CSRF-Token")
    # または request.body.csrf_token

    if not csrfTokenStore.verify(token, request.session):
        return errorResponse(403, "無効なCSRFトークン")

    # リクエストを処理
```

#### SameSiteクッキー

```
# すべてのセッションクッキーに設定
setResponseCookie(
    name: "session",
    value: sessionId,
    httpOnly: true,
    secure: true,
    sameSite: "Strict"  # または "Lax"
)
```

#### 確認ステップ

- [ ] 状態変更操作にCSRFトークン
- [ ] すべてのクッキーにSameSite属性
- [ ] ダブルサブミットクッキーパターンが実装
- [ ] Referer/Originヘッダーの検証（補助的）

### 7. レート制限

#### APIレート制限

```
# レート制限ミドルウェア
rateLimiter = createRateLimiter(
    windowMs: 15 * 60 * 1000,  # 15分
    maxRequests: 100,          # ウィンドウあたり100リクエスト
    keyGenerator: request => request.ip,
    message: "リクエストが多すぎます"
)

# ルートに適用
app.use("/api/*", rateLimiter)
```

#### 高コスト操作

```
# 検索に対するより厳しいレート制限
searchLimiter = createRateLimiter(
    windowMs: 60 * 1000,  # 1分
    maxRequests: 10,      # 1分あたり10リクエスト
    message: "検索リクエストが多すぎます"
)

# ログイン試行制限
loginLimiter = createRateLimiter(
    windowMs: 15 * 60 * 1000,  # 15分
    maxRequests: 5,            # 15分で5回
    keyGenerator: request => request.body.email,
    message: "ログイン試行回数を超えました"
)
```

#### 確認ステップ

- [ ] すべてのAPIエンドポイントにレート制限
- [ ] 高コスト操作により厳しい制限
- [ ] IPベースのレート制限
- [ ] ユーザーベースのレート制限（認証済み）
- [ ] ログイン試行のレート制限

### 8. 機密データの露出

#### ログ出力

```
# 間違い：機密データをログ出力
log("User login:", { email, password })
log("Payment:", { cardNumber, cvv })

# 正解：機密データを秘匿
log("User login:", { email, userId })
log("Payment:", { last4: card.last4, userId })

# パスワードやトークンをマスク
log("Request:", maskSensitiveFields(request))
```

#### エラーメッセージ

```
# 間違い：内部詳細を露出
catch error:
    return jsonResponse(
        { error: error.message, stack: error.stack },
        status: 500
    )

# 正解：汎用エラーメッセージ
catch error:
    logError("内部エラー:", error)  # サーバーログのみ
    return jsonResponse(
        { error: "エラーが発生しました。再度お試しください。" },
        status: 500
    )
```

#### 確認ステップ

- [ ] ログにパスワード、トークン、シークレットがない
- [ ] ユーザー向けエラーメッセージが汎用
- [ ] 詳細エラーはサーバーログのみ
- [ ] スタックトレースがユーザーに露出しない
- [ ] APIレスポンスに不要な内部情報がない

### 9. 暗号化とデータ保護

#### パスワードハッシュ

```
# 正解：強力なハッシュアルゴリズム
hashedPassword = bcrypt.hash(password, cost: 12)
# または
hashedPassword = argon2.hash(password)

# 間違い：弱いハッシュ
hashedPassword = md5(password)      # 絶対にダメ
hashedPassword = sha256(password)   # ソルトなしはダメ
```

#### 機密データの暗号化

```
# 保存時の暗号化（at rest）
encryptedData = encrypt(sensitiveData, encryptionKey)
db.save(encryptedData)

# 転送時の暗号化（in transit）
# - HTTPS/TLSを強制
# - 古いTLSバージョンを無効化（TLS 1.2以上）
```

#### 確認ステップ

- [ ] パスワードはbcrypt/argon2でハッシュ
- [ ] 機密データは暗号化して保存
- [ ] TLS 1.2以上を使用
- [ ] 暗号化キーは安全に管理

### 10. 依存関係のセキュリティ

#### 定期的な更新

```bash
# 言語/パッケージマネージャに応じて実行

# 脆弱性をチェック
<package-manager> audit

# 依存関係を更新
<package-manager> update

# 古いパッケージをチェック
<package-manager> outdated
```

#### ロックファイル

```bash
# 常にロックファイルをコミット
git add <lockfile>  # package-lock.json, Gemfile.lock, etc.

# CI/CDで再現可能なビルドのために使用
<package-manager> install --frozen-lockfile
```

#### 確認ステップ

- [ ] 依存関係が最新
- [ ] 既知の脆弱性がない
- [ ] ロックファイルがコミット済み
- [ ] 自動セキュリティ更新が有効（Dependabot等）
- [ ] 定期的なセキュリティ監査

## セキュリティテスト

### 自動セキュリティテスト

```
# 認証をテスト
test "認証なしでは保護されたエンドポイントにアクセスできない":
    response = httpGet("/api/protected")
    assertEqual(response.status, 401)

# 認可をテスト
test "一般ユーザーは管理者APIにアクセスできない":
    response = httpGet("/api/admin",
        headers: { Authorization: userToken })
    assertEqual(response.status, 403)

# 入力バリデーションをテスト
test "無効な入力を拒否する":
    response = httpPost("/api/users",
        body: { email: "not-an-email" })
    assertEqual(response.status, 400)

# SQLインジェクションをテスト
test "SQLインジェクションを防ぐ":
    response = httpGet("/api/users?id=1' OR '1'='1")
    assertNotEqual(response.data.length, allUsersCount)

# レート制限をテスト
test "レート制限を強制する":
    for i in 1..101:
        response = httpGet("/api/endpoint")
    assertEqual(response.status, 429)
```

## デプロイ前セキュリティチェックリスト

本番デプロイ前に必ず確認：

### 必須項目

- [ ] **シークレット**：ハードコードされたシークレットがない、すべて環境変数
- [ ] **入力バリデーション**：すべてのユーザー入力が検証
- [ ] **SQLインジェクション**：すべてのクエリがパラメータ化
- [ ] **XSS**：ユーザーコンテンツがサニタイズ
- [ ] **CSRF**：保護が有効
- [ ] **認証**：適切なトークン処理、httpOnlyクッキー
- [ ] **認可**：ロールチェックが実装
- [ ] **パスワード**：bcrypt/argon2でハッシュ

### 推奨項目

- [ ] **レート制限**：すべてのエンドポイントで有効
- [ ] **HTTPS**：本番で強制
- [ ] **セキュリティヘッダー**：CSP、X-Frame-Options、X-Content-Type-Options
- [ ] **エラー処理**：エラーに機密データがない
- [ ] **ログ出力**：機密データがログに記録されない
- [ ] **依存関係**：最新、脆弱性なし
- [ ] **CORS**：適切に設定
- [ ] **ファイルアップロード**：検証済み（サイズ、タイプ、マジックバイト）

### データベース

- [ ] **Row Level Security**：有効
- [ ] **接続暗号化**：SSL/TLS使用
- [ ] **最小権限**：アプリケーションユーザーに必要最小限の権限

## OWASP Top 10 対応表

| 脆弱性                                  | 対策                 | このドキュメントのセクション |
| --------------------------------------- | -------------------- | ---------------------------- |
| A01:2021 - アクセス制御の不備           | 認可チェック、RLS    | 4. 認証と認可                |
| A02:2021 - 暗号化の失敗                 | 強力なハッシュ、TLS  | 9. 暗号化とデータ保護        |
| A03:2021 - インジェクション             | パラメータ化クエリ   | 3. SQLインジェクション防止   |
| A04:2021 - 安全でない設計               | 入力検証、レート制限 | 2, 7                         |
| A05:2021 - セキュリティ設定ミス         | セキュリティヘッダー | 5, 6                         |
| A06:2021 - 脆弱な依存関係               | 定期更新、監査       | 10. 依存関係のセキュリティ   |
| A07:2021 - 認証の失敗                   | httpOnlyクッキー     | 4. 認証と認可                |
| A08:2021 - ソフトウェアとデータの整合性 | ロックファイル       | 10. 依存関係のセキュリティ   |
| A09:2021 - ログと監視の失敗             | 安全なログ出力       | 8. 機密データの露出          |
| A10:2021 - SSRF                         | 入力検証             | 2. 入力バリデーション        |

## リソース

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)
- [CWE/SANS Top 25](https://cwe.mitre.org/top25/)
- [Web Security Academy](https://portswigger.net/web-security)

---

**覚えておく**：セキュリティはオプションではありません。1つの脆弱性がプラットフォーム全体を危険にさらす可能性があります。迷ったら、安全側に倒す。
