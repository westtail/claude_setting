---
name: iterative-retrieval
description: サブエージェントのコンテキスト問題を解決するための、段階的なコンテキスト取得パターン
---

# 反復的取得パターン

サブエージェントが作業を開始するまで必要なコンテキストがわからないという、マルチエージェントワークフローにおける「コンテキスト問題」を解決します。

## 課題

サブエージェントは限られたコンテキストで起動されます。以下のことがわかりません：

- どのファイルに関連コードが含まれているか
- コードベースにどんなパターンが存在するか
- プロジェクトでどんな用語が使われているか

標準的なアプローチは失敗します：

- **全部送る**：コンテキスト制限を超過
- **何も送らない**：エージェントが重要な情報を欠く
- **必要なものを推測**：しばしば間違える

## 解決策：反復的取得

コンテキストを段階的に洗練する4フェーズループ：

```
┌─────────────────────────────────────────────┐
│                                             │
│   ┌──────────┐      ┌──────────┐            │
│   │ DISPATCH │─────▶│ EVALUATE │            │
│   │ (発送)    │      │ (評価)    │            │
│   └──────────┘      └──────────┘            │
│        ▲                  │                 │
│        │                  ▼                 │
│   ┌──────────┐      ┌──────────┐            │
│   │   LOOP   │◀─────│  REFINE  │            │
│   │ (繰返)    │      │ (洗練)    │            │
│   └──────────┘      └──────────┘            │
│                                             │
│        最大3サイクル、その後処理続行            │
└─────────────────────────────────────────────┘
```

### フェーズ1：DISPATCH（発送）

候補ファイルを収集するための初期広範クエリ：

```
# 高レベルの意図から開始
initialQuery:
  patterns: ["src/**/*", "lib/**/*"]
  keywords: ["authentication", "user", "session"]
  excludes: ["*_test.*", "*_spec.*"]

# 取得エージェントに発送
candidates = retrieveFiles(initialQuery)
```

### フェーズ2：EVALUATE（評価）

取得したコンテンツの関連性を評価：

```
function evaluateRelevance(files, task):
  return files.map(file =>
    path: file.path
    relevance: scoreRelevance(file.content, task)
    reason: explainRelevance(file.content, task)
    missingContext: identifyGaps(file.content, task)
  )
```

スコアリング基準：

- **高 (0.8-1.0)**：対象機能を直接実装している
- **中 (0.5-0.7)**：関連パターンや型を含む
- **低 (0.2-0.4)**：間接的に関連
- **なし (0-0.2)**：関連なし、除外

### フェーズ3：REFINE（洗練）

評価に基づいて検索条件を更新：

```
function refineQuery(evaluation, previousQuery):
  return:
    # 高関連性ファイルで発見された新しいパターンを追加
    patterns: previousQuery.patterns + extractPatterns(evaluation)

    # コードベースで見つかった用語を追加
    keywords: previousQuery.keywords + extractKeywords(evaluation)

    # 確認済みの無関係なパスを除外
    excludes: previousQuery.excludes +
      evaluation.filter(e => e.relevance < 0.2).map(e => e.path)

    # 特定のギャップを対象に
    focusAreas: evaluation.flatMap(e => e.missingContext).unique()
```

### フェーズ4：LOOP（繰り返し）

洗練された条件で繰り返し（最大3サイクル）：

```
function iterativeRetrieve(task, maxCycles = 3):
  query = createInitialQuery(task)
  bestContext = []

  for cycle in 0..maxCycles:
    candidates = retrieveFiles(query)
    evaluation = evaluateRelevance(candidates, task)

    # 十分なコンテキストがあるか確認
    highRelevance = evaluation.filter(e => e.relevance >= 0.7)
    if highRelevance.count >= 3 AND NOT hasCriticalGaps(evaluation):
      return highRelevance

    # 洗練して続行
    query = refineQuery(evaluation, query)
    bestContext = mergeContext(bestContext, highRelevance)

  return bestContext
```

## 実践例

### 例1：バグ修正のコンテキスト

```
タスク：「認証トークンの有効期限切れバグを修正」

サイクル1：
  DISPATCH：src/**で「token」「auth」「expiry」を検索
  EVALUATE：auth.* (0.9), tokens.* (0.8), user.* (0.3)を発見
  REFINE：「refresh」「jwt」キーワードを追加；user.*を除外

サイクル2：
  DISPATCH：洗練された条件で検索
  EVALUATE：session_manager.* (0.95), jwt_utils.* (0.85)を発見
  REFINE：十分なコンテキスト（高関連性ファイル2つ）

結果：auth.*, tokens.*, session_manager.*, jwt_utils.*
```

### 例2：機能実装

```
タスク：「APIエンドポイントにレート制限を追加」

サイクル1：
  DISPATCH：routes/**で「rate」「limit」「api」を検索
  EVALUATE：一致なし - コードベースは「throttle」用語を使用
  REFINE：「throttle」「middleware」キーワードを追加

サイクル2：
  DISPATCH：洗練された条件で検索
  EVALUATE：throttle.* (0.9), middleware/index.* (0.7)を発見
  REFINE：ルーターパターンが必要

サイクル3：
  DISPATCH：「router」「handler」パターンを検索
  EVALUATE：router_setup.* (0.8)を発見
  REFINE：十分なコンテキスト

結果：throttle.*, middleware/index.*, router_setup.*
```

### 例3：リファクタリング

```
タスク：「データベース接続をシングルトンからDIに変更」

サイクル1：
  DISPATCH：「database」「connection」「db」を検索
  EVALUATE：db_connection.* (0.9), config.* (0.5), models/* (0.4)を発見
  REFINE：「singleton」「instance」「inject」を追加

サイクル2：
  DISPATCH：洗練された条件で検索
  EVALUATE：service_locator.* (0.85), container.* (0.8)を発見
  REFINE：使用箇所を確認が必要

サイクル3：
  DISPATCH：db_connection.*をimportしているファイルを検索
  EVALUATE：user_repository.* (0.75), order_service.* (0.75)を発見
  REFINE：十分なコンテキスト

結果：db_connection.*, service_locator.*, container.*,
      user_repository.*, order_service.*
```

## エージェントとの統合

エージェントプロンプトで使用：

```markdown
このタスクのコンテキストを取得する際：

1. 広範なキーワード検索から開始
2. 各ファイルの関連性を評価（0-1スケール）
3. まだ不足しているコンテキストを特定
4. 検索条件を洗練して繰り返し（最大3サイクル）
5. 関連性0.7以上のファイルを返す
```

## アルゴリズムの概要

```
iterativeRetrieve(task):
  INPUT:  タスクの説明
  OUTPUT: 高関連性ファイルのリスト

  1. 初期クエリを生成（タスクからキーワード抽出）
  2. REPEAT（最大3回）:
     a. クエリでファイルを検索
     b. 各ファイルの関連性をスコアリング
     c. IF 高関連性ファイル >= 3 AND クリティカルなギャップなし:
          RETURN 高関連性ファイル
     d. 発見した用語・パターンでクエリを洗練
     e. 低関連性ファイルを除外リストに追加
  3. RETURN 収集した最良のコンテキスト
```

## ベストプラクティス

1. **広く始めて徐々に絞る** - 初期クエリを過度に特定しない
2. **コードベースの用語を学ぶ** - 最初のサイクルでしばしば命名規則が明らかになる
3. **不足を追跡** - 明示的なギャップ特定が洗練を促進
4. **「十分」で止める** - 3つの高関連性ファイルは10の平凡なものより良い
5. **自信を持って除外** - 低関連性ファイルが関連性を持つようにはならない

## 失敗パターンと対策

| 失敗パターン     | 症状                     | 対策                           |
| ---------------- | ------------------------ | ------------------------------ |
| クエリが狭すぎる | サイクル1で結果なし      | より一般的なキーワードから開始 |
| 用語の不一致     | 高関連性ファイルがない   | 発見した用語をキーワードに追加 |
| 無限ループ       | 3サイクル後も不十分      | 収集した最良の結果で続行       |
| 過度な取得       | 大量の中程度関連ファイル | 閾値を0.8に上げる              |

## 関連

- `continuous-learning`スキル - 時間とともに改善するパターン
- `~/.claude/agents/`内のエージェント定義
