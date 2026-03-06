---
name: ruby-testing
description: RSpec/Minitestによるテストパターン、パラメータ化テスト、モック、ベンチマーク、テストカバレッジを含むRubyテストパターン。イディオマティックなRubyプラクティスに従ったTDD手法。
---

# Rubyテストパターン

TDD手法に従った、信頼性が高く保守性のあるテストを書くための包括的なRubyテストパターン。

## 起動タイミング

- 新しいRubyクラスやメソッドを書くとき
- 既存コードにテストカバレッジを追加するとき
- パフォーマンス重視のコードのベンチマークを作成するとき
- RubyプロジェクトでTDDワークフローに従うとき

## RubyのためのTDDワークフロー

### RED-GREEN-REFACTORサイクル

```
RED     → まず失敗するテストを書く
GREEN   → テストを通過させる最小限のコードを書く
REFACTOR → テストをグリーンに保ちながらコードを改善
REPEAT  → 次の要件に進む
```

### RSpec でのステップバイステップTDD

```ruby
# ステップ1：クラス/メソッドを定義
# lib/calculator.rb
class Calculator
  def add(a, b)
    raise NotImplementedError, "not implemented" # プレースホルダー
  end
end

# ステップ2：失敗するテストを書く（RED）
# spec/calculator_spec.rb
require 'spec_helper'
require 'calculator'

RSpec.describe Calculator do
  describe '#add' do
    it '2つの数を加算する' do
      calculator = Calculator.new
      expect(calculator.add(2, 3)).to eq(5)
    end
  end
end

# ステップ3：テストを実行 - 失敗を確認
# $ bundle exec rspec
# Failures:
#   1) Calculator#add 2つの数を加算する
#      NotImplementedError: not implemented

# ステップ4：最小限のコードを実装（GREEN）
class Calculator
  def add(a, b)
    a + b
  end
end

# ステップ5：再度テストを実行 - 通過を確認
# $ bundle exec rspec
# 1 example, 0 failures

# ステップ6：必要に応じてリファクタリング、テストが通過することを確認
```

## パラメータ化テスト（テーブル駆動テスト相当）

RSpecの標準パターン。最小限のコードで包括的なカバレッジを実現。

```ruby
RSpec.describe Calculator do
  describe '#add' do
    [
      { name: '正の数', a: 2, b: 3, expected: 5 },
      { name: '負の数', a: -1, b: -2, expected: -3 },
      { name: 'ゼロ値', a: 0, b: 0, expected: 0 },
      { name: '符号混在', a: -1, b: 1, expected: 0 },
      { name: '大きな数', a: 1_000_000, b: 2_000_000, expected: 3_000_000 },
    ].each do |test_case|
      it "#{test_case[:name]}: #{test_case[:a]} + #{test_case[:b]} = #{test_case[:expected]}" do
        calculator = Calculator.new
        expect(calculator.add(test_case[:a], test_case[:b])).to eq(test_case[:expected])
      end
    end
  end
end
```

### shared_examples を使ったパラメータ化テスト

```ruby
RSpec.shared_examples 'a valid addition' do |a, b, expected|
  it "#{a} + #{b} = #{expected}" do
    expect(calculator.add(a, b)).to eq(expected)
  end
end

RSpec.describe Calculator do
  let(:calculator) { Calculator.new }

  describe '#add' do
    it_behaves_like 'a valid addition', 2, 3, 5
    it_behaves_like 'a valid addition', -1, -2, -3
    it_behaves_like 'a valid addition', 0, 0, 0
  end
end
```

### エラーケース付きパラメータ化テスト

```ruby
RSpec.describe ConfigParser do
  describe '.parse' do
    [
      {
        name: '有効な設定',
        input: '{"host": "localhost", "port": 8080}',
        expected: { 'host' => 'localhost', 'port' => 8080 },
        raises_error: false,
      },
      {
        name: '無効なJSON',
        input: '{invalid}',
        raises_error: true,
      },
      {
        name: '空の入力',
        input: '',
        raises_error: true,
      },
      {
        name: '最小限の設定',
        input: '{}',
        expected: {},
        raises_error: false,
      },
    ].each do |test_case|
      context test_case[:name] do
        if test_case[:raises_error]
          it 'エラーを発生させる' do
            expect { ConfigParser.parse(test_case[:input]) }.to raise_error(JSON::ParserError)
          end
        else
          it '正しい値を返す' do
            expect(ConfigParser.parse(test_case[:input])).to eq(test_case[:expected])
          end
        end
      end
    end
  end
end
```

## コンテキストとネスト

### 関連テストの整理

```ruby
RSpec.describe UserRepository do
  let(:db) { setup_test_db }

  describe '#create' do
    it 'ユーザーを作成する' do
      user = User.new(name: 'Alice')
      result = db.create_user(user)

      expect(result).to be_truthy
      expect(user.id).not_to be_nil
    end
  end

  describe '#find' do
    before do
      @user = db.create_user(User.new(name: 'Alice'))
    end

    it 'ユーザーを取得する' do
      found = db.find_user(@user.id)

      expect(found).not_to be_nil
      expect(found.name).to eq('Alice')
    end
  end

  describe '#update' do
    # ...
  end

  describe '#delete' do
    # ...
  end
end
```

### context を使った条件分岐

```ruby
RSpec.describe UserService do
  describe '#authenticate' do
    context '有効な認証情報の場合' do
      it 'ユーザーを返す' do
        user = UserService.authenticate('alice@example.com', 'password123')
        expect(user).not_to be_nil
        expect(user.email).to eq('alice@example.com')
      end
    end

    context '無効なパスワードの場合' do
      it 'nilを返す' do
        user = UserService.authenticate('alice@example.com', 'wrong_password')
        expect(user).to be_nil
      end
    end

    context '存在しないユーザーの場合' do
      it 'nilを返す' do
        user = UserService.authenticate('unknown@example.com', 'password')
        expect(user).to be_nil
      end
    end
  end
end
```

## テストヘルパー

### カスタムマッチャー

```ruby
# spec/support/matchers/json_matchers.rb
RSpec::Matchers.define :be_valid_json do
  match do |actual|
    JSON.parse(actual)
    true
  rescue JSON::ParserError
    false
  end
end

# spec/support/matchers/have_error_on.rb
RSpec::Matchers.define :have_error_on do |attribute|
  match do |model|
    model.valid?
    model.errors[attribute].any?
  end
end

# 使用例
RSpec.describe 'JSON validation' do
  it 'is valid JSON' do
    expect('{"key": "value"}').to be_valid_json
  end
end
```

### ヘルパーメソッド

```ruby
# spec/support/database_helpers.rb
module DatabaseHelpers
  def setup_test_db
    db = SQLite3::Database.new(':memory:')
    db.execute(schema)
    db
  end

  def create_test_user(attributes = {})
    User.create!(
      {
        name: 'Test User',
        email: 'test@example.com',
      }.merge(attributes)
    )
  end
end

RSpec.configure do |config|
  config.include DatabaseHelpers
end

# 使用例
RSpec.describe UserRepository do
  let(:db) { setup_test_db }
  let(:user) { create_test_user(name: 'Alice') }

  it 'finds the user' do
    expect(db.find(user.id)).to eq(user)
  end
end
```

### 一時ファイルとディレクトリ

```ruby
require 'tempfile'
require 'tmpdir'

RSpec.describe FileProcessor do
  describe '#process' do
    it 'ファイルを処理する' do
      Dir.mktmpdir do |tmp_dir|
        # テストファイルを作成
        test_file = File.join(tmp_dir, 'test.txt')
        File.write(test_file, 'test content')

        # テストを実行
        result = FileProcessor.process(test_file)

        expect(result).to be_truthy
      end
      # ブロック終了時に自動的にクリーンアップ
    end
  end
end
```

## let と let! の使い分け

```ruby
RSpec.describe Order do
  # let - 遅延評価（初めて呼ばれたときに評価）
  let(:user) { User.create!(name: 'Alice') }
  let(:product) { Product.create!(name: 'Widget', price: 100) }
  let(:order) { Order.new(user: user, product: product) }

  # let! - 即時評価（各テストの前に評価）
  let!(:existing_order) { Order.create!(user: user, product: product) }

  describe '#total' do
    it '合計金額を計算する' do
      expect(order.total).to eq(100)
    end
  end

  describe '.find_by_user' do
    it 'ユーザーの注文を見つける' do
      # existing_order は let! なので既に作成されている
      expect(Order.find_by_user(user)).to include(existing_order)
    end
  end
end
```

## before / after フック

```ruby
RSpec.describe DatabaseOperations do
  before(:all) do
    # すべてのテストの前に1回だけ実行
    @connection = Database.connect
  end

  after(:all) do
    # すべてのテストの後に1回だけ実行
    @connection.close
  end

  before(:each) do
    # 各テストの前に実行
    @connection.begin_transaction
  end

  after(:each) do
    # 各テストの後に実行
    @connection.rollback
  end

  it 'inserts a record' do
    # テスト...
  end
end

# around フック
RSpec.describe 'Time-sensitive tests' do
  around(:each) do |example|
    Timecop.freeze(Time.local(2024, 1, 1)) do
      example.run
    end
  end

  it 'returns the frozen time' do
    expect(Time.now.year).to eq(2024)
  end
end
```

## モックとスタブ

### RSpec Mocks

```ruby
RSpec.describe UserService do
  describe '#get_profile' do
    it 'ユーザープロファイルを取得する' do
      # ダブルを作成
      repository = instance_double(UserRepository)

      # スタブを設定
      allow(repository).to receive(:find).with('123').and_return(
        User.new(id: '123', name: 'Alice')
      )

      service = UserService.new(repository)
      profile = service.get_profile('123')

      expect(profile.name).to eq('Alice')
    end

    it 'メソッド呼び出しを検証する' do
      repository = instance_double(UserRepository)

      # 呼び出しを期待
      expect(repository).to receive(:find).with('123').and_return(
        User.new(id: '123', name: 'Alice')
      )

      service = UserService.new(repository)
      service.get_profile('123')
    end
  end
end
```

### 部分モック

```ruby
RSpec.describe ExternalApiClient do
  describe '#fetch_data' do
    it '外部APIを呼び出す' do
      client = ExternalApiClient.new

      # 特定のメソッドだけをスタブ
      allow(client).to receive(:http_get).and_return(
        { 'status' => 'success', 'data' => [1, 2, 3] }
      )

      result = client.fetch_data
      expect(result).to eq([1, 2, 3])
    end
  end
end
```

### スパイ

```ruby
RSpec.describe NotificationService do
  describe '#send_welcome_email' do
    it 'メール送信を呼び出す' do
      mailer = spy('Mailer')
      service = NotificationService.new(mailer)

      service.send_welcome_email('alice@example.com')

      # 後から呼び出しを検証
      expect(mailer).to have_received(:send).with(
        to: 'alice@example.com',
        subject: 'Welcome!',
        body: anything
      )
    end
  end
end
```

## ベンチマーク

### benchmark-ips を使ったベンチマーク

```ruby
require 'benchmark/ips'

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  parts = %w[hello world foo bar baz]

  x.report('plus') do
    s = ''
    parts.each { |p| s += p }
    s
  end

  x.report('shovel') do
    s = ''
    parts.each { |p| s << p }
    s
  end

  x.report('join') do
    parts.join
  end

  x.compare!
end

# 出力:
# Comparison:
#                 join: 2000000.0 i/s
#               shovel: 1500000.0 i/s - 1.33x slower
#                 plus:  500000.0 i/s - 4.00x slower
```

### メモリベンチマーク

```ruby
require 'benchmark/memory'

Benchmark.memory do |x|
  parts = %w[hello world foo bar baz]

  x.report('plus') do
    s = ''
    parts.each { |p| s += p }
  end

  x.report('shovel') do
    s = ''
    parts.each { |p| s << p }
  end

  x.report('join') do
    parts.join
  end

  x.compare!
end
```

### 標準ライブラリでのベンチマーク

```ruby
require 'benchmark'

n = 100_000

Benchmark.bm(10) do |x|
  x.report('for loop:') do
    for i in 1..n
      a = "1"
    end
  end

  x.report('times:') do
    n.times do
      a = "1"
    end
  end

  x.report('upto:') do
    1.upto(n) do
      a = "1"
    end
  end
end
```

## テストカバレッジ

### SimpleCov の設定

```ruby
# spec/spec_helper.rb
require 'simplecov'

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'

  add_group 'Models', 'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Services', 'app/services'
  add_group 'Libraries', 'lib'

  minimum_coverage 80
  minimum_coverage_by_file 70
end

# カバレッジを実行
# $ bundle exec rspec
# Coverage report generated to coverage/index.html
```

### カバレッジ目標

| コードタイプ           | 目標    |
| ---------------------- | ------- |
| 重要なビジネスロジック | 100%    |
| パブリックAPI          | 90%以上 |
| 一般コード             | 80%以上 |
| 生成コード             | 除外    |

## Rack/Rails テスト

### Rack::Test を使ったAPIテスト

```ruby
require 'rack/test'

RSpec.describe 'Health API' do
  include Rack::Test::Methods

  def app
    MyApp
  end

  describe 'GET /health' do
    it 'OKを返す' do
      get '/health'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('OK')
    end
  end
end

RSpec.describe 'Users API' do
  include Rack::Test::Methods

  def app
    MyApp
  end

  [
    {
      name: 'ユーザー取得',
      method: :get,
      path: '/users/123',
      expected_status: 200,
      expected_body: '{"id":"123","name":"Alice"}',
    },
    {
      name: '見つからない',
      method: :get,
      path: '/users/999',
      expected_status: 404,
    },
    {
      name: 'ユーザー作成',
      method: :post,
      path: '/users',
      body: '{"name":"Bob"}',
      expected_status: 201,
    },
  ].each do |test_case|
    context test_case[:name] do
      it "正しいステータスを返す" do
        if test_case[:body]
          header 'Content-Type', 'application/json'
          send(test_case[:method], test_case[:path], test_case[:body])
        else
          send(test_case[:method], test_case[:path])
        end

        expect(last_response.status).to eq(test_case[:expected_status])

        if test_case[:expected_body]
          expect(last_response.body).to eq(test_case[:expected_body])
        end
      end
    end
  end
end
```

### Rails Request Spec

```ruby
# spec/requests/users_spec.rb
require 'rails_helper'

RSpec.describe 'Users', type: :request do
  describe 'GET /users/:id' do
    let!(:user) { User.create!(name: 'Alice') }

    it 'ユーザーを返す' do
      get "/users/#{user.id}"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['name']).to eq('Alice')
    end
  end

  describe 'POST /users' do
    it 'ユーザーを作成する' do
      post '/users', params: { user: { name: 'Bob' } }

      expect(response).to have_http_status(:created)
      expect(User.last.name).to eq('Bob')
    end
  end
end
```

## Factory Bot

### ファクトリの定義

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    name { 'Test User' }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }

    trait :admin do
      role { 'admin' }
    end

    trait :with_posts do
      after(:create) do |user|
        create_list(:post, 3, user: user)
      end
    end
  end

  factory :post do
    title { 'Test Post' }
    body { 'This is a test post.' }
    user
  end
end

# 使用例
RSpec.describe Post do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:user_with_posts) { create(:user, :with_posts) }

  it 'belongs to a user' do
    post = create(:post, user: user)
    expect(post.user).to eq(user)
  end
end
```

## テストコマンド

```bash
# すべてのテストを実行
bundle exec rspec

# 詳細出力でテストを実行
bundle exec rspec --format documentation

# 特定のファイルを実行
bundle exec rspec spec/models/user_spec.rb

# 特定の行を実行
bundle exec rspec spec/models/user_spec.rb:42

# パターンに一致するテストを実行
bundle exec rspec --example "User#authenticate"

# タグ付きテストを実行
bundle exec rspec --tag focus
bundle exec rspec --tag ~slow  # slowタグを除外

# 失敗したテストのみ再実行
bundle exec rspec --only-failures

# 並列実行
bundle exec parallel_rspec spec/

# カバレッジ付きでテストを実行
COVERAGE=true bundle exec rspec

# プロファイリング（遅いテストを特定）
bundle exec rspec --profile 10
```

## Minitest での書き方

```ruby
require 'minitest/autorun'

class CalculatorTest < Minitest::Test
  def setup
    @calculator = Calculator.new
  end

  def test_add_positive_numbers
    assert_equal 5, @calculator.add(2, 3)
  end

  def test_add_negative_numbers
    assert_equal(-3, @calculator.add(-1, -2))
  end

  def test_add_with_zero
    assert_equal 0, @calculator.add(0, 0)
  end
end

# パラメータ化テスト（Minitestの場合）
class CalculatorParameterizedTest < Minitest::Test
  CASES = [
    { a: 2, b: 3, expected: 5 },
    { a: -1, b: -2, expected: -3 },
    { a: 0, b: 0, expected: 0 },
  ]

  CASES.each_with_index do |test_case, i|
    define_method("test_add_case_#{i}") do
      calculator = Calculator.new
      assert_equal test_case[:expected], calculator.add(test_case[:a], test_case[:b])
    end
  end
end
```

## ベストプラクティス

**すべきこと：**

- テストを最初に書く（TDD）
- パラメータ化テストで包括的なカバレッジを実現
- 実装ではなく動作をテスト
- `let` と `let!` を適切に使い分ける
- 独立したテストに `parallel` gem を使用
- `before` / `after` フックでセットアップとクリーンアップ
- シナリオを説明する意味のある `describe` / `context` を使用

**すべきでないこと：**

- プライベートメソッドを直接テスト（パブリックAPI経由でテスト）
- テストで `sleep` を使用（モックや条件を使用）
- 不安定なテストを無視（修正または削除）
- すべてをモック（可能な場合は統合テストを優先）
- エラーパスのテストをスキップ

## CI/CDとの統合

```yaml
# GitHub Actionsの例
test:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: ruby/setup-ruby@v1
      with:
        ruby-version: "3.3"
        bundler-cache: true

    - name: テストを実行
      run: bundle exec rspec --format progress --format RspecJunitFormatter --out tmp/rspec.xml

    - name: カバレッジを確認
      run: |
        coverage=$(cat coverage/.last_run.json | jq '.result.line')
        if [ $(echo "$coverage < 80" | bc) -eq 1 ]; then
          echo "Coverage $coverage% is below 80%"
          exit 1
        fi
```

**覚えておく**：テストはドキュメントです。コードがどのように使われるべきかを示します。明確に書き、最新の状態を保ちましょう。
