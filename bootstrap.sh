#!/bin/zsh
set -euo pipefail
umask 077

readonly REPO_URL="https://github.com/sunJack1991/codex-switcher.git"
readonly TARGET="$HOME/.codex/switcher"
readonly CODEX_DIR="$HOME/.codex"
readonly CONFIG_PATH="$CODEX_DIR/config.toml"
readonly MODELS_PATH="$CODEX_DIR/models.json"
readonly OFFICIAL_BACKUP_DIR="$CODEX_DIR/backup-deepseek"
readonly DEEPSEEK_SETUP_URL="https://cdn.deepseek.com/api-docs/codex-deepseek-setup-en.sh"
readonly REQUIRED_VISION_MODEL="deepseek-v4-flash-vision-exp"

temp_script=""
official_setup_has_vision=0
fallback_target_model=""

ok() {
  print -r -- "✅ $*"
}

info() {
  print -r -- "→ $*"
}

die() {
  print -u2 -r -- "❌ $*"
  exit 1
}

confirm() {
  local prompt="$1"
  local answer
  read -r "answer?$prompt [y/N]: "
  [[ "$answer" == [yY] ]]
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
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

cleanup_temp_script() {
  local path="${temp_script:-}"

  if [[ -n "$path" && ( -e "$path" || -L "$path" ) ]]; then
    /bin/rm -f -- "$path" >/dev/null 2>&1 || true
  fi
  temp_script=""
}

clear_temp_traps() {
  trap - EXIT HUP INT TERM
}

download_current_deepseek_setup() {
  info "按 DeepSeek 官方文档原始 URL 下载 Codex setup…"

  if ! /usr/bin/curl -fsSL "$DEEPSEEK_SETUP_URL" -o "$temp_script"; then
    print -u2 -r -- "❌ DeepSeek 官方 setup 下载失败：$DEEPSEEK_SETUP_URL"
    return 1
  fi

  if /usr/bin/grep -Fq "$REQUIRED_VISION_MODEL" "$temp_script"; then
    official_setup_has_vision=1
    ok "已获取 DeepSeek 官方三模型 setup：Flash / Pro / Vision"
    info "官方脚本：$DEEPSEEK_SETUP_URL"
    return 0
  fi

  official_setup_has_vision=0
  print -u2 -r -- "⚠️ DeepSeek 官方文档当前声明三模型，但本机官方 CDN 仍返回旧两模型 setup。"
  print -u2 -r -- "缺少模型：$REQUIRED_VISION_MODEL"
  info "启用兼容兜底：先由官方脚本生成本机兼容配置，再补齐官方文档定义的 Vision 条目。"
  return 0
}

choose_fallback_target_model() {
  local choice=""

  print
  print -r -- "DeepSeek 官方文档当前支持三个 Codex 模型："
  print -r -- "  1) deepseek-v4-flash"
  print -r -- "  2) deepseek-v4-pro"
  print -r -- "  3) deepseek-v4-flash-vision-exp"

  while true; do
    read -r "choice?请选择最终要使用的模型 [1-3]: "
    case "$choice" in
      1)
        fallback_target_model="deepseek-v4-flash"
        break
        ;;
      2)
        fallback_target_model="deepseek-v4-pro"
        break
        ;;
      3)
        fallback_target_model="$REQUIRED_VISION_MODEL"
        break
        ;;
      *)
        print -u2 -r -- "请输入 1、2 或 3。"
        ;;
    esac
  done

  ok "目标模型：$fallback_target_model"
}

augment_deepseek_vision_catalog() {
  local catalog="$1"
  local staged=""
  local index=0
  local flash_index=""
  local pro_seen=0
  local slug=""

  [[ -x /usr/bin/plutil ]] || die "兼容兜底需要 macOS 原生 /usr/bin/plutil。"
  [[ -x /usr/libexec/PlistBuddy ]] || die "兼容兜底需要 macOS 原生 /usr/libexec/PlistBuddy。"
  [[ -f "$catalog" && ! -L "$catalog" ]] || die "DeepSeek models.json 不存在或不是安全普通文件：$catalog"

  if /usr/bin/grep -Fq "$REQUIRED_VISION_MODEL" "$catalog"; then
    ok "DeepSeek models.json 已包含 Vision，无需补齐"
    return 0
  fi

  staged=$(/usr/bin/mktemp "${catalog}.vision.XXXXXX") || die "无法创建 Vision catalog 临时文件。"
  if ! /bin/cp -p "$catalog" "$staged"; then
    /bin/rm -f -- "$staged"
    die "无法暂存 DeepSeek models.json。"
  fi

  if ! /usr/bin/plutil -convert xml1 "$staged" >/dev/null 2>&1; then
    /bin/rm -f -- "$staged"
    die "DeepSeek models.json 不是 plutil 可解析的有效 JSON。"
  fi

  while slug=$(/usr/libexec/PlistBuddy -c "Print :models:$index:slug" "$staged" 2>/dev/null); do
    if [[ "$slug" == "deepseek-v4-flash" ]]; then
      flash_index="$index"
    elif [[ "$slug" == "deepseek-v4-pro" ]]; then
      pro_seen=1
    fi
    (( index += 1 ))
  done

  if [[ -z "$flash_index" || "$pro_seen" -ne 1 ]]; then
    /bin/rm -f -- "$staged"
    die "官方旧版 models.json 未同时包含 Flash / Pro，拒绝推导 Vision。"
  fi

  if ! /usr/libexec/PlistBuddy -c "Copy :models:$flash_index :models:$index" "$staged" >/dev/null 2>&1; then
    /bin/rm -f -- "$staged"
    die "无法从官方 Flash 条目复制 Vision 模型模板。"
  fi

  if ! /usr/libexec/PlistBuddy -c "Set :models:$index:slug $REQUIRED_VISION_MODEL" "$staged" >/dev/null 2>&1 ||
     ! /usr/libexec/PlistBuddy -c "Set :models:$index:display_name DeepSeek-V4-Flash-Vision" "$staged" >/dev/null 2>&1 ||
     ! /usr/libexec/PlistBuddy -c "Set :models:$index:description Latest frontier agentic coding model with image input." "$staged" >/dev/null 2>&1 ||
     ! /usr/libexec/PlistBuddy -c "Delete :models:$index:input_modalities" "$staged" >/dev/null 2>&1 ||
     ! /usr/libexec/PlistBuddy -c "Add :models:$index:input_modalities array" "$staged" >/dev/null 2>&1 ||
     ! /usr/libexec/PlistBuddy -c "Add :models:$index:input_modalities:0 string text" "$staged" >/dev/null 2>&1 ||
     ! /usr/libexec/PlistBuddy -c "Add :models:$index:input_modalities:1 string image" "$staged" >/dev/null 2>&1 ||
     ! /usr/libexec/PlistBuddy -c "Set :models:$index:supports_image_detail_original true" "$staged" >/dev/null 2>&1 ||
     ! /usr/libexec/PlistBuddy -c "Set :models:$index:priority 3" "$staged" >/dev/null 2>&1; then
    /bin/rm -f -- "$staged"
    die "补齐 Vision 官方差异字段失败；原 models.json 未被覆盖。"
  fi

  if /usr/libexec/PlistBuddy -c "Print :models:$index:minimal_client_version" "$staged" >/dev/null 2>&1; then
    if ! /usr/libexec/PlistBuddy -c "Set :models:$index:minimal_client_version 0.144.0" "$staged" >/dev/null 2>&1; then
      /bin/rm -f -- "$staged"
      die "设置 Vision minimal_client_version 失败；原 models.json 未被覆盖。"
    fi
  fi

  if ! /usr/bin/plutil -convert json "$staged" >/dev/null 2>&1 ||
     ! /usr/bin/plutil -lint "$staged" >/dev/null 2>&1 ||
     ! /usr/bin/grep -Fq "$REQUIRED_VISION_MODEL" "$staged"; then
    /bin/rm -f -- "$staged"
    die "补齐后的 DeepSeek models.json 校验失败；原文件未被覆盖。"
  fi

  /bin/chmod 600 "$staged" || {
    /bin/rm -f -- "$staged"
    die "无法设置补齐后 models.json 的权限。"
  }
  /bin/mv -f "$staged" "$catalog" || {
    /bin/rm -f -- "$staged"
    die "无法原子安装补齐后的 models.json。"
  }

  ok "已按 DeepSeek 官方文档补齐 Vision 模型目录"
}

next_bootstrap_config_backup_path() {
  local backup_dir="$TARGET/backups"
  local timestamp
  local candidate
  local suffix=0

  if [[ -e "$backup_dir" || -L "$backup_dir" ]]; then
    [[ -d "$backup_dir" && ! -L "$backup_dir" ]] || die "Switcher 备份路径不是安全目录：$backup_dir"
  else
    /bin/mkdir -p "$backup_dir" || die "无法创建 Switcher 备份目录：$backup_dir"
  fi
  /bin/chmod 700 "$backup_dir"

  timestamp=$(/bin/date '+%Y%m%d_%H%M%S')
  candidate="$backup_dir/bootstrap_config_$timestamp.toml"
  while [[ -e "$candidate" || -L "$candidate" ]]; do
    (( suffix += 1 ))
    candidate="$backup_dir/bootstrap_config_${timestamp}_$suffix.toml"
  done
  print -r -- "$candidate"
}

set_active_deepseek_model() {
  local target_model="$1"
  local staged=""
  local backup_path=""

  case "$target_model" in
    deepseek-v4-flash|deepseek-v4-pro|deepseek-v4-flash-vision-exp) ;;
    *) die "拒绝写入未知 DeepSeek 模型：$target_model" ;;
  esac

  [[ -f "$CONFIG_PATH" && ! -L "$CONFIG_PATH" ]] || die "当前 config.toml 不存在或不是安全普通文件。"
  backup_path="$(next_bootstrap_config_backup_path)"
  /bin/cp -p "$CONFIG_PATH" "$backup_path" || die "兼容兜底前备份 config.toml 失败。"
  /bin/chmod 600 "$backup_path"

  staged=$(/usr/bin/mktemp "${CONFIG_PATH}.model.XXXXXX") || die "无法创建 config.toml 临时文件。"
  if ! /usr/bin/awk -v target="$target_model" '
    BEGIN { in_top = 1; replaced = 0 }
    in_top && /^[[:space:]]*\[/ { in_top = 0 }
    in_top && /^[[:space:]]*model[[:space:]]*=/ && replaced == 0 {
      print "model = \"" target "\""
      replaced = 1
      next
    }
    { print }
    END { if (replaced == 0) exit 42 }
  ' "$CONFIG_PATH" > "$staged"; then
    /bin/rm -f -- "$staged"
    die "未找到可安全替换的顶层 model 字段；原 config.toml 未修改。"
  fi

  /bin/chmod 600 "$staged" || {
    /bin/rm -f -- "$staged"
    die "无法设置新 config.toml 权限。"
  }
  /bin/mv -f "$staged" "$CONFIG_PATH" || {
    /bin/rm -f -- "$staged"
    die "无法原子安装新的 config.toml。"
  }

  ok "已切换到目标 DeepSeek 模型：$target_model"
  info "修改前 config 备份：$backup_path"
}

validate_three_model_catalog() {
  local catalog="$1"
  local model

  for model in deepseek-v4-flash deepseek-v4-pro "$REQUIRED_VISION_MODEL"; do
    /usr/bin/grep -Fq "$model" "$catalog" || die "DeepSeek models.json 缺少模型：$model"
  done
}

next_stale_backup_path() {
  local timestamp
  local candidate
  local suffix=0

  timestamp=$(/bin/date '+%Y%m%d_%H%M%S')
  candidate="$CODEX_DIR/backup-deepseek.stale-$timestamp"
  while [[ -e "$candidate" || -L "$candidate" ]]; do
    (( suffix += 1 ))
    candidate="$CODEX_DIR/backup-deepseek.stale-$timestamp-$suffix"
  done
  print -r -- "$candidate"
}

prepare_deepseek_official_state() {
  local setup_script="$1"
  local archived_backup

  if [[ ! -e "$OFFICIAL_BACKUP_DIR" && ! -L "$OFFICIAL_BACKUP_DIR" ]]; then
    return 0
  fi

  [[ -d "$OFFICIAL_BACKUP_DIR" && ! -L "$OFFICIAL_BACKUP_DIR" ]] || \
    die "DeepSeek 官方备份路径不是安全目录：$OFFICIAL_BACKUP_DIR"

  require_safe_optional_file "$MODELS_PATH" "当前 models.json"

  if is_deepseek_config; then
    if [[ -f "$MODELS_PATH" ]]; then
      return 0
    fi

    print
    info "检测到 DeepSeek 官方历史状态不完整：当前仍是 DeepSeek 配置，但 models.json 缺失。"
    info "按 DeepSeek 官方建议先执行 Restore（选项 9），再继续初始化。"
    if ! /bin/bash "$setup_script" <<< "9"; then
      die "DeepSeek 官方 Restore 失败。为避免覆盖旧备份，初始化已停止。"
    fi
    is_deepseek_config && \
      die "DeepSeek 官方 Restore 返回成功，但 config.toml 仍是 DeepSeek 状态，初始化已停止。"
    ok "DeepSeek 官方历史状态已恢复"
  fi

  if [[ -e "$OFFICIAL_BACKUP_DIR" || -L "$OFFICIAL_BACKUP_DIR" ]]; then
    [[ -d "$OFFICIAL_BACKUP_DIR" && ! -L "$OFFICIAL_BACKUP_DIR" ]] || \
      die "DeepSeek 官方备份路径不是安全目录：$OFFICIAL_BACKUP_DIR"

    archived_backup="$(next_stale_backup_path)"
    /bin/mv "$OFFICIAL_BACKUP_DIR" "$archived_backup" || \
      die "无法隔离旧 DeepSeek 官方备份：$OFFICIAL_BACKUP_DIR"
    ok "已保留旧 DeepSeek 官方备份：$archived_backup"
    info "接下来官方 setup 会基于当前 GPT 配置重新创建新的 backup-deepseek。"
  fi
}

install_or_update_repo() {
  /bin/mkdir -p "$CODEX_DIR"

  if [[ -d "$TARGET/.git" ]]; then
    info "检测到现有 codex-switcher，更新 Git…"
    /usr/bin/git -C "$TARGET" pull --ff-only || die "git pull 失败。"
  elif [[ -e "$TARGET" || -L "$TARGET" ]]; then
    die "$TARGET 已存在但不是 Git 仓库。请先检查或删除后重试。"
  else
    info "从 GitHub 下载 codex-switcher…"
    /usr/bin/git clone "$REPO_URL" "$TARGET" || die "git clone 失败。"
  fi

  /bin/chmod +x "$TARGET/install.sh" "$TARGET/setup.sh" "$TARGET/uninstall.sh" "$TARGET/bin/"*.sh 2>/dev/null || true
  "$TARGET/setup.sh" install
  ok "codex-switcher 已安装到固定路径：$TARGET"
}

ensure_gpt_profile() {
  if [[ -f "$TARGET/profiles/gpt.toml" ]]; then
    ok "GPT Profile 已存在"
    return 0
  fi

  [[ -f "$CONFIG_PATH" ]] || \
    die "未找到 $CONFIG_PATH。请先安装并至少启动一次 Codex / ChatGPT Desktop，再重试。"

  if is_deepseek_config; then
    die "当前 config.toml 已是 DeepSeek 状态，无法安全创建 GPT Profile。请先恢复 GPT 后重试。"
  fi

  print
  print -r -- "首次安装需要先保存当前 GPT 配置，作为以后切回 GPT 的基线。"
  if ! confirm "请确认当前 Codex GPT 已经可以正常使用"; then
    die "未确认 GPT 可用，初始化已停止；未保存 GPT Profile。"
  fi

  "$TARGET/setup.sh" save-gpt --confirmed-working
  ok "GPT Profile 已保存"
}

run_deepseek_official_setup() {
  if [[ -f "$TARGET/profiles/deepseek.toml" && -f "$TARGET/profiles/models.deepseek.json" ]]; then
    ok "DeepSeek Profile 已存在，跳过首次接入"
    return 0
  fi

  temp_script=$(/usr/bin/mktemp -t codex-switcher-deepseek-setup) || \
    die "无法创建 DeepSeek 临时安装脚本。"

  trap 'cleanup_temp_script' EXIT
  trap 'cleanup_temp_script; exit 129' HUP
  trap 'cleanup_temp_script; exit 130' INT
  trap 'cleanup_temp_script; exit 143' TERM

  print
  print -r -- "接下来启动 DeepSeek 官方 Codex setup。"
  print -r -- "需要人工选择模型并粘贴 DeepSeek API Key；这是首次安装唯一的交互步骤。"

  if ! download_current_deepseek_setup; then
    cleanup_temp_script
    clear_temp_traps
    die "DeepSeek 官方 setup 下载失败。"
  fi

  prepare_deepseek_official_state "$temp_script"

  if [[ "$official_setup_has_vision" -eq 0 ]]; then
    choose_fallback_target_model
    print
    print -r -- "接下来仍会进入 DeepSeek 官方旧版 setup。"
    print -r -- "旧菜单可能只显示 1=Flash、2=Pro、9=Restore；请选择 1 或 2 并输入 API Key。"
    print -r -- "官方脚本完成后，Switcher 会补齐 Vision，并自动切到你上面选择的最终模型。"
  fi

  if ! /bin/bash "$temp_script"; then
    cleanup_temp_script
    clear_temp_traps
    die "DeepSeek 官方 setup 执行失败。"
  fi

  [[ -f "$CONFIG_PATH" ]] || die "DeepSeek setup 完成后仍未找到 config.toml。"
  [[ -f "$MODELS_PATH" ]] || die "DeepSeek setup 完成后仍未找到 models.json。"
  is_deepseek_config || \
    die "DeepSeek 官方 setup 已结束，但当前 config.toml 不是 DeepSeek 状态。请重新运行并选择 DeepSeek 模型。"

  if [[ "$official_setup_has_vision" -eq 0 ]]; then
    augment_deepseek_vision_catalog "$MODELS_PATH"
    validate_three_model_catalog "$MODELS_PATH"
    set_active_deepseek_model "$fallback_target_model"
    ok "DeepSeek 三模型兼容兜底完成：Flash / Pro / Vision"
  else
    validate_three_model_catalog "$MODELS_PATH"
  fi

  ok "DeepSeek 官方 Codex 配置已接入"

  cleanup_temp_script
  clear_temp_traps

  print
  /usr/bin/open -a Codex >/dev/null 2>&1 || true
  print -r -- "请在 Codex 中新建一个任务，确认 DeepSeek 可以正常回复。"
  print -r -- "确认后回到终端继续；如果不可用，请输入 n，脚本不会保存 DeepSeek Profile。"
  if ! confirm "DeepSeek 已在 Codex 中实际验证可用"; then
    die "未确认 DeepSeek 可用，未保存 DeepSeek Profile。"
  fi

  "$TARGET/setup.sh" save-deepseek --confirmed-working
  ok "DeepSeek Profile 已保存"
}

final_check() {
  print
  "$TARGET/setup.sh" check

  local missing
  missing="$("$TARGET/setup.sh" check | /usr/bin/grep '^MISSING ' || true)"
  [[ -z "$missing" ]] || die "初始化未完成，请根据上面的 MISSING 项处理。"

  print
  ok "初始化完成"
  print -r -- "固定运行目录：$TARGET"
  print -r -- "GPT 快捷指令：/bin/zsh \"\$HOME/.codex/switcher/bin/codex-switcher.sh\" gpt"
  print -r -- "DeepSeek 快捷指令：/bin/zsh \"\$HOME/.codex/switcher/bin/codex-switcher.sh\" deepseek"
  print -r -- "更换 Mac 后只要重新运行本初始化脚本，快捷指令路径无需修改。"
}

main() {
  [[ "$(uname -s)" == "Darwin" ]] || die "当前脚本仅支持 macOS。"

  require_command git
  require_command curl

  install_or_update_repo
  ensure_gpt_profile
  run_deepseek_official_setup
  final_check
}

if [[ "${CODEX_SWITCHER_BOOTSTRAP_SOURCE_ONLY:-0}" != "1" ]]; then
  main "$@"
fi
