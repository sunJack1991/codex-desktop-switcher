#!/bin/zsh
set -euo pipefail

readonly PROJECT_DIR="${0:A:h:h}"
readonly UNINSTALL="$PROJECT_DIR/uninstall.sh"
readonly TEST_ROOT=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/codex-switcher-uninstall-test.XXXXXX")

cleanup() { /bin/rm -rf -- "$TEST_ROOT"; }
trap cleanup EXIT HUP INT TERM
fail() { print -u2 -r -- "FAIL: $1"; exit 1; }

run_uninstall() {
  local test_home="$1"
  /usr/bin/env HOME="$test_home" CODEX_SWITCHER_TEST_MODE=1 /bin/zsh "$UNINSTALL" >/dev/null
}

home1="$TEST_ROOT/home1"
codex1="$home1/.codex"
profiles1="$codex1/switcher/profiles"
/bin/mkdir -p "$profiles1"
print -r -- 'model_provider = "deepseek"' > "$codex1/config.toml"
print -r -- 'model = "gpt-5.6-sol"' > "$profiles1/gpt.toml"
print -r -- 'model_provider = "deepseek"' > "$profiles1/deepseek.toml"
print -r -- '{"models":["deepseek-v4-flash"]}' > "$profiles1/models.deepseek.json"
/bin/cp "$profiles1/models.deepseek.json" "$codex1/models.json"
print -r -- "absent" > "$profiles1/models.gpt.absent"
print -r -- "sentinel-auth" > "$codex1/auth.json"
print -r -- 'model = "gpt-5.6-sol"' > "$TEST_ROOT/expected-gpt.toml"
auth1=$(/usr/bin/shasum -a 256 "$codex1/auth.json")
run_uninstall "$home1"
[[ ! -e "$codex1/switcher" ]] || fail "卸载后 switcher 目录仍存在"
/usr/bin/cmp -s "$codex1/config.toml" "$TEST_ROOT/expected-gpt.toml" || fail "卸载未恢复 GPT config.toml"
[[ ! -e "$codex1/models.json" ]] || fail "卸载未删除可确认的 DeepSeek models.json"
[[ "$auth1" == "$(/usr/bin/shasum -a 256 "$codex1/auth.json")" ]] || fail "卸载修改了 auth.json"

home2="$TEST_ROOT/home2"
codex2="$home2/.codex"
profiles2="$codex2/switcher/profiles"
/bin/mkdir -p "$profiles2"
print -r -- 'model = "gpt-5.6-sol"' > "$codex2/config.toml"
print -r -- 'model = "gpt-5.6-sol"' > "$profiles2/gpt.toml"
print -r -- 'model_provider = "deepseek"' > "$profiles2/deepseek.toml"
print -r -- '{"models":["deepseek-v4-flash"]}' > "$profiles2/models.deepseek.json"
print -r -- '{"models":["user-custom"]}' > "$codex2/models.json"
/bin/cp "$codex2/config.toml" "$TEST_ROOT/expected-gpt-config.toml"
/bin/cp "$codex2/models.json" "$TEST_ROOT/expected-user-models.json"
run_uninstall "$home2"
[[ ! -e "$codex2/switcher" ]] || fail "GPT 态卸载后 switcher 目录仍存在"
/usr/bin/cmp -s "$codex2/config.toml" "$TEST_ROOT/expected-gpt-config.toml" || fail "GPT 态卸载不应覆盖现有 config.toml"
/usr/bin/cmp -s "$codex2/models.json" "$TEST_ROOT/expected-user-models.json" || fail "卸载误删或覆盖未知 models.json"

print -r -- "PASS: 卸载可恢复 GPT、清理已确认 DeepSeek models，并保留 auth.json 与未知 models.json。"
