#!/bin/zsh

set -euo pipefail
umask 077

readonly SCRIPT_DIR="${0:A:h}"
readonly PROGRAM_NAME="${0:t}"
readonly SOURCE_SWITCHER="$SCRIPT_DIR/codex-switch.sh"
readonly CODEX_DIR="$HOME/.codex"
readonly CONFIG_PATH="$CODEX_DIR/config.toml"
readonly MODELS_PATH="$CODEX_DIR/models.json"
readonly SWITCHER_DIR="$CODEX_DIR/switcher"
readonly PROFILE_DIR="$SWITCHER_DIR/profiles"
readonly BACKUP_DIR="$SWITCHER_DIR/backups"
readonly BIN_DIR="$SWITCHER_DIR/bin"

usage() {
  print -u2 -r -- "Usage:"
  print -u2 -r -- "  $PROGRAM_NAME install"
  print -u2 -r -- "  $PROGRAM_NAME save-deepseek --confirmed-working"
  print -u2 -r -- "  $PROGRAM_NAME save-gpt --confirmed-working"
  print -u2 -r -- "  $PROGRAM_NAME check"
}

fail() {
  print -u2 -r -- "Codex Switcher setup: $1"
  exit 1
}

require_regular_file() {
  local path="$1"
  local label="$2"

  [[ -f "$path" && ! -L "$path" ]] || fail "$label 不存在或不是普通文件：$path"
  [[ -r "$path" ]] || fail "$label 不可读：$path"
}

prepare_directories() {
  local directory

  for directory in "$SWITCHER_DIR" "$PROFILE_DIR" "$BACKUP_DIR" "$BIN_DIR"; do
    if [[ -e "$directory" || -L "$directory" ]]; then
      [[ -d "$directory" && ! -L "$directory" ]] || \
        fail "拒绝使用非目录或符号链接路径：$directory"
    else
      /bin/mkdir "$directory" || fail "无法创建目录：$directory"
    fi
  done
  /bin/chmod 700 "$SWITCHER_DIR" "$PROFILE_DIR" "$BACKUP_DIR" "$BIN_DIR"
}

atomic_copy_private() {
  local source="$1"
  local destination="$2"
  local staged

  if [[ -e "$destination" || -L "$destination" ]]; then
    [[ -f "$destination" && ! -L "$destination" ]] || \
      fail "拒绝覆盖非普通文件或符号链接：$destination"
  fi
  staged=$(/usr/bin/mktemp "${destination}.new.XXXXXX") || fail "无法创建临时文件：$destination"
  if ! /bin/cp -p "$source" "$staged"; then
    /bin/rm -f -- "$staged"
    fail "复制失败：$destination"
  fi
  /bin/chmod 600 "$staged" || {
    /bin/rm -f -- "$staged"
    fail "无法设置私有文件权限：$destination"
  }
  /bin/mv -f "$staged" "$destination" || {
    /bin/rm -f -- "$staged"
    fail "无法安装文件：$destination"
  }
}

backup_existing_profile() {
  local profile="$1"
  local name="$2"
  local timestamp
  local destination
  local suffix=0

  if [[ -e "$profile" || -L "$profile" ]]; then
    [[ -f "$profile" && ! -L "$profile" ]] || fail "旧 $name Profile 不是安全的普通文件。"
  else
    return 0
  fi
  timestamp=$(/bin/date '+%Y%m%d_%H%M%S')
  destination="$BACKUP_DIR/profile_${name}_${timestamp}.bak"
  while [[ -e "$destination" ]]; do
    (( suffix += 1 ))
    destination="$BACKUP_DIR/profile_${name}_${timestamp}_$suffix.bak"
  done
  /bin/cp -p "$profile" "$destination" || \
    fail "旧 $name Profile 备份失败，未覆盖。"
  /bin/chmod 600 "$destination"
}

install_switcher() {
  require_regular_file "$SOURCE_SWITCHER" "项目脚本"
  prepare_directories
  atomic_copy_private "$SOURCE_SWITCHER" "$BIN_DIR/codex-switch.sh"
  /bin/chmod 700 "$BIN_DIR/codex-switch.sh"
  print -r -- "已安装：$BIN_DIR/codex-switch.sh"
}

save_deepseek() {
  [[ "${1:-}" == "--confirmed-working" ]] || \
    fail "仅在 DeepSeek 已实际验证可用后执行，并传入 --confirmed-working。"
  require_regular_file "$CONFIG_PATH" "当前 Codex 配置"
  require_regular_file "$MODELS_PATH" "当前 DeepSeek models.json"
  prepare_directories
  backup_existing_profile "$PROFILE_DIR/deepseek.toml" "deepseek"
  backup_existing_profile "$PROFILE_DIR/models.deepseek.json" "models_deepseek"
  atomic_copy_private "$CONFIG_PATH" "$PROFILE_DIR/deepseek.toml"
  atomic_copy_private "$MODELS_PATH" "$PROFILE_DIR/models.deepseek.json"
  print -r -- "已保存经人工确认的 DeepSeek Profile。"
}

save_gpt() {
  [[ "${1:-}" == "--confirmed-working" ]] || \
    fail "仅在 GPT 已实际验证可用后执行，并传入 --confirmed-working。"
  require_regular_file "$CONFIG_PATH" "当前 Codex 配置"
  prepare_directories
  backup_existing_profile "$PROFILE_DIR/gpt.toml" "gpt"
  atomic_copy_private "$CONFIG_PATH" "$PROFILE_DIR/gpt.toml"
  print -r -- "已保存经人工确认的 GPT Profile。"
}

check_path() {
  local path="$1"
  local label="$2"

  if [[ -f "$path" && ! -L "$path" ]]; then
    print -r -- "OK      $label"
  else
    print -r -- "MISSING $label"
  fi
}

check_setup() {
  check_path "$CONFIG_PATH" "当前 config.toml"
  check_path "$PROFILE_DIR/gpt.toml" "GPT Profile"
  check_path "$PROFILE_DIR/deepseek.toml" "DeepSeek Profile"
  check_path "$PROFILE_DIR/models.deepseek.json" "DeepSeek models 快照"
  check_path "$BIN_DIR/codex-switch.sh" "已安装的切换脚本"
}

main() {
  local command="${1:-}"

  case "$command" in
    install)
      [[ $# -eq 1 ]] || {
        usage
        exit 2
      }
      install_switcher
      ;;
    save-deepseek)
      [[ $# -eq 2 ]] || {
        usage
        exit 2
      }
      save_deepseek "$2"
      ;;
    save-gpt)
      [[ $# -eq 2 ]] || {
        usage
        exit 2
      }
      save_gpt "$2"
      ;;
    check)
      [[ $# -eq 1 ]] || {
        usage
        exit 2
      }
      check_setup
      ;;
    *)
      usage
      exit 2
      ;;
  esac
}

main "$@"
