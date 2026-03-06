#!/bin/bash
# Strategic Compact Suggester
# Runs on PreToolUse or periodically to suggest manual compaction at logical intervals
#
# Why manual over auto-compact:
# - Auto-compact happens at arbitrary points, often mid-task
# - Strategic compacting preserves context through logical phases
# - Compact after exploration, before execution
# - Compact after completing a milestone, before starting next
#
# Hook config (in ~/.claude/settings.json):
# {
#   "hooks": {
#     "PreToolUse": [{
#       "matcher": "tool == \"Edit\" || tool == \"Write\"",
#       "hooks": [{
#         "type": "command",
#         "command": "~/.claude/skills/strategic-compact/suggest-compact.sh"
#       }]
#     }]
#   }
# }
#
# Criteria for suggesting compact:
# - Session has been running for extended period
# - Large number of tool calls made
# - Transitioning from research/exploration to implementation
# - Plan has been finalized
#
# Security improvements:
# - Session ID sanitization to prevent path traversal
# - User-specific temp directory with UID
# - Threshold validation
# - File locking for atomic operations

set -euo pipefail

# エラーハンドリング - Claude Codeの動作を妨げない
handle_error() {
  exit 0
}
trap handle_error ERR

# =============================================================================
# セキュリティ: ユーザー固有の一時ディレクトリ
# =============================================================================
# XDG_RUNTIME_DIRが最も安全（ユーザー専用、権限制限済み）
# 利用不可の場合はユーザーIDを含めたディレクトリを使用
if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "${XDG_RUNTIME_DIR}" ]; then
  RUNTIME_DIR="${XDG_RUNTIME_DIR}"
else
  # ユーザーIDを含めてマルチユーザー環境での衝突を防止
  USER_ID=$(id -u 2>/dev/null || echo "unknown")
  RUNTIME_DIR="${TMPDIR:-/tmp}/claude-user-${USER_ID}"
fi

COUNTER_DIR="${RUNTIME_DIR}/claude-compact"

# ディレクトリが存在しない場合は作成（権限700: owner only）
if [ ! -d "$COUNTER_DIR" ]; then
  mkdir -p "$COUNTER_DIR" 2>/dev/null || exit 0
  chmod 700 "$COUNTER_DIR" 2>/dev/null || true
fi

# ディレクトリの権限を確認（他ユーザーが作成した場合は使用しない）
if [ "$(stat -f '%u' "$COUNTER_DIR" 2>/dev/null || stat -c '%u' "$COUNTER_DIR" 2>/dev/null)" != "$(id -u)" ]; then
  # 自分が所有していないディレクトリは使用しない（セキュリティリスク）
  exit 0
fi

# =============================================================================
# セキュリティ: セッションIDのサニタイズ（パストラバーサル防止）
# =============================================================================
SESSION_ID="${CLAUDE_SESSION_ID:-$$}"
# 英数字、ハイフン、アンダースコアのみ許可（パストラバーサル攻撃を防止）
SESSION_ID="${SESSION_ID//[^a-zA-Z0-9_-]/}"
# 空になった場合はPIDを使用
if [ -z "$SESSION_ID" ]; then
  SESSION_ID="$$"
fi
# 長すぎる場合は切り詰め（ファイルシステムの制限対策）
SESSION_ID="${SESSION_ID:0:64}"

COUNTER_FILE="${COUNTER_DIR}/count-${SESSION_ID}"

# =============================================================================
# セキュリティ: 閾値の検証
# =============================================================================
THRESHOLD="${COMPACT_THRESHOLD:-50}"
# 数値でない場合、または1未満の場合はデフォルト値を使用
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || [ "$THRESHOLD" -lt 1 ] || [ "$THRESHOLD" -gt 10000 ]; then
  THRESHOLD=50
fi

# =============================================================================
# クリーンアップ関数（古いファイルを削除）
# =============================================================================
cleanup_old_files() {
  # 24時間以上経過したファイルを削除
  # レースコンディション防止のため、自分が所有するファイルのみ削除
  find "$COUNTER_DIR" -name "count-*" -type f -user "$(id -u)" -mmin +1440 -delete 2>/dev/null || true
}

# 10回に1回の確率でクリーンアップを実行（毎回実行するとオーバーヘッド）
if [ $((RANDOM % 10)) -eq 0 ]; then
  cleanup_old_files
fi

# =============================================================================
# カウンター操作（ファイルロック付き）
# =============================================================================
# flockが利用可能な場合はファイルロックを使用
increment_counter() {
  local count=0

  if [ -f "$COUNTER_FILE" ]; then
    count=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
    # 数値チェック
    if ! [[ "$count" =~ ^[0-9]+$ ]]; then
      count=0
    fi
  fi

  count=$((count + 1))

  # アトミックな書き込み（一時ファイル経由）
  local temp_file
  temp_file=$(mktemp "${COUNTER_DIR}/tmp-XXXXXX" 2>/dev/null) || return 1
  echo "$count" > "$temp_file"
  mv "$temp_file" "$COUNTER_FILE" 2>/dev/null || { rm -f "$temp_file" 2>/dev/null; return 1; }

  echo "$count"
}

# flockが利用可能かチェック
if command -v flock >/dev/null 2>&1; then
  # ファイルロック付きでカウンター操作
  LOCK_FILE="${COUNTER_DIR}/.lock-${SESSION_ID}"
  count=$(
    flock -w 5 "$LOCK_FILE" bash -c "
      count=0
      if [ -f '$COUNTER_FILE' ]; then
        count=\$(cat '$COUNTER_FILE' 2>/dev/null || echo '0')
        if ! [[ \"\$count\" =~ ^[0-9]+\$ ]]; then
          count=0
        fi
      fi
      count=\$((count + 1))
      echo \"\$count\" > '$COUNTER_FILE'
      echo \"\$count\"
    " 2>/dev/null
  ) || count=$(increment_counter)
else
  # flockが利用不可の場合は従来の方法
  count=$(increment_counter)
fi

# カウントが取得できなかった場合は終了
if [ -z "$count" ] || ! [[ "$count" =~ ^[0-9]+$ ]]; then
  exit 0
fi

# =============================================================================
# コンパクト提案
# =============================================================================
# 閾値に達した場合に提案
if [ "$count" -eq "$THRESHOLD" ]; then
  echo "[StrategicCompact] ${THRESHOLD} tool calls reached - consider /compact if transitioning phases" >&2
fi

# 閾値後、25回ごとにリマインド
if [ "$count" -gt "$THRESHOLD" ] && [ $((count % 25)) -eq 0 ]; then
  echo "[StrategicCompact] ${count} tool calls - good checkpoint for /compact if context is stale" >&2
fi

exit 0
