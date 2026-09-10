#!/bin/zsh
set -euo pipefail
umask 077

readonly TARGET="$HOME/.codex/switcher"
readonly CODEX_DIR="$HOME/.codex"
readonly CONFIG_PATH="$CODEX_DIR/config.toml"
readonly MODELS_PATH="$CODEX_DIR/models.json"

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

is_deepseek_config() {
  [[ -f "$CONFIG_PATH" ]] &&     /usr/bin/grep -Eq '^[[:space:]]*model_provider[[:space:]]*=[[:space:]]*"deepseek"' "$CONFIG_PATH"
}

restore_gpt_if_possible() {
  local gpt_profile="$TARGET/profiles/gpt.toml"

  if [[ -f "$gpt_profile" ]]; then
    info "检测到 GPT Profile，卸载前恢复 GPT 配置…"
    /bin/cp -p "$gpt_profile" "$CONFIG_PATH" || die "恢复 GPT config.toml 失败。"
    /bin/chmod 600 "$CONFIG_PATH"
    ok "已恢复 GPT config.toml"
  elif is_deepseek_config; then
    print -u2 -r -- "⚠️ 当前 config.toml 是 DeepSeek 状态，但未找到 GPT Profile。"
    print -u2 -r -- "为避免误删后留下不可恢复状态，本次不会自动删除 config.toml。"
  fi
}

main() {
  [[ "$(uname -s)" == "Darwin" ]] || die "当前脚本仅支持 macOS。"

  print -r -- "将删除："
  print -r -- "  $TARGET"
  print -r -- "  $MODELS_PATH（DeepSeek models 快照，仅在当前为 DeepSeek 或存在本项目 DeepSeek Profile 时）"
  print -r -- ""
  print -r -- "不会删除："
  print -r -- "  $HOME/.codex/auth.json"
  print -r -- "  Codex / ChatGPT Desktop 应用"
  print -r -- "  其他与本项目无关的 ~/.codex 文件"
  print

  confirm "确认彻底删除 codex-switcher，并清理本项目 DeepSeek 接入文件" || {
    print -r -- "已取消。"
    exit 0
  }

  restore_gpt_if_possible

  if [[ -f "$TARGET/profiles/deepseek.toml" || -f "$TARGET/profiles/models.deepseek.json" || is_deepseek_config ]]; then
    if [[ -e "$MODELS_PATH" || -L "$MODELS_PATH" ]]; then
      [[ -f "$MODELS_PATH" && ! -L "$MODELS_PATH" ]] ||         die "拒绝删除非普通文件或符号链接：$MODELS_PATH"
      /bin/rm -f -- "$MODELS_PATH"
      ok "已删除 DeepSeek models.json"
    fi
  fi

  if [[ -e "$TARGET" || -L "$TARGET" ]]; then
    [[ -d "$TARGET" && ! -L "$TARGET" ]] || die "拒绝删除非目录或符号链接：$TARGET"
    /bin/rm -rf -- "$TARGET"
    ok "已删除 codex-switcher：$TARGET"
  else
    ok "codex-switcher 已不存在，无需删除"
  fi

  print
  ok "卸载完成"
  print -r -- "如需重装，重新运行 README 顶部的一键安装命令即可。"
}

main "$@"
