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

# auth.json 不变式：Switcher 必须绝不创建 / 改写 / 删除 ~/.codex/auth.json。
# 用带内容的哨兵文件证明整个切换流程（含 DeepSeek 路径与中断路径）都不会触碰它。
print -r -- 'sentinel-auth-json-content' > "$TEST_CODEX_DIR/auth.json"
auth_json_before=$(/usr/bin/shasum -a 256 "$TEST_CODEX_DIR/auth.json")

success_output=$(/usr/bin/env \
  CODEX_SWITCHER_TEST_MODE=1 \
  CODEX_SWITCHER_TEST_CODEX_DIR="$TEST_CODEX_DIR" \
  "$SWITCHER" deepseek 2>&1)
[[ -z "$success_output" ]] || fail "成功切换应完全静默，实际输出：$success_output"
assert_file_equals "$TEST_CODEX_DIR/config.toml" "$PROFILE_DIR/deepseek.toml" "DeepSeek 配置未正确安装"
assert_file_equals "$TEST_CODEX_DIR/models.json" "$PROFILE_DIR/models.deepseek.json" "DeepSeek models 未正确安装"
[[ "$(<"$TEST_CODEX_DIR/switcher/state")" == "deepseek" ]] || fail "DeepSeek 状态错误"
auth_json_after_switch=$(/usr/bin/shasum -a 256 "$TEST_CODEX_DIR/auth.json")
[[ "$auth_json_before" == "$auth_json_after_switch" ]] || fail "切换流程修改了 auth.json"
initial_backups=("$BACKUP_DIR"/config_*.toml(N))
(( ${#initial_backups} == 1 )) || fail "首次切换应创建一份备份"
assert_file_equals "${initial_backups[1]}" "$TEST_ROOT/expected-initial-config.toml" "首次备份内容错误"

run_switch gpt
assert_file_equals "$TEST_CODEX_DIR/config.toml" "$PROFILE_DIR/gpt.toml" "GPT 配置未正确安装"
[[ ! -e "$TEST_CODEX_DIR/models.json" ]] || fail "Legacy GPT 切回时应清理与 DeepSeek 快照完全一致的 models.json"
[[ "$(<"$TEST_CODEX_DIR/switcher/state")" == "gpt" ]] || fail "GPT 状态错误"
print -r -- "absent" > "$PROFILE_DIR/models.gpt.absent"
/bin/chmod 600 "$PROFILE_DIR/models.gpt.absent"

for iteration in {1..20}; do
  if (( iteration % 2 == 1 )); then
    run_switch deepseek
  else
    run_switch gpt
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

run_switch deepseek
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

/bin/rm -f -- "$PROFILE_DIR/models.gpt.absent"
print -r -- '{"models":["gpt-custom"]}' > "$PROFILE_DIR/models.gpt.json"
/bin/chmod 600 "$PROFILE_DIR/models.gpt.json"
run_switch gpt
assert_file_equals "$TEST_CODEX_DIR/models.json" "$PROFILE_DIR/models.gpt.json" "GPT models 快照未正确恢复"
run_switch deepseek
run_switch gpt
assert_file_equals "$TEST_CODEX_DIR/models.json" "$PROFILE_DIR/models.gpt.json" "GPT models 快照双向切换后未保持"

config_mode=$(/usr/bin/stat -f '%Lp' "$TEST_CODEX_DIR/config.toml")
[[ "$config_mode" == "600" ]] || fail "config.toml 权限应为 600，实际为 $config_mode"

auth_json_after_all=$(/usr/bin/shasum -a 256 "$TEST_CODEX_DIR/auth.json")
[[ "$auth_json_before" == "$auth_json_after_all" ]] || fail "多次切换 / 中断路径后 auth.json 被修改"

print -r -- "PASS: 静默成功、可见错误、GPT models 基线恢复、Legacy 清理、双向切换、20 次连续切换、备份轮转、预检保护和中断安全均通过。"
