---
name: sql-patterns
description: クエリ最適化、スキーマ設計、インデックス作成、セキュリティのためのPostgreSQLおよびMySQLデータベースパターン。各DBMSのベストプラクティスに基づく。
---

# SQLデータベースパターン

PostgreSQLとMySQLのベストプラクティスのクイックリファレンス。

## アクティベーションタイミング

- SQLクエリやマイグレーションを書くとき
- データベーススキーマを設計するとき
- 遅いクエリのトラブルシューティング時
- セキュリティの実装時
- コネクションプーリングの設定時

## セキュリティ

### SQLインジェクション防止

**⚠️ 絶対にやってはいけないこと：**

```sql
-- 危険：文字列連結によるクエリ構築
SELECT * FROM users WHERE email = '" + userEmail + "';
SELECT * FROM users WHERE id = " + userId;
EXECUTE 'SELECT * FROM ' || tableName;  -- 動的テーブル名も危険
```

**✅ 常にパラメータ化クエリを使用：**

**PostgreSQL:**

```sql
-- プリペアドステートメント（$1, $2... 形式）
PREPARE find_user (text) AS
  SELECT * FROM users WHERE email = $1;
EXECUTE find_user('alice@example.com');

-- または直接パラメータ化
SELECT * FROM users WHERE email = $1;  -- アプリケーション側でバインド
```

**MySQL:**

```sql
-- プリペアドステートメント
PREPARE stmt FROM 'SELECT * FROM users WHERE email = ?';
SET @email = 'alice@example.com';
EXECUTE stmt USING @email;
DEALLOCATE PREPARE stmt;

-- 名前付きパラメータ（アプリケーション側）
SELECT * FROM users WHERE email = :email;
```

**動的なテーブル名・カラム名（必要な場合のみ）：**

```sql
-- 間違い：動的に構築
EXECUTE 'SELECT * FROM ' || user_input;  -- SQLインジェクション！

-- 正解：ホワイトリストで検証（PostgreSQL例）
CREATE FUNCTION safe_query(table_name text) RETURNS SETOF RECORD AS $$
BEGIN
  -- 許可されたテーブル名のみ
  IF table_name NOT IN ('users', 'orders', 'products') THEN
    RAISE EXCEPTION 'Invalid table name: %', table_name;
  END IF;
  RETURN QUERY EXECUTE format('SELECT * FROM %I', table_name);
END;
$$ LANGUAGE plpgsql;
```

### ユーザー権限とアクセス制御

**⚠️ 接続元の制限（重要）：**

```sql
-- 危険：任意のホストからの接続を許可
CREATE USER 'app_user'@'%' IDENTIFIED BY 'password';
-- '%' = すべてのIPアドレスからの接続を許可 → セキュリティリスク！

-- 推奨：特定のホスト/ネットワークのみ許可
CREATE USER 'app_user'@'10.0.0.%' IDENTIFIED BY 'password';  -- 内部ネットワーク
CREATE USER 'app_user'@'app-server.example.com' IDENTIFIED BY 'password';
CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'password';  -- ローカルのみ
```

**PostgreSQLのpg_hba.conf：**

```
# TYPE  DATABASE  USER       ADDRESS         METHOD
host    mydb      app_user   10.0.0.0/24     scram-sha-256
host    mydb      app_user   127.0.0.1/32    scram-sha-256
# 拒否（それ以外）
host    all       all        0.0.0.0/0       reject
```

**最小権限の原則：**

```sql
-- 悪い例：すべての権限を付与
GRANT ALL PRIVILEGES ON *.* TO 'app_user'@'%';

-- 良い例：必要最小限の権限のみ
-- アプリケーション用（CRUD操作のみ、DDLなし）
GRANT SELECT, INSERT, UPDATE, DELETE ON mydb.* TO 'app_user'@'10.0.0.%';

-- 読み取り専用ユーザー（レポート・分析用）
GRANT SELECT ON mydb.* TO 'report_user'@'10.0.0.%';

-- マイグレーション用（スキーマ変更可能、本番では別管理）
GRANT ALL PRIVILEGES ON mydb.* TO 'migration_user'@'localhost';
```

### トランザクション分離レベル

並行処理の問題を防ぐために適切な分離レベルを選択：

| 分離レベル       | ダーティリード | ノンリピータブルリード | ファントムリード | 用途                           |
| ---------------- | :------------: | :--------------------: | :--------------: | ------------------------------ |
| READ UNCOMMITTED |       ○        |           ○            |        ○         | 統計など精度不要な場合のみ     |
| READ COMMITTED   |       ×        |           ○            |        ○         | PostgreSQLデフォルト、一般用途 |
| REPEATABLE READ  |       ×        |           ×            |       ○(※)       | MySQLデフォルト、一貫性が必要  |
| SERIALIZABLE     |       ×        |           ×            |        ×         | 厳密な整合性が必要な場合       |

※ MySQLのREPEATABLE READはギャップロックでファントムリードを防止

**PostgreSQL:**

```sql
-- トランザクション単位で設定
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- 処理
COMMIT;

-- セッション単位で設定
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

**MySQL:**

```sql
-- トランザクション単位で設定
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION;
-- 処理
COMMIT;

-- セッション単位で設定
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
```

**推奨設定：**

| ユースケース      | 推奨分離レベル             | 理由                         |
| ----------------- | -------------------------- | ---------------------------- |
| 一般的なWebアプリ | READ COMMITTED             | 十分な一貫性、デッドロック少 |
| 金融・決済処理    | SERIALIZABLE               | 厳密な整合性が必須           |
| 在庫管理・予約    | REPEATABLE READ + 行ロック | 二重予約防止                 |
| レポート・分析    | READ COMMITTED             | 長時間クエリでロック回避     |

### 接続のセキュリティ

```sql
-- PostgreSQL: SSL接続を強制
ALTER SYSTEM SET ssl = on;
-- pg_hba.conf で hostssl のみ許可

-- MySQL: SSL接続を強制
ALTER USER 'app_user'@'%' REQUIRE SSL;
-- または
ALTER USER 'app_user'@'%' REQUIRE X509;  -- クライアント証明書必須
```

---

## インデックスチートシート

### PostgreSQL

| クエリパターン          | インデックスタイプ   | 例                                       |
| ----------------------- | -------------------- | ---------------------------------------- |
| `WHERE col = value`     | B-tree（デフォルト） | `CREATE INDEX idx ON t (col)`            |
| `WHERE col > value`     | B-tree               | `CREATE INDEX idx ON t (col)`            |
| `WHERE a = x AND b > y` | 複合                 | `CREATE INDEX idx ON t (a, b)`           |
| `WHERE jsonb @> '{}'`   | GIN                  | `CREATE INDEX idx ON t USING gin (col)`  |
| `WHERE tsv @@ query`    | GIN                  | `CREATE INDEX idx ON t USING gin (col)`  |
| 時系列範囲              | BRIN                 | `CREATE INDEX idx ON t USING brin (col)` |

### MySQL

| クエリパターン            | インデックスタイプ   | 例                                     |
| ------------------------- | -------------------- | -------------------------------------- |
| `WHERE col = value`       | B-tree（デフォルト） | `CREATE INDEX idx ON t (col)`          |
| `WHERE col > value`       | B-tree               | `CREATE INDEX idx ON t (col)`          |
| `WHERE a = x AND b > y`   | 複合                 | `CREATE INDEX idx ON t (a, b)`         |
| `MATCH(col) AGAINST(...)` | FULLTEXT             | `CREATE FULLTEXT INDEX idx ON t (col)` |
| 空間データ                | SPATIAL              | `CREATE SPATIAL INDEX idx ON t (col)`  |
| 降順ソート (8.0+)         | 降順                 | `CREATE INDEX idx ON t (col DESC)`     |

## データ型クイックリファレンス

### PostgreSQL

| ユースケース   | 正しい型               | 避けるべき型        |
| -------------- | ---------------------- | ------------------- |
| ID             | `bigint` / `bigserial` | `int`、ランダムUUID |
| 文字列         | `text`                 | `varchar(255)`      |
| タイムスタンプ | `timestamptz`          | `timestamp`         |
| 金額           | `numeric(10,2)`        | `float`             |
| フラグ         | `boolean`              | `varchar`, `int`    |
| JSON           | `jsonb`                | `json`, `text`      |
| UUID           | `uuid`                 | `varchar(36)`       |

### MySQL

| ユースケース   | 正しい型                         | 避けるべき型                   |
| -------------- | -------------------------------- | ------------------------------ |
| ID             | `BIGINT UNSIGNED AUTO_INCREMENT` | `INT`、ランダムUUID            |
| 文字列（短い） | `VARCHAR(n)`                     | `TEXT`（インデックス制限あり） |
| 文字列（長い） | `TEXT` / `MEDIUMTEXT`            | `VARCHAR(65535)`               |
| タイムスタンプ | `DATETIME(6)` / `TIMESTAMP`      | 精度なし `DATETIME`            |
| 金額           | `DECIMAL(10,2)`                  | `FLOAT`, `DOUBLE`              |
| フラグ         | `TINYINT(1)` / `BOOLEAN`         | `VARCHAR`, `ENUM`              |
| JSON           | `JSON` (5.7+)                    | `TEXT`                         |
| UUID           | `BINARY(16)` / `CHAR(36)`        | `VARCHAR(36)`                  |

## 一般的なパターン

### 複合インデックスの順序

```sql
-- 等価列を先に、その後に範囲列（両方共通）
CREATE INDEX idx ON orders (status, created_at);
-- 対象クエリ: WHERE status = 'pending' AND created_at > '2024-01-01'
```

### カバリングインデックス

**PostgreSQL:**

```sql
CREATE INDEX idx ON users (email) INCLUDE (name, created_at);
-- SELECT email, name, created_at でテーブル参照を回避
```

**MySQL (8.0+):**

```sql
-- MySQLはINCLUDEをサポートしないため、複合インデックスで代用
CREATE INDEX idx ON users (email, name, created_at);
-- InnoDB PKはカバリングインデックスとして機能
```

### 部分インデックス / 条件付きインデックス

**PostgreSQL:**

```sql
CREATE INDEX idx ON users (email) WHERE deleted_at IS NULL;
-- より小さいインデックス、アクティブユーザーのみ含む
```

**MySQL:**

```sql
-- MySQLは部分インデックスをサポートしない
-- 代替案1: 生成列を使用
ALTER TABLE users ADD COLUMN is_active TINYINT(1)
  GENERATED ALWAYS AS (CASE WHEN deleted_at IS NULL THEN 1 ELSE NULL END) STORED;
CREATE INDEX idx ON users (email, is_active);

-- 代替案2: アクティブユーザー専用テーブル/ビュー
```

### UPSERT

**PostgreSQL:**

```sql
INSERT INTO settings (user_id, key, value)
VALUES (123, 'theme', 'dark')
ON CONFLICT (user_id, key)
DO UPDATE SET value = EXCLUDED.value;
```

**MySQL:**

```sql
INSERT INTO settings (user_id, `key`, value)
VALUES (123, 'theme', 'dark')
ON DUPLICATE KEY UPDATE value = VALUES(value);

-- MySQL 8.0.19+ では別名も使用可能
INSERT INTO settings (user_id, `key`, value)
VALUES (123, 'theme', 'dark') AS new
ON DUPLICATE KEY UPDATE value = new.value;
```

### カーソルページネーション

```sql
-- 両方共通: O(1) 対 OFFSETは O(n)
SELECT * FROM products WHERE id > ? ORDER BY id LIMIT 20;
```

### キュー処理

**PostgreSQL:**

```sql
UPDATE jobs SET status = 'processing'
WHERE id = (
  SELECT id FROM jobs WHERE status = 'pending'
  ORDER BY created_at LIMIT 1
  FOR UPDATE SKIP LOCKED
) RETURNING *;
```

**MySQL (8.0+):**

```sql
-- MySQLはUPDATE ... RETURNINGをサポートしないため、2ステップで実行
START TRANSACTION;

SELECT id INTO @job_id FROM jobs
WHERE status = 'pending'
ORDER BY created_at LIMIT 1
FOR UPDATE SKIP LOCKED;

UPDATE jobs SET status = 'processing' WHERE id = @job_id;

SELECT * FROM jobs WHERE id = @job_id;

COMMIT;
```

### RLSポリシー（PostgreSQLのみ）

```sql
-- PostgreSQL固有の機能
CREATE POLICY policy ON orders
  USING ((SELECT auth.uid()) = user_id);  -- SELECTでラップ！
```

**MySQL代替案:**

```sql
-- MySQLはRLSをサポートしない
-- 代替案1: ビューを使用
CREATE VIEW user_orders AS
SELECT * FROM orders WHERE user_id = @current_user_id;

-- 代替案2: アプリケーション層で制御
-- 代替案3: ストアドプロシージャでアクセス制限
```

## 全文検索

**PostgreSQL:**

```sql
-- tsvector列を追加
ALTER TABLE articles ADD COLUMN tsv tsvector
  GENERATED ALWAYS AS (to_tsvector('japanese', title || ' ' || body)) STORED;
CREATE INDEX idx_tsv ON articles USING gin (tsv);

-- 検索
SELECT * FROM articles WHERE tsv @@ to_tsquery('japanese', 'キーワード');
```

**MySQL:**

```sql
-- FULLTEXTインデックスを作成
CREATE FULLTEXT INDEX idx_ft ON articles (title, body)
  WITH PARSER ngram;  -- 日本語対応

-- 検索
SELECT * FROM articles
WHERE MATCH(title, body) AGAINST('キーワード' IN NATURAL LANGUAGE MODE);

-- ブール検索
SELECT * FROM articles
WHERE MATCH(title, body) AGAINST('+必須 -除外' IN BOOLEAN MODE);
```

## JSON操作

**PostgreSQL:**

```sql
-- JSONBフィールドでクエリ
SELECT * FROM users WHERE preferences @> '{"theme": "dark"}';
SELECT * FROM users WHERE preferences->>'theme' = 'dark';

-- JSONBフィールドを更新
UPDATE users SET preferences = preferences || '{"theme": "light"}';
UPDATE users SET preferences = jsonb_set(preferences, '{theme}', '"light"');

-- GINインデックス
CREATE INDEX idx ON users USING gin (preferences);
CREATE INDEX idx ON users USING gin (preferences jsonb_path_ops);
```

**MySQL:**

```sql
-- JSONフィールドでクエリ
SELECT * FROM users WHERE JSON_EXTRACT(preferences, '$.theme') = 'dark';
SELECT * FROM users WHERE preferences->>'$.theme' = 'dark';  -- 5.7+

-- JSONフィールドを更新
UPDATE users SET preferences = JSON_SET(preferences, '$.theme', 'light');

-- 生成列とインデックス（仮想列）
ALTER TABLE users ADD COLUMN theme VARCHAR(50)
  GENERATED ALWAYS AS (preferences->>'$.theme') VIRTUAL;
CREATE INDEX idx ON users (theme);
```

## アンチパターン検出

### PostgreSQL

```sql
-- インデックスなしの外部キーを検出
SELECT conrelid::regclass, a.attname
FROM pg_constraint c
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
WHERE c.contype = 'f'
  AND NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indrelid = c.conrelid AND a.attnum = ANY(i.indkey)
  );

-- 遅いクエリを検出
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
WHERE mean_exec_time > 100
ORDER BY mean_exec_time DESC;

-- テーブルの膨張を確認
SELECT relname, n_dead_tup, last_vacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
```

### MySQL

```sql
-- インデックスなしの外部キーを検出
SELECT
  TABLE_NAME,
  COLUMN_NAME,
  CONSTRAINT_NAME,
  REFERENCED_TABLE_NAME,
  REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE REFERENCED_TABLE_NAME IS NOT NULL
  AND TABLE_SCHEMA = DATABASE()
  AND NOT EXISTS (
    SELECT 1 FROM information_schema.STATISTICS s
    WHERE s.TABLE_SCHEMA = KEY_COLUMN_USAGE.TABLE_SCHEMA
      AND s.TABLE_NAME = KEY_COLUMN_USAGE.TABLE_NAME
      AND s.COLUMN_NAME = KEY_COLUMN_USAGE.COLUMN_NAME
  );

-- 遅いクエリを検出（Performance Schema）
SELECT
  DIGEST_TEXT,
  COUNT_STAR AS calls,
  AVG_TIMER_WAIT/1000000000 AS avg_ms
FROM performance_schema.events_statements_summary_by_digest
WHERE AVG_TIMER_WAIT > 100000000  -- 100ms以上
ORDER BY AVG_TIMER_WAIT DESC
LIMIT 20;

-- テーブルの断片化を確認
SELECT
  TABLE_NAME,
  DATA_LENGTH,
  DATA_FREE,
  ROUND(DATA_FREE / DATA_LENGTH * 100, 2) AS fragmentation_pct
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND DATA_FREE > 0
ORDER BY DATA_FREE DESC;
```

## 設定テンプレート

### PostgreSQL

```sql
-- 接続制限（RAMに応じて調整）
ALTER SYSTEM SET max_connections = 100;
ALTER SYSTEM SET work_mem = '8MB';

-- タイムアウト
ALTER SYSTEM SET idle_in_transaction_session_timeout = '30s';
ALTER SYSTEM SET statement_timeout = '30s';

-- モニタリング
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- セキュリティデフォルト
REVOKE ALL ON SCHEMA public FROM public;

SELECT pg_reload_conf();
```

### MySQL

```ini
# my.cnf / my.ini

[mysqld]
# 接続制限
max_connections = 100
wait_timeout = 28800
interactive_timeout = 28800

# メモリ（RAMに応じて調整）
innodb_buffer_pool_size = 1G
sort_buffer_size = 2M
join_buffer_size = 2M

# クエリログ
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1

# Performance Schema
performance_schema = ON

# 文字セット
character_set_server = utf8mb4
collation_server = utf8mb4_unicode_ci

# タイムゾーン
default_time_zone = '+00:00'
```

```sql
-- セキュリティ設定
-- ⚠️ 注意：'%'は全ホスト許可。本番では特定ホストに制限すべき
-- 例: 'app_user'@'10.0.0.%' や 'app_user'@'app-server.local'

-- 不要な権限を削除
REVOKE ALL PRIVILEGES ON *.* FROM 'app_user'@'10.0.0.%';
-- 必要最小限の権限のみ付与
GRANT SELECT, INSERT, UPDATE, DELETE ON mydb.* TO 'app_user'@'10.0.0.%';

-- SSL接続を要求（推奨）
ALTER USER 'app_user'@'10.0.0.%' REQUIRE SSL;

-- タイムアウト設定
SET GLOBAL wait_timeout = 300;
SET GLOBAL max_execution_time = 30000;  -- 30秒（8.0+）
```

## ロック戦略

### PostgreSQL

```sql
-- 行レベルロック
SELECT * FROM orders WHERE id = 1 FOR UPDATE;
SELECT * FROM orders WHERE id = 1 FOR UPDATE NOWAIT;
SELECT * FROM orders WHERE id = 1 FOR UPDATE SKIP LOCKED;

-- アドバイザリロック
SELECT pg_advisory_lock(12345);
SELECT pg_advisory_unlock(12345);

-- トランザクション終了時に自動解放
SELECT pg_advisory_xact_lock(12345);
```

### MySQL

```sql
-- 行レベルロック
SELECT * FROM orders WHERE id = 1 FOR UPDATE;
SELECT * FROM orders WHERE id = 1 FOR UPDATE NOWAIT;  -- 8.0+
SELECT * FROM orders WHERE id = 1 FOR UPDATE SKIP LOCKED;  -- 8.0+

-- ネームドロック
SELECT GET_LOCK('my_lock', 10);  -- 10秒タイムアウト
SELECT RELEASE_LOCK('my_lock');
SELECT IS_FREE_LOCK('my_lock');
```

## パーティショニング

### PostgreSQL

```sql
-- 範囲パーティション
CREATE TABLE orders (
  id BIGSERIAL,
  created_at TIMESTAMPTZ NOT NULL,
  amount NUMERIC(10,2)
) PARTITION BY RANGE (created_at);

CREATE TABLE orders_2024_01 PARTITION OF orders
  FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE orders_2024_02 PARTITION OF orders
  FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
```

### MySQL

```sql
-- 範囲パーティション
CREATE TABLE orders (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  created_at DATETIME NOT NULL,
  amount DECIMAL(10,2),
  PRIMARY KEY (id, created_at)  -- パーティションキーをPKに含める必要あり
) PARTITION BY RANGE (YEAR(created_at) * 100 + MONTH(created_at)) (
  PARTITION p202401 VALUES LESS THAN (202402),
  PARTITION p202402 VALUES LESS THAN (202403),
  PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- パーティション追加
ALTER TABLE orders ADD PARTITION (PARTITION p202403 VALUES LESS THAN (202404));
```

## 接続プーリング

### PostgreSQL

```
# PgBouncer設定例 (pgbouncer.ini)
[databases]
mydb = host=localhost dbname=mydb

[pgbouncer]
listen_port = 6432
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
```

### MySQL

```
# ProxySQL設定例
mysql_servers:
  - address: "127.0.0.1"
    port: 3306
    max_connections: 100

mysql_users:
  - username: "app"
    # ⚠️ パスワードは環境変数または外部シークレット管理を使用
    # password: "${MYSQL_APP_PASSWORD}"  # 実際の設定では環境変数を参照
    default_hostgroup: 0
```

## 関連

- エージェント：`database-reviewer` - 完全なデータベースレビューワークフロー

---

_[Supabase Agent Skills](https://github.com/supabase/agent-skills)（MITライセンス）に基づく（PostgreSQL部分）_
