#!/bin/zsh

# Codex Desktop Switcher — provider switcher
# macOS only. Success is fully silent; every error goes to stderr.
#
# Usage:
#   codex-switcher.sh codex
#   codex-switcher.sh deepseek
#
# Aliases (still accepted for backward compatibility):
#   gpt / openai  -> codex
#   deep          -> deepseek

set -euo pipefail
umask 077

readonly BACKUP_LIMIT=20
readonly PROGRAM_NAME="${0:t}"

if [[ "${CODEX_SWITCHER_TEST_MODE:-0}" == "1" ]]; then
  readonly CODEX_DIR="${CODEX_SWITCHER_TEST_CODEX_DIR:?CODEX_SWITCHER_TEST_CODEX_DIR is required in test mode}"
  readonly TEST_MODE=1
else
  readonly CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
  readonly TEST_MODE=0
fi

readonly SWITCHER_DIR="$CODEX_DIR/switcher"
readonly PROFILE_DIR="$SWITCHER_DIR/profiles"
readonly BACKUP_DIR="$SWITCHER_DIR/backups"
readonly CONFIG_PATH="$CODEX_DIR/config.toml"
readonly MODELS_PATH="$CODEX_DIR/models.json"
readonly STATE_PATH="$SWITCHER_DIR/state"
readonly LOCK_DIR="$SWITCHER_DIR/.switch.lock"

config_stage=""
models_stage=""
state_stage=""
lock_held=0

usage() {
  print -u2 -r -- "Usage: $PROGRAM_NAME codex|deepseek"
  print -u2 -r -- "Aliases: gpt|openai (-> codex), deep (-> deepseek)"
}

fail() {
  local message="$1"
  print -u2 -r -- "Codex Switcher: $message"
  exit 1
}

cleanup() {
  local exit_status=$?
  trap - EXIT HUP INT TERM
  if [[ "$lock_held" == "1" ]]; then
    /bin/rmdir "$LOCK_DIR" >/dev/null 2>&1 || true
    lock_held=0
  fi
  if [[ -n "$config_stage" && -e "$config_stage" ]]; then
    /bin/rm -f -- "$config_stage"
  fi
  if [[ -n "$models_stage" && -e "$models_stage" ]]; then
    /bin/rm -f -- "$models_stage"
  fi
  if [[ -n "$state_stage" && -e "$state_stage" ]]; then
    /bin/rm -f -- "$state_stage"
  fi
  exit "$exit_status"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

require_regular_file() {
  local path="$1"
  local label="$2"

  [[ -f "$path" && ! -L "$path" ]] || fail "$label 不存在或不是普通文件：$path"
  [[ -r "$path" ]] || fail "$label 不可读：$path"
}

require_safe_optional_file() {
  local path="$1"
  local label="$2"

  if [[ -e "$path" || -L "$path" ]]; then
    [[ -f "$path" && ! -L "$path" ]] || fail "$label 不是安全的普通文件：$path"
  fi
}

require_safe_directory() {
  local path="$1"
  local label="$2"

  [[ -d "$path" && ! -L "$path" ]] || fail "$label 不存在或不是安全目录：$path"
}

acquire_lock() {
  if ! /bin/mkdir "$LOCK_DIR" 2>/dev/null; then
    fail "已有一次切换正在进行，请稍后再试。"
  fi
  lock_held=1
}

# /Codex.app/Contents/ 以匹配整个 Desktop App bundle 内的进程，避免误杀 Codex CLI。
codex_app_running() {
  /usr/bin/pgrep -f '/Codex\.app/Contents/' >/dev/null 2>&1
}

wait_for_codex_exit() {
  local loops="$1"
  local i=1
  while (( i <= loops )); do
    if ! codex_app_running; then
      return 0
    fi
    /bin/sleep 0.5
    (( i++ ))
  done
  return 1
}

# 必须彻底退出，新 Provider 才能由全新 Codex 进程加载。
quit_codex_completely() {
  (( TEST_MODE == 1 )) && return 0
  if ! codex_app_running; then
    return 0
  fi

  # Stage A — graceful
  /usr/bin/osascript -e 'tell application "Codex" to quit' >/dev/null 2>&1 || true
  if wait_for_codex_exit 10; then
    return 0
  fi

  # Stage B — TERM
  /usr/bin/pkill -TERM -f '/Codex\.app/Contents/' >/dev/null 2>&1 || true
  if wait_for_codex_exit 10; then
    return 0
  fi

  # Stage C — KILL, last resort
  /usr/bin/pkill -KILL -f '/Codex\.app/Contents/' >/dev/null 2>&1 || true
  /bin/sleep 1

  if codex_app_running; then
    fail "Codex.app 仍有残留进程，本次切换已停止，配置未修改。"
  fi
}

next_backup_path() {
  local timestamp
  local candidate
  local suffix=0

  timestamp=$(/bin/date '+%Y%m%d_%H%M%S')
  candidate="$BACKUP_DIR/config_${timestamp}.toml"
  while [[ -e "$candidate" ]]; do
    (( suffix += 1 ))
    candidate="$BACKUP_DIR/config_${timestamp}_$suffix.toml"
  done
  print -r -- "$candidate"
}

# 按修改时间升序（最老在前），只删除超出上限的最老备份，保留最新 BACKUP_LIMIT 份。
prune_backups() {
  local -a backups
  local index
  local to_remove

  backups=("$BACKUP_DIR"/config_*.toml(N.om))
  (( ${#backups} > BACKUP_LIMIT )) || return 0
  to_remove=$(( ${#backups} - BACKUP_LIMIT ))
  for (( index = 1; index <= to_remove; index += 1 )); do
    /bin/rm -f -- "${backups[$index]}"
  done
}

stage_file() {
  local source="$1"
  local template="$2"
  local staged

  staged=$(/usr/bin/mktemp "$template") || return 1
  if ! /bin/cp -p "$source" "$staged"; then
    /bin/rm -f -- "$staged"
    return 1
  fi
  /bin/chmod 600 "$staged" || {
    /bin/rm -f -- "$staged"
    return 1
  }
  print -r -- "$staged"
}

main() {
  local target
  local target_raw="${1:-}"
  local profile_path
  local models_profile_path="$PROFILE_DIR/models.deepseek.json"
  local backup_path

  [[ $# -eq 1 ]] || {
    usage
    exit 2
  }

  case "$target_raw" in
    codex|gpt|openai)
      target="codex"
      profile_path="$PROFILE_DIR/gpt.toml"
      ;;
    deepseek|deep)
      target="deepseek"
      profile_path="$PROFILE_DIR/deepseek.toml"
      ;;
    *)
      usage
      exit 2
      ;;
  esac

  require_regular_file "$CONFIG_PATH" "当前 Codex 配置"
  require_safe_directory "$SWITCHER_DIR" "Switcher 目录"
  require_safe_directory "$PROFILE_DIR" "Profile 目录"
  require_regular_file "$profile_path" "$target Profile"
  require_safe_optional_file "$STATE_PATH" "状态文件"
  if [[ "$target" == "deepseek" ]]; then
    require_regular_file "$models_profile_path" "DeepSeek models 快照"
    require_safe_optional_file "$MODELS_PATH" "当前 models.json"
  fi

  if [[ -e "$BACKUP_DIR" || -L "$BACKUP_DIR" ]]; then
    require_safe_directory "$BACKUP_DIR" "备份目录"
  fi

  /bin/mkdir -p "$BACKUP_DIR"
  /bin/chmod 700 "$SWITCHER_DIR" "$PROFILE_DIR" "$BACKUP_DIR"

  # 预检后立即拿锁，避免 Shortcut 连续点击产生竞态。
  acquire_lock

  config_stage=$(stage_file "$profile_path" "$CODEX_DIR/.config.toml.switch.XXXXXX") || \
    fail "无法暂存 $target Profile，配置未切换。"
  if [[ "$target" == "deepseek" ]]; then
    models_stage=$(stage_file "$models_profile_path" "$CODEX_DIR/.models.json.switch.XXXXXX") || \
      fail "无法暂存 DeepSeek models 快照，配置未切换。"
  fi
  state_stage=$(/usr/bin/mktemp "$SWITCHER_DIR/.state.switch.XXXXXX") || \
    fail "无法暂存状态文件，配置未切换。"
  print -r -- "$target" > "$state_stage"
  /bin/chmod 600 "$state_stage"

  quit_codex_completely

  backup_path=$(next_backup_path)
  if ! /bin/cp -p "$CONFIG_PATH" "$backup_path"; then
    fail "备份当前 config.toml 失败，配置未切换。"
  fi
  /bin/chmod 600 "$backup_path"

  # DeepSeek models 先落盘，config.toml 最后原子替换；中断时不会留下引用缺失 models 的配置。
  if [[ "$target" == "deepseek" ]]; then
    if ! /bin/mv -f "$models_stage" "$MODELS_PATH"; then
      fail "安装 DeepSeek models 快照失败，原配置未切换。"
    fi
    models_stage=""
  fi

  if (( TEST_MODE == 1 )) && [[ "${CODEX_SWITCHER_TEST_ABORT_BEFORE_CONFIG:-0}" == "1" ]]; then
    exit 97
  fi

  if ! /bin/mv -f "$config_stage" "$CONFIG_PATH"; then
    fail "替换 config.toml 失败；原配置仍保存在 $backup_path。"
  fi
  config_stage=""

  if ! /bin/mv -f "$state_stage" "$STATE_PATH"; then
    print -u2 -r -- "Codex Switcher: 配置已切换，但状态文件写入失败。"
  else
    state_stage=""
  fi

  prune_backups

  if (( TEST_MODE == 0 )); then
    if ! /usr/bin/open -a Codex; then
      print -u2 -r -- "Codex Switcher: 配置已切换到 $target，但 Codex 启动失败。"
      exit 1
    fi
  fi
}

main "$@"
