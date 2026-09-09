#!/bin/zsh
set -euo pipefail

# Codex Desktop Switcher — bootstrap installer / updater
# Target is always: $HOME/.codex/switcher
#
# Usage A — one command, explicit repo URL:
#   /bin/zsh install.sh --repo https://github.com/OWNER/REPO.git
#
# Usage B — executed from an already-cloned repo:
#   ./install.sh

TARGET="$HOME/.codex/switcher"
REPO_URL="${CODEX_SWITCHER_REPO_URL:-}"

usage() {
  cat <<'TXT'
Usage:
  install.sh [--repo <git-url>]

Examples:
  ./install.sh
  ./install.sh --repo https://github.com/OWNER/REPO.git

Optional environment variable:
  CODEX_SWITCHER_REPO_URL=https://github.com/OWNER/REPO.git
TXT
}

die() {
  print -u2 -r -- "❌ $*"
  exit 1
}

ok() {
  print -r -- "✅ $*"
}

while (( $# > 0 )); do
  case "$1" in
    --repo)
      (( $# >= 2 )) || die "--repo 缺少 Git URL。"
      REPO_URL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "未知参数：$1"
      ;;
  esac
done

command -v git >/dev/null 2>&1 || die "未找到 git。请先安装 Apple Command Line Tools。"

SELF_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"

# Case 1: installer is already inside the canonical checkout.
if [[ -n "$SELF_DIR" && "$SELF_DIR" == "$TARGET" && -d "$TARGET/.git" ]]; then
  ok "已位于标准目录：$TARGET"
  exec "$TARGET/setup.sh" install
fi

# Case 2: target is already installed. Fast-forward only, never overwrite local state.
if [[ -d "$TARGET/.git" ]]; then
  print -r -- "→ 已检测到现有安装，更新 Git…"
  /usr/bin/git -C "$TARGET" pull --ff-only || die "git pull 失败；未修改本机 Profile。"
  exec "$TARGET/setup.sh" install
fi

# Refuse to overwrite an unrelated / non-git directory.
if [[ -e "$TARGET" ]]; then
  die "$TARGET 已存在但不是 Git 仓库。为避免覆盖本机文件，请先人工检查该目录。"
fi

[[ -n "$REPO_URL" ]] || \
  die "首次安装需要 Git URL。请使用：install.sh --repo <YOUR_GIT_REPO_URL>"

/bin/mkdir -p "$HOME/.codex"

print -r -- "→ Clone: $REPO_URL"
print -r -- "→ Target: $TARGET"
/usr/bin/git clone "$REPO_URL" "$TARGET" || die "git clone 失败。"

/bin/chmod +x "$TARGET/setup.sh" "$TARGET/install.sh" "$TARGET/bin/"*.sh 2>/dev/null || true

exec "$TARGET/setup.sh" install
