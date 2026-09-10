#!/bin/zsh
set -euo pipefail
umask 077

readonly REPO_URL="https://github.com/sunJack1991/codex-switcher.git"
readonly TARGET="$HOME/.codex/switcher"
readonly CODEX_DIR="$HOME/.codex"
readonly CONFIG_PATH="$CODEX_DIR/config.toml"
readonly MODELS_PATH="$CODEX_DIR/models.json"
readonly DEEPSEEK_SETUP_URL="https://cdn.deepseek.com/api-docs/codex-deepseek-setup.sh"

temp_script=""

ok() { print -r -- "✅ $*"; }
info() { print -r -- "→ $*"; }
die() { print -u2 -r -- "❌ $*"; exit 1; }

confirm() {
  local prompt="$1"
  local answer
  read -r "answer?$prompt [y/N]: "
  [[ "$answer" == [yY] ]]
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
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

download_official_deepseek_setup() {
  info "从 DeepSeek 官方 CDN 下载 Codex setup（原样执行，不修改）…"
  if ! /usr/bin/curl -fsSL "$DEEPSEEK_SETUP_URL" -o "$temp_script"; then
    print -u2 -r -- "❌ DeepSeek 官方 setup 下载失败：$DEEPSEEK_SETUP_URL"
    return 1
  fi
  [[ -s "$temp_script" ]] || {
    print -u2 -r -- "❌ DeepSeek 官方 setup 下载结果为空。"
    return 1
  }
  ok "DeepSeek 官方 setup 已下载"
  info "官方地址：$DEEPSEEK_SETUP_URL"
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
    print -u2 -r -- "当前 config.toml 已是 DeepSeek 状态，无法安全创建 GPT Profile。"
    print -u2 -r -- "请先运行 DeepSeek 官方命令并使用官方 Restore 选项恢复 GPT："
    print -u2 -r -- "bash <(curl -fsSL $DEEPSEEK_SETUP_URL)"
    die "恢复 GPT 后重新运行初始化。"
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
  print -r -- "模型菜单、API Key、config.toml、models.json 全部由 DeepSeek 官方脚本处理。"
  print -r -- "codex-switcher 不检测模型版本、不补模型、不修改官方生成内容。"

  if ! download_official_deepseek_setup; then
    cleanup_temp_script
    clear_temp_traps
    die "DeepSeek 官方 setup 下载失败。"
  fi

  if ! /bin/bash "$temp_script"; then
    cleanup_temp_script
    clear_temp_traps
    print -u2 -r -- "可直接运行 DeepSeek 官方命令复现："
    print -u2 -r -- "bash <(curl -fsSL $DEEPSEEK_SETUP_URL)"
    die "DeepSeek 官方 setup 执行失败；Switcher 未修改官方生成内容。"
  fi

  [[ -f "$CONFIG_PATH" ]] || die "DeepSeek 官方 setup 完成后仍未找到 config.toml。"
  [[ -f "$MODELS_PATH" ]] || die "DeepSeek 官方 setup 完成后仍未找到 models.json。"
  is_deepseek_config || \
    die "DeepSeek 官方 setup 已结束，但当前 config.toml 不是 DeepSeek 状态。请重新运行官方 setup 并选择 DeepSeek 模型。"

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
  ok "DeepSeek Profile 已按官方生成结果原样保存"
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

main "$@"
