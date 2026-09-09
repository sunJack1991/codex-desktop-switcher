#!/bin/zsh

set -euo pipefail
umask 077

readonly BACKUP_LIMIT=20
readonly CODEX_PROCESS_NAME="Codex"
readonly PROGRAM_NAME="${0:t}"

if [[ "${CODEX_SWITCHER_TEST_MODE:-0}" == "1" ]]; then
  readonly CODEX_DIR="${CODEX_SWITCHER_TEST_CODEX_DIR:?CODEX_SWITCHER_TEST_CODEX_DIR is required in test mode}"
  readonly TEST_MODE=1
else
  readonly CODEX_DIR="$HOME/.codex"
  readonly TEST_MODE=0
fi

readonly SWITCHER_DIR="$CODEX_DIR/switcher"
readonly PROFILE_DIR="$SWITCHER_DIR/profiles"
readonly BACKUP_DIR="$SWITCHER_DIR/backups"
readonly CONFIG_PATH="$CODEX_DIR/config.toml"
readonly MODELS_PATH="$CODEX_DIR/models.json"
readonly STATE_PATH="$SWITCHER_DIR/state"

config_stage=""
models_stage=""
state_stage=""

usage() {
  print -u2 -r -- "Usage: $PROGRAM_NAME gpt|deepseek"
}

fail() {
  local message="$1"

  print -u2 -r -- "Codex Switcher: $message"
  exit 1
}

cleanup() {
  local exit_status=$?

  trap - EXIT HUP INT TERM
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

codex_is_running() {
  local pgrep_status

  if /usr/bin/pgrep -x "$CODEX_PROCESS_NAME" >/dev/null 2>&1; then
    return 0
  else
    pgrep_status=$?
  fi
  (( pgrep_status == 1 )) && return 1
  fail "无法检查 Codex 进程状态，配置未切换。"
}

quit_codex() {
  local attempt

  (( TEST_MODE == 1 )) && return 0
  codex_is_running || return 0

  if ! /usr/bin/osascript -e 'tell application "Codex" to quit' >/dev/null 2>&1; then
    fail "无法请求 Codex 正常退出，配置未切换。"
  fi

  for attempt in {1..10}; do
    codex_is_running || return 0
    /bin/sleep 1
  done

  fail "Codex 在 10 秒内未退出，配置未切换。"
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

prune_backups() {
  local -a backups
  local index

  backups=("$BACKUP_DIR"/config_*.toml(N.om))
  for (( index = BACKUP_LIMIT + 1; index <= ${#backups}; index += 1 )); do
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
  local target="${1:-}"
  local profile_path
  local models_profile_path="$PROFILE_DIR/models.deepseek.json"
  local backup_path

  [[ $# -eq 1 ]] || {
    usage
    exit 2
  }

  case "$target" in
    gpt)
      profile_path="$PROFILE_DIR/gpt.toml"
      ;;
    deepseek)
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

  quit_codex

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
