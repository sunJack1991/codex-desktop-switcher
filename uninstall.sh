#!/bin/zsh
set -euo pipefail
umask 077

readonly TARGET="$HOME/.codex/switcher"
readonly CODEX_DIR="$HOME/.codex"
readonly CONFIG_PATH="$CODEX_DIR/config.toml"
readonly MODELS_PATH="$CODEX_DIR/models.json"
readonly PROFILE_DIR="$TARGET/profiles"
readonly BACKUP_DIR="$TARGET/backups"
readonly GPT_PROFILE="$PROFILE_DIR/gpt.toml"
readonly GPT_MODELS_PROFILE="$PROFILE_DIR/models.gpt.json"
readonly GPT_MODELS_ABSENT="$PROFILE_DIR/models.gpt.absent"
readonly DEEP_MODELS_PROFILE="$PROFILE_DIR/models.deepseek.json"
readonly CODEX_APP_PATTERN="/Applications/ChatGPT.app/Contents/(MacOS|Frameworks)/"

if [[ "${CODEX_SWITCHER_TEST_MODE:-0}" == "1" ]]; then
  readonly TEST_MODE=1
else
  readonly TEST_MODE=0
fi

config_stage=""
models_stage=""
reopen_codex=0

ok() { print -r -- "✅ $*"; }
info() { print -r -- "→ $*"; }
die() { print -u2 -r -- "❌ $*"; exit 1; }

cleanup() {
  local exit_status=$?
  trap - EXIT HUP INT TERM
  [[ -z "$config_stage" || ! -e "$config_stage" ]] || /bin/rm -f -- "$config_stage"
  [[ -z "$models_stage" || ! -e "$models_stage" ]] || /bin/rm -f -- "$models_stage"
  exit "$exit_status"
}
trap cleanup EXIT HUP INT TERM

confirm() {
  local prompt="$1"
  local answer
  (( TEST_MODE == 1 )) && return 0
  read -r "answer?$prompt [y/N]: "
  [[ "$answer" == [yY] ]]
}

require_regular_file() {
  local path="$1"
  local label="$2"
  [[ -f "$path" && ! -L "$path" ]] || die "$label 不存在或不是普通文件：$path"
  [[ -r "$path" ]] || die "$label 不可读：$path"
}

require_safe_optional_file() {
  local path="$1"
  local label="$2"
  if [[ -e "$path" || -L "$path" ]]; then
    [[ -f "$path" && ! -L "$path" ]] || die "$label 不是安全的普通文件：$path"
  fi
}

is_deepseek_config() {
  [[ -f "$CONFIG_PATH" ]] && \
    /usr/bin/grep -Eq '^[[:space:]]*model_provider[[:space:]]*=[[:space:]]*"deepseek"' "$CONFIG_PATH"
}

current_models_is_deepseek_snapshot() {
  [[ -f "$MODELS_PATH" && -f "$DEEP_MODELS_PROFILE" ]] && \
    /usr/bin/cmp -s "$MODELS_PATH" "$DEEP_MODELS_PROFILE"
}

codex_app_running() {
  (( TEST_MODE == 1 )) && return 1
  /usr/bin/pgrep -f "$CODEX_APP_PATTERN" >/dev/null 2>&1
}

wait_for_codex_exit() {
  local loops="$1"
  local i=1
  while (( i <= loops )); do
    if ! codex_app_running; then return 0; fi
    /bin/sleep 0.5
    (( i++ ))
  done
  return 1
}

quit_codex_completely() {
  (( TEST_MODE == 1 )) && return 0
  if ! codex_app_running; then return 0; fi
  reopen_codex=1
  /usr/bin/osascript -e 'tell application "Codex" to quit' >/dev/null 2>&1 || true
  if wait_for_codex_exit 10; then return 0; fi
  /usr/bin/pkill -TERM -f "$CODEX_APP_PATTERN" >/dev/null 2>&1 || true
  if wait_for_codex_exit 10; then return 0; fi
  /usr/bin/pkill -KILL -f "$CODEX_APP_PATTERN" >/dev/null 2>&1 || true
  /bin/sleep 1
  codex_app_running && die "Codex.app 仍有残留进程，卸载已停止，未删除本地配置。"
}

stage_file() {
  local source="$1"
  local template="$2"
  local staged
  staged=$(/usr/bin/mktemp "$template") || return 1
  if ! /bin/cp -p "$source" "$staged"; then /bin/rm -f -- "$staged"; return 1; fi
  /bin/chmod 600 "$staged" || { /bin/rm -f -- "$staged"; return 1; }
  print -r -- "$staged"
}

next_uninstall_backup() {
  local timestamp
  local candidate
  local suffix=0
  timestamp=$(/bin/date '+%Y%m%d_%H%M%S')
  candidate="$BACKUP_DIR/uninstall_config_${timestamp}.toml"
  while [[ -e "$candidate" ]]; do
    (( suffix += 1 ))
    candidate="$BACKUP_DIR/uninstall_config_${timestamp}_$suffix.toml"
  done
  print -r -- "$candidate"
}

main() {
  local restore_config=0
  local models_action="preserve"
  local backup_path=""

  (( TEST_MODE == 1 )) || [[ "$(uname -s)" == "Darwin" ]] || die "当前脚本仅支持 macOS。"

  print -r -- "将删除："
  print -r -- "  $TARGET"
  print -r -- "  可确认属于本项目 DeepSeek 的 models.json"
  print -r -- ""
  print -r -- "不会删除："
  print -r -- "  $HOME/.codex/auth.json"
  print -r -- "  Codex / ChatGPT Desktop 应用"
  print -r -- "  无法确认归属的其他 ~/.codex 文件"
  print

  confirm "确认彻底删除 codex-switcher，并清理本项目 DeepSeek 接入文件" || { print -r -- "已取消。"; exit 0; }

  if [[ ! -e "$TARGET" && ! -L "$TARGET" ]]; then ok "codex-switcher 已不存在，无需删除"; exit 0; fi
  [[ -d "$TARGET" && ! -L "$TARGET" ]] || die "拒绝删除非目录或符号链接：$TARGET"

  require_safe_optional_file "$CONFIG_PATH" "当前 config.toml"
  require_safe_optional_file "$MODELS_PATH" "当前 models.json"
  require_safe_optional_file "$GPT_PROFILE" "GPT Profile"
  require_safe_optional_file "$GPT_MODELS_PROFILE" "GPT models 快照"
  require_safe_optional_file "$GPT_MODELS_ABSENT" "GPT models absent 标记"
  require_safe_optional_file "$DEEP_MODELS_PROFILE" "DeepSeek models 快照"

  if [[ -f "$GPT_MODELS_PROFILE" && -f "$GPT_MODELS_ABSENT" ]]; then
    die "GPT models 基线冲突：同时存在 models.gpt.json 与 models.gpt.absent。请先重新保存 GPT Profile。"
  fi

  if is_deepseek_config; then
    require_regular_file "$GPT_PROFILE" "GPT Profile"
    restore_config=1
  fi

  if [[ -f "$GPT_MODELS_PROFILE" ]]; then
    if (( restore_config == 1 )) || current_models_is_deepseek_snapshot; then
      models_action="restore-gpt"
      models_stage=$(stage_file "$GPT_MODELS_PROFILE" "$CODEX_DIR/.models.json.uninstall.XXXXXX") || die "无法暂存 GPT models 快照，卸载已停止。"
    fi
  elif [[ -f "$GPT_MODELS_ABSENT" ]]; then
    if (( restore_config == 1 )) || current_models_is_deepseek_snapshot; then models_action="remove-gpt"; fi
  elif current_models_is_deepseek_snapshot; then
    models_action="remove-known-deepseek"
  fi

  if (( restore_config == 1 )); then
    config_stage=$(stage_file "$GPT_PROFILE" "$CODEX_DIR/.config.toml.uninstall.XXXXXX") || die "无法暂存 GPT Profile，卸载已停止。"
  fi

  if (( restore_config == 1 )) || [[ "$models_action" != "preserve" ]]; then quit_codex_completely; fi

  if (( restore_config == 1 )); then
    /bin/mkdir -p "$BACKUP_DIR"
    /bin/chmod 700 "$BACKUP_DIR"
    backup_path=$(next_uninstall_backup)
    /bin/cp -p "$CONFIG_PATH" "$backup_path" || die "卸载前备份 config.toml 失败。"
    /bin/chmod 600 "$backup_path"
    /bin/mv -f "$config_stage" "$CONFIG_PATH" || die "恢复 GPT config.toml 失败；原配置保存在 $backup_path。"
    config_stage=""
    ok "已恢复 GPT config.toml"
  fi

  case "$models_action" in
    restore-gpt)
      if ! /bin/mv -f "$models_stage" "$MODELS_PATH"; then
        if (( restore_config == 1 )) && [[ -n "$backup_path" ]]; then /bin/cp -p "$backup_path" "$CONFIG_PATH" >/dev/null 2>&1 || true; fi
        die "恢复 GPT models.json 失败；codex-switcher 未删除。"
      fi
      models_stage=""
      ok "已恢复 GPT models.json 基线"
      ;;
    remove-gpt|remove-known-deepseek)
      if [[ -e "$MODELS_PATH" || -L "$MODELS_PATH" ]]; then
        if ! /bin/rm -f -- "$MODELS_PATH"; then
          if (( restore_config == 1 )) && [[ -n "$backup_path" ]]; then /bin/cp -p "$backup_path" "$CONFIG_PATH" >/dev/null 2>&1 || true; fi
          die "清理 DeepSeek models.json 失败；codex-switcher 未删除。"
        fi
        ok "已清理可确认的 DeepSeek models.json"
      fi
      ;;
    preserve)
      if [[ -f "$MODELS_PATH" ]]; then info "models.json 无法确认属于本项目 DeepSeek，已保留。"; fi
      ;;
  esac

  /bin/rm -rf -- "$TARGET"
  ok "已删除 codex-switcher：$TARGET"

  if (( reopen_codex == 1 && TEST_MODE == 0 )); then
    /usr/bin/open -a Codex >/dev/null 2>&1 || print -u2 -r -- "⚠️ 卸载完成，但 Codex 自动重新打开失败。"
  fi

  print
  ok "卸载完成"
  print -r -- "如需重装，重新运行 README 顶部的一键安装命令即可。"
}

main "$@"
