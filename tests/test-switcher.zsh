#!/bin/zsh

set -euo pipefail

readonly PROJECT_DIR="${0:A:h:h}"
readonly SWITCHER="$PROJECT_DIR/bin/codex-switcher.sh"
readonly TEST_ROOT=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/codex-switcher-test.XXXXXX")
readonly TEST_CODEX_DIR="$TEST_ROOT/.codex"
readonly PROFILE_DIR="$TEST_CODEX_DIR/switcher/profiles"
readonly BACKUP_DIR="$TEST_CODEX_DIR/switcher/backups"

cleanup() {
  /bin/rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

fail() {
  print -u2 -r -- "FAIL: $1"
  exit 1
}

assert_file_equals() {
  /usr/bin/cmp -s "$1" "$2" || fail "$3"
}

run_switch() {
  /usr/bin/env \
    CODEX_SWITCHER_TEST_MODE=1 \
    CODEX_SWITCHER_TEST_CODEX_DIR="$TEST_CODEX_DIR" \
    "$SWITCHER" "$1" >/dev/null
}

/bin/mkdir -p "$PROFILE_DIR" "$BACKUP_DIR"
print -r -- 'provider = "current"' > "$TEST_CODEX_DIR/config.toml"
print -r -- 'provider = "current"' > "$TEST_ROOT/expected-initial-config.toml"
print -r -- 'provider = "gpt"' > "$PROFILE_DIR/gpt.toml"
print -r -- 'provider = "deepseek"' > "$PROFILE_DIR/deepseek.toml"
print -r -- '{"models":["deepseek-v4-flash"]}' > "$PROFILE_DIR/models.deepseek.json"
/bin/chmod 600 "$TEST_CODEX_DIR/config.toml" "$PROFILE_DIR"/*

success_output=$(/usr/bin/env \
  CODEX_SWITCHER_TEST_MODE=1 \
  CODEX_SWITCHER_TEST_CODEX_DIR="$TEST_CODEX_DIR" \
  "$SWITCHER" deepseek 2>&1)
[[ -z "$success_output" ]] || fail "成功切换应完全静默，实际输出：$success_output"
assert_file_equals "$TEST_CODEX_DIR/config.toml" "$PROFILE_DIR/deepseek.toml" "DeepSeek 配置未正确安装"
assert_file_equals "$TEST_CODEX_DIR/models.json" "$PROFILE_DIR/models.deepseek.json" "DeepSeek models 未正确安装"
[[ "$(<"$TEST_CODEX_DIR/switcher/state")" == "deepseek" ]] || fail "DeepSeek 状态错误"
initial_backups=("$BACKUP_DIR"/config_*.toml(N))
(( ${#initial_backups} == 1 )) || fail "首次切换应创建一份备份"
assert_file_equals "${initial_backups[1]}" "$TEST_ROOT/expected-initial-config.toml" "首次备份内容错误"

run_switch codex
assert_file_equals "$TEST_CODEX_DIR/config.toml" "$PROFILE_DIR/gpt.toml" "GPT 配置未正确安装"
[[ "$(<"$TEST_CODEX_DIR/switcher/state")" == "codex" ]] || fail "GPT 状态错误"

for iteration in {1..20}; do
  if (( iteration % 2 == 1 )); then
    run_switch deepseek
  else
    run_switch codex
  fi
done

backups=("$BACKUP_DIR"/config_*.toml(N))
(( ${#backups} == 20 )) || fail "备份轮转后应保留 20 份，实际为 ${#backups}"

/bin/mv "$PROFILE_DIR/models.deepseek.json" "$PROFILE_DIR/models.deepseek.json.hidden"
before_hash=$(/usr/bin/shasum -a 256 "$TEST_CODEX_DIR/config.toml")
if error_output=$(run_switch deepseek 2>&1); then
  fail "缺少 models 快照时切换不应成功"
fi
[[ -n "$error_output" ]] || fail "失败切换必须保留终端错误输出"
after_hash=$(/usr/bin/shasum -a 256 "$TEST_CODEX_DIR/config.toml")
[[ "$before_hash" == "$after_hash" ]] || fail "预检失败后 config.toml 被修改"
/bin/mv "$PROFILE_DIR/models.deepseek.json.hidden" "$PROFILE_DIR/models.deepseek.json"

/bin/mv "$TEST_CODEX_DIR/models.json" "$TEST_CODEX_DIR/models.json.saved"
/bin/mkdir "$TEST_CODEX_DIR/models.json"
before_hash=$(/usr/bin/shasum -a 256 "$TEST_CODEX_DIR/config.toml")
if run_switch deepseek 2>/dev/null; then
  fail "models.json 是目录时切换不应成功"
fi
after_hash=$(/usr/bin/shasum -a 256 "$TEST_CODEX_DIR/config.toml")
[[ "$before_hash" == "$after_hash" ]] || fail "不安全的 models.json 目标导致配置被修改"
/bin/rmdir "$TEST_CODEX_DIR/models.json"
/bin/mv "$TEST_CODEX_DIR/models.json.saved" "$TEST_CODEX_DIR/models.json"

print -r -- 'provider = "gpt"' > "$TEST_CODEX_DIR/config.toml"
if /usr/bin/env \
  CODEX_SWITCHER_TEST_MODE=1 \
  CODEX_SWITCHER_TEST_CODEX_DIR="$TEST_CODEX_DIR" \
  CODEX_SWITCHER_TEST_ABORT_BEFORE_CONFIG=1 \
  "$SWITCHER" deepseek >/dev/null 2>&1; then
  fail "模拟中断不应返回成功"
fi
assert_file_equals "$TEST_CODEX_DIR/config.toml" "$PROFILE_DIR/gpt.toml" "模拟中断后当前配置不安全"

config_mode=$(/usr/bin/stat -f '%Lp' "$TEST_CODEX_DIR/config.toml")
[[ "$config_mode" == "600" ]] || fail "config.toml 权限应为 600，实际为 $config_mode"

print -r -- "PASS: 静默成功、可见错误、双向切换、20 次连续切换、备份轮转、预检保护和中断安全均通过。"
