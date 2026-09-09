#!/bin/zsh

set -euo pipefail

readonly PROJECT_DIR="${0:A:h:h}"
readonly SETUP="$PROJECT_DIR/setup.sh"
readonly TEST_ROOT=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/codex-switcher-setup-test.XXXXXX")
readonly TEST_HOME="$TEST_ROOT/home"
readonly TEST_CODEX_DIR="$TEST_HOME/.codex"

cleanup() {
  /bin/rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

fail() {
  print -u2 -r -- "FAIL: $1"
  exit 1
}

run_setup() {
  /usr/bin/env HOME="$TEST_HOME" "$SETUP" "$@" >/dev/null
}

/bin/mkdir -p "$TEST_CODEX_DIR"
print -r -- 'provider = "deepseek"' > "$TEST_CODEX_DIR/config.toml"
print -r -- '{"models":["deepseek-v4-flash"]}' > "$TEST_CODEX_DIR/models.json"

run_setup install
run_setup save-deepseek --confirmed-working

print -r -- 'provider = "gpt"' > "$TEST_CODEX_DIR/config.toml"
run_setup save-gpt --confirmed-working

/usr/bin/cmp -s "$TEST_CODEX_DIR/switcher/profiles/gpt.toml" "$TEST_CODEX_DIR/config.toml" || \
  fail "GPT Profile 捕获错误"
[[ -x "$TEST_CODEX_DIR/switcher/bin/codex-switch.sh" ]] || fail "安装后的脚本不可执行"

for private_path in \
  "$TEST_CODEX_DIR/switcher/profiles/gpt.toml" \
  "$TEST_CODEX_DIR/switcher/profiles/deepseek.toml" \
  "$TEST_CODEX_DIR/switcher/profiles/models.deepseek.json"; do
  mode=$(/usr/bin/stat -f '%Lp' "$private_path")
  [[ "$mode" == "600" ]] || fail "$private_path 权限应为 600，实际为 $mode"
done

if /usr/bin/env HOME="$TEST_HOME" "$SETUP" save-gpt >/dev/null 2>&1; then
  fail "未确认可用时不应保存 GPT Profile"
fi

print -r -- "PASS: 安装、Profile 捕获、权限和人工确认保护均通过。"
