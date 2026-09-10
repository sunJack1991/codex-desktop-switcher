#!/bin/zsh

set -euo pipefail

readonly PROJECT_DIR="${0:A:h:h}"
readonly BOOTSTRAP="$PROJECT_DIR/bootstrap.sh"
readonly OFFICIAL_URL="https://cdn.deepseek.com/api-docs/codex-deepseek-setup.sh"

fail() {
  print -u2 -r -- "FAIL: $1"
  exit 1
}

/bin/zsh -n "$BOOTSTRAP" || fail "bootstrap.sh zsh 语法检查失败"

/usr/bin/grep -Fq "readonly DEEPSEEK_SETUP_URL=\"$OFFICIAL_URL\"" "$BOOTSTRAP" || \
  fail "bootstrap 未固定使用指定 DeepSeek 官方 setup URL"

/usr/bin/grep -Fq '/usr/bin/curl -fsSL "$DEEPSEEK_SETUP_URL" -o "$temp_script"' "$BOOTSTRAP" || \
  fail "bootstrap 未从官方 URL 原样下载 setup"

/usr/bin/grep -Fq '/bin/bash "$temp_script"' "$BOOTSTRAP" || \
  fail "bootstrap 未直接执行下载后的官方 setup"

for forbidden in \
  'augment_deepseek_vision_catalog' \
  'fallback_target_model' \
  'REQUIRED_VISION_MODEL' \
  'PlistBuddy' \
  'plutil' \
  'set_active_deepseek_model' \
  'validate_three_model_catalog' \
  'backup-deepseek.stale' \
  'codex-deepseek-setup-en.sh'; do
  if /usr/bin/grep -Fq "$forbidden" "$BOOTSTRAP"; then
    fail "bootstrap 出现禁止的 DeepSeek 非官方修改逻辑：$forbidden"
  fi
done

print -r -- "PASS: bootstrap 仅下载并原样执行指定 DeepSeek 官方 setup，不包含模型 patch / 派生 / CDN 版本匹配逻辑。"
