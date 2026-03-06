---
name: ruby-patterns
description: イディオマティックなRubyパターン、ベストプラクティス、エレガントでメンテナブルなRubyアプリケーション構築のための規約。
---

# Ruby開発パターン

イディオマティックなRubyパターンとベストプラクティス。エレガントでメンテナブルなアプリケーション構築のために。

## アクティベーション条件

- 新しいRubyコードを書くとき
- Rubyコードをレビューするとき
- 既存のRubyコードをリファクタリングするとき
- Gemやモジュールを設計するとき

## 基本原則

### 1. 最小驚きの原則（POLA）

Rubyは開発者の期待に沿った振る舞いを重視する。コードは直感的で読みやすくあるべき。

```ruby
# 良い: 明確で直接的
def find_user(id)
  user = User.find_by(id: id)
  raise UserNotFoundError, "User #{id} not found" unless user
  user
end

# 悪い: 予期しない副作用
def find_user(id)
  @last_searched_id = id  # 意図しない副作用
  User.find_by(id: id).tap { |u| log_access(u) }
end
```

### 2. ダックタイピングを活用する

型ではなくメソッドの存在で判断する。

```ruby
# 良い: ダックタイピング
def process(item)
  item.to_s  # to_sに応答するあらゆるオブジェクト
end

# 悪い: 型チェック
def process(item)
  case item
  when String then item
  when Integer then item.to_s
  when Symbol then item.to_s
  else raise TypeError
  end
end
```

### 3. オブジェクト指向とブロックを活用

Rubyらしいコードはブロックとイテレータを積極的に使う。

```ruby
# 良い: ブロックを活用
users.select { |u| u.active? }.map(&:name)

# 良い: シンボルto_proc
users.map(&:name).join(", ")

# 悪い: 手続き的
result = []
users.each do |u|
  if u.active?
    result << u.name
  end
end
```

## エラーハンドリングパターン

### カスタム例外クラス

```ruby
# ドメイン固有の例外階層を定義
module MyApp
  class Error < StandardError; end

  class ValidationError < Error
    attr_reader :field, :message

    def initialize(field, message)
      @field = field
      @message = message
      super("Validation failed on #{field}: #{message}")
    end
  end

  class NotFoundError < Error; end
  class UnauthorizedError < Error; end
end
```

### begin-rescue-ensure パターン

```ruby
# 良い: 適切なエラーハンドリング
def load_config(path)
  data = File.read(path)
  YAML.safe_load(data, symbolize_names: true)
rescue Errno::ENOENT => e
  raise ConfigError, "Config file not found: #{path}"
rescue Psych::SyntaxError => e
  raise ConfigError, "Invalid YAML in #{path}: #{e.message}"
ensure
  # クリーンアップ処理（必要な場合）
end
```

### 例外を握りつぶさない

```ruby
# 悪い: 例外を握りつぶす
def dangerous_operation
  do_something
rescue
  nil  # 何が起きたか不明
end

# 良い: ログを残すか再raise
def dangerous_operation
  do_something
rescue StandardError => e
  Rails.logger.error("Operation failed: #{e.message}")
  raise
end

# 許容: 意図的に無視する場合はコメント
def best_effort_cleanup
  File.delete(temp_file)
rescue Errno::ENOENT
  # ファイルが既に削除されていても問題ない
end
```

### 例外の種類を限定する

```ruby
# 悪い: すべての例外をキャッチ
begin
  risky_operation
rescue Exception => e  # NoMemoryErrorなども捕捉してしまう
  handle_error(e)
end

# 良い: StandardErrorをキャッチ
begin
  risky_operation
rescue StandardError => e
  handle_error(e)
end

# 最良: 特定の例外のみキャッチ
begin
  risky_operation
rescue NetworkError, TimeoutError => e
  handle_error(e)
end
```

## メタプログラミングパターン

### method_missing は慎重に

```ruby
# 良い: respond_to_missing? も実装
class DynamicFinder
  def method_missing(method_name, *args, &block)
    if method_name.to_s.start_with?("find_by_")
      attribute = method_name.to_s.sub("find_by_", "")
      find_by_attribute(attribute, args.first)
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    method_name.to_s.start_with?("find_by_") || super
  end

  private

  def find_by_attribute(attr, value)
    # 実装
  end
end
```

### define_method で動的メソッド定義

```ruby
# 良い: define_methodで明示的に定義
class User
  STATUSES = %w[active inactive pending].freeze

  STATUSES.each do |status|
    define_method("#{status}?") do
      self.status == status
    end

    define_method("mark_as_#{status}!") do
      update!(status: status)
    end
  end
end
```

### クラスマクロパターン

```ruby
# 良い: ActiveRecordスタイルのクラスマクロ
module Configurable
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def config_accessor(name, default: nil)
      define_method(name) do
        instance_variable_get("@#{name}") || default
      end

      define_method("#{name}=") do |value|
        instance_variable_set("@#{name}", value)
      end
    end
  end
end

class MyService
  include Configurable

  config_accessor :timeout, default: 30
  config_accessor :retries, default: 3
end
```

## 並行処理パターン

### スレッドセーフなコード

```ruby
# 良い: Mutexで保護
class Counter
  def initialize
    @mutex = Mutex.new
    @count = 0
  end

  def increment
    @mutex.synchronize { @count += 1 }
  end

  def value
    @mutex.synchronize { @count }
  end
end

# 良い: Concurrent Rubyを使用
require 'concurrent'

class SafeCounter
  def initialize
    @count = Concurrent::AtomicFixnum.new(0)
  end

  def increment
    @count.increment
  end

  def value
    @count.value
  end
end
```

### 並列処理

```ruby
# Parallel gemで並列処理
require 'parallel'

def process_items(items)
  Parallel.map(items, in_threads: 4) do |item|
    expensive_operation(item)
  end
end

# Concurrent Rubyでの非同期処理
require 'concurrent'

def fetch_all(urls)
  futures = urls.map do |url|
    Concurrent::Future.execute { fetch(url) }
  end

  futures.map(&:value)
end
```

### タイムアウト処理

```ruby
require 'timeout'

def fetch_with_timeout(url, timeout_seconds: 5)
  Timeout.timeout(timeout_seconds) do
    Net::HTTP.get(URI(url))
  end
rescue Timeout::Error
  raise FetchError, "Request to #{url} timed out after #{timeout_seconds}s"
end
```

## モジュール設計

### 名前空間とモジュールの分離

```ruby
# 良い: 明確な名前空間
module MyApp
  module Services
    class UserService
      def initialize(repository:)
        @repository = repository
      end

      def find(id)
        @repository.find(id)
      end
    end
  end

  module Repositories
    class UserRepository
      def find(id)
        User.find(id)
      end
    end
  end
end
```

### Concernパターン（Rails）

```ruby
# app/models/concerns/searchable.rb
module Searchable
  extend ActiveSupport::Concern

  included do
    scope :search, ->(query) { where("name LIKE ?", "%#{query}%") }
  end

  class_methods do
    def searchable_columns
      [:name, :description]
    end
  end

  def matching_highlights(query)
    # インスタンスメソッド
  end
end

# 使用
class Product < ApplicationRecord
  include Searchable
end
```

### Service Objectパターン

```ruby
# app/services/user_registration_service.rb
class UserRegistrationService
  def initialize(user_params, notifier: EmailNotifier.new)
    @user_params = user_params
    @notifier = notifier
  end

  def call
    user = User.new(@user_params)

    ActiveRecord::Base.transaction do
      user.save!
      create_default_settings(user)
      @notifier.welcome(user)
    end

    Result.success(user)
  rescue ActiveRecord::RecordInvalid => e
    Result.failure(e.record.errors)
  end

  private

  def create_default_settings(user)
    UserSettings.create!(user: user, theme: 'light')
  end
end

# 使用
result = UserRegistrationService.new(params).call
if result.success?
  redirect_to result.value
else
  render :new, errors: result.errors
end
```

## プロジェクト構成

### 標準的なGem構成

```text
my_gem/
├── lib/
│   ├── my_gem.rb              # メインエントリーポイント
│   ├── my_gem/
│   │   ├── version.rb         # バージョン定義
│   │   ├── configuration.rb   # 設定クラス
│   │   ├── client.rb          # メインクラス
│   │   └── errors.rb          # カスタム例外
├── spec/
│   ├── spec_helper.rb
│   ├── my_gem_spec.rb
│   └── my_gem/
│       └── client_spec.rb
├── my_gem.gemspec
├── Gemfile
├── Rakefile
└── README.md
```

### Rails アプリケーション構成

```text
app/
├── controllers/
├── models/
├── views/
├── services/          # Service Objects
├── queries/           # Query Objects
├── presenters/        # Presenter/Decorator
├── policies/          # Pundit policies
├── validators/        # カスタムバリデータ
├── jobs/              # Background jobs
└── mailers/
lib/
├── tasks/             # Rakeタスク
└── extensions/        # コア拡張
```

## Ruby イディオム

### 条件式の活用

```ruby
# 良い: 後置if/unless
return if user.nil?
send_notification unless silent_mode?

# 良い: 三項演算子（シンプルな場合）
status = user.active? ? 'active' : 'inactive'

# 良い: ||= でメモ化
def expensive_data
  @expensive_data ||= calculate_expensive_data
end

# 良い: &&= で条件付き代入
user.name &&= user.name.strip
```

### コレクション操作

```ruby
# 良い: Enumerableを活用
# select, reject, map, reduce, find, any?, all?, none?

active_users = users.select(&:active?)
names = users.map(&:name)
total = orders.sum(&:amount)
admin = users.find(&:admin?)

# 良い: チェーン
users
  .select(&:active?)
  .reject(&:banned?)
  .sort_by(&:created_at)
  .take(10)
  .map(&:email)
```

### 安全なナビゲーション演算子

```ruby
# 良い: &. を使用
user&.profile&.avatar_url

# 悪い: 冗長なnil チェック
user && user.profile && user.profile.avatar_url

# 良い: dig でネストしたハッシュ
config.dig(:database, :primary, :host)
```

### freeze でイミュータビリティ

```ruby
# 良い: 定数をfreeze
VALID_STATUSES = %w[pending active completed].freeze
DEFAULT_OPTIONS = { timeout: 30, retries: 3 }.freeze

# 良い: magic comment で文字列リテラルをfreeze
# frozen_string_literal: true

class MyClass
  DEFAULT_NAME = "default"  # 自動的にfreeze
end
```

## パフォーマンスのベストプラクティス

### N+1クエリの回避

```ruby
# 悪い: N+1クエリ
users = User.all
users.each do |user|
  puts user.posts.count  # 各ユーザーでクエリ発行
end

# 良い: includes/preload
users = User.includes(:posts)
users.each do |user|
  puts user.posts.size  # メモリ上のデータを使用
end

# 良い: counter_cache
class Post < ApplicationRecord
  belongs_to :user, counter_cache: true
end
# user.posts_count でカウント取得
```

### 遅延評価

```ruby
# 良い: lazy enumeration
(1..Float::INFINITY)
  .lazy
  .select { |n| n % 3 == 0 }
  .take(10)
  .to_a

# 良い: each_with_object（reduceより効率的な場合）
names_by_id = users.each_with_object({}) do |user, hash|
  hash[user.id] = user.name
end
```

### 文字列操作

```ruby
# 悪い: ループ内で文字列連結
result = ""
items.each { |item| result += item.to_s }

# 良い: join を使用
result = items.map(&:to_s).join

# 良い: StringIO を使用（大量のデータ）
require 'stringio'
buffer = StringIO.new
items.each { |item| buffer << item.to_s }
result = buffer.string
```

## テストパターン

### RSpec の基本構造

```ruby
RSpec.describe UserService do
  describe '#find' do
    subject(:service) { described_class.new(repository: repository) }

    let(:repository) { instance_double(UserRepository) }
    let(:user) { build(:user, id: 1) }

    context 'ユーザーが存在する場合' do
      before do
        allow(repository).to receive(:find).with(1).and_return(user)
      end

      it 'ユーザーを返す' do
        expect(service.find(1)).to eq(user)
      end
    end

    context 'ユーザーが存在しない場合' do
      before do
        allow(repository).to receive(:find).with(1).and_return(nil)
      end

      it 'nilを返す' do
        expect(service.find(1)).to be_nil
      end
    end
  end
end
```

### FactoryBot パターン

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { Faker::Name.name }
    status { :active }

    trait :admin do
      role { :admin }
    end

    trait :with_posts do
      transient do
        posts_count { 3 }
      end

      after(:create) do |user, evaluator|
        create_list(:post, evaluator.posts_count, user: user)
      end
    end
  end
end

# 使用
create(:user)
create(:user, :admin)
create(:user, :with_posts, posts_count: 5)
```

## ツール統合

### 必須コマンド

```bash
# テスト実行
bundle exec rspec
bundle exec rspec --format documentation

# コードスタイルチェック
bundle exec rubocop
bundle exec rubocop -a  # 自動修正

# セキュリティチェック
bundle exec brakeman  # Railsアプリ
bundle exec bundler-audit check

# 依存関係
bundle install
bundle update
bundle outdated
```

### RuboCop 設定 (.rubocop.yml)

```yaml
require:
  - rubocop-rails
  - rubocop-rspec
  - rubocop-performance

AllCops:
  NewCops: enable
  TargetRubyVersion: 3.2
  Exclude:
    - "db/**/*"
    - "vendor/**/*"
    - "bin/**/*"

Style/Documentation:
  Enabled: false

Metrics/MethodLength:
  Max: 15

Metrics/BlockLength:
  Exclude:
    - "spec/**/*"
    - "config/routes.rb"

RSpec/ExampleLength:
  Max: 10
```

## クイックリファレンス: Rubyイディオム

| イディオム           | 説明                                       |
| -------------------- | ------------------------------------------ | --- | ------------------------ |
| ダックタイピング     | 型ではなくメソッドの存在で判断             |
| ブロックとイテレータ | each, map, select などを活用               |
| シンボル to_proc     | `&:method_name` でメソッド呼び出しを簡潔に |
| 後置条件             | `return if condition` でガード節           |
| メモ化               | `@var                                      |     | = expensive_computation` |
| freeze               | 定数や設定値をイミュータブルに             |
| 安全ナビゲーション   | `obj&.method` でnilチェック                |
| 暗黙のreturn         | 最後の式が戻り値                           |

## 避けるべきアンチパターン

```ruby
# 悪い: for ループ（Rubyらしくない）
for user in users
  process(user)
end

# 良い: each を使用
users.each { |user| process(user) }

# 悪い: クラス変数（スレッドセーフでない）
class Counter
  @@count = 0  # 危険
end

# 良い: クラスインスタンス変数
class Counter
  @count = 0

  class << self
    attr_accessor :count
  end
end

# 悪い: rescue Exception
begin
  dangerous
rescue Exception => e  # NoMemoryError等も捕捉
  handle(e)
end

# 良い: rescue StandardError（または特定の例外）
begin
  dangerous
rescue StandardError => e
  handle(e)
end

# 悪い: モンキーパッチの乱用
class String
  def to_boolean
    self == 'true'
  end
end

# 良い: Refinements を使用（Ruby 2.0+）
module StringExtensions
  refine String do
    def to_boolean
      self == 'true'
    end
  end
end

# 使用する場所で明示的にusing
using StringExtensions
```

**覚えておくこと**: Rubyコードはエレガントで読みやすくあるべき。「美しいコードは正しいコードである」という哲学を持ち、開発者の幸福を優先する。迷ったら、Rubyらしさを追求する。
