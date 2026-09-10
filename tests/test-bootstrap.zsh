#!/bin/zsh

set -euo pipefail

readonly PROJECT_DIR="${0:A:h:h}"
readonly BOOTSTRAP="$PROJECT_DIR/bootstrap.sh"
readonly TEST_ROOT=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/codex-switcher-bootstrap-test.XXXXXX")
readonly TEST_HOME="$TEST_ROOT/home"
readonly TEST_CODEX_DIR="$TEST_HOME/.codex"
readonly TEST_SWITCHER_DIR="$TEST_CODEX_DIR/switcher"
readonly TEST_MODELS="$TEST_CODEX_DIR/models.json"
readonly TEST_CONFIG="$TEST_CODEX_DIR/config.toml"

cleanup() {
  /bin/rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

fail() {
  print -u2 -r -- "FAIL: $1"
  exit 1
}

[[ "$(uname -s)" == "Darwin" ]] || fail "该测试仅支持 macOS"
[[ -x /usr/bin/plutil ]] || fail "缺少 /usr/bin/plutil"
[[ -x /usr/libexec/PlistBuddy ]] || fail "缺少 /usr/libexec/PlistBuddy"

/bin/mkdir -p "$TEST_SWITCHER_DIR/backups"

{
  print -r -- '{'
  print -r -- '  "models": ['
  print -r -- '    {'
  print -r -- '      "slug": "deepseek-v4-flash",'
  print -r -- '      "display_name": "DeepSeek-V4-Flash",'
  print -r -- '      "description": "Latest frontier agentic coding model.",'
  print -r -- '      "input_modalities": ["text"],'
  print -r -- '      "supports_image_detail_original": false,'
  print -r -- '      "priority": 1,'
  print -r -- '      "minimal_client_version": "0.130.0",'
  print -r -- '      "marker_from_official_flash": "must-survive"'
  print -r -- '    },'
  print -r -- '    {'
  print -r -- '      "slug": "deepseek-v4-pro",'
  print -r -- '      "display_name": "DeepSeek-V4-Pro",'
  print -r -- '      "description": "Most capable frontier agentic coding model.",'
  print -r -- '      "input_modalities": ["text"],'
  print -r -- '      "supports_image_detail_original": false,'
  print -r -- '      "priority": 2'
  print -r -- '    }'
  print -r -- '  ]'
  print -r -- '}'
} > "$TEST_MODELS"

{
  print -r -- 'model = "deepseek-v4-flash"'
  print -r -- 'model_provider = "deepseek"'
  print -r -- ''
  print -r -- '[model_providers.deepseek]'
  print -r -- 'name = "deepseek"'
  print -r -- 'base_url = "https://api.deepseek.com/"'
  print -r -- 'wire_api = "responses"'
  print -r -- 'experimental_bearer_token = "test-only-key"'
  print -r -- ''
  print -r -- '[agents.example]'
  print -r -- 'model = "nested-model-must-survive"'
} > "$TEST_CONFIG"

/bin/chmod 600 "$TEST_MODELS" "$TEST_CONFIG"

export HOME="$TEST_HOME"
export CODEX_SWITCHER_BOOTSTRAP_SOURCE_ONLY=1
source "$BOOTSTRAP"

augment_deepseek_vision_catalog "$TEST_MODELS"
validate_three_model_catalog "$TEST_MODELS"

/usr/bin/plutil -convert xml1 "$TEST_MODELS" >/dev/null 2>&1
vision_index=2

[[ "$(/usr/libexec/PlistBuddy -c "Print :models:$vision_index:slug" "$TEST_MODELS")" == "deepseek-v4-flash-vision-exp" ]] || fail "Vision slug 错误"
[[ "$(/usr/libexec/PlistBuddy -c "Print :models:$vision_index:display_name" "$TEST_MODELS")" == "DeepSeek-V4-Flash-Vision" ]] || fail "Vision display_name 错误"
[[ "$(/usr/libexec/PlistBuddy -c "Print :models:$vision_index:input_modalities:0" "$TEST_MODELS")" == "text" ]] || fail "Vision text modality 缺失"
[[ "$(/usr/libexec/PlistBuddy -c "Print :models:$vision_index:input_modalities:1" "$TEST_MODELS")" == "image" ]] || fail "Vision image modality 缺失"
[[ "$(/usr/libexec/PlistBuddy -c "Print :models:$vision_index:supports_image_detail_original" "$TEST_MODELS")" == "true" ]] || fail "Vision image detail 标记错误"
[[ "$(/usr/libexec/PlistBuddy -c "Print :models:$vision_index:priority" "$TEST_MODELS")" == "3" ]] || fail "Vision priority 错误"
[[ "$(/usr/libexec/PlistBuddy -c "Print :models:$vision_index:minimal_client_version" "$TEST_MODELS")" == "0.144.0" ]] || fail "Vision minimum client version 错误"
[[ "$(/usr/libexec/PlistBuddy -c "Print :models:$vision_index:marker_from_official_flash" "$TEST_MODELS")" == "must-survive" ]] || fail "Vision 未继承官方 Flash 其余字段"

/usr/bin/plutil -convert json "$TEST_MODELS" >/dev/null 2>&1

set_active_deepseek_model "deepseek-v4-flash-vision-exp"

top_model=$(/usr/bin/awk '
  BEGIN { in_top = 1 }
  in_top && /^[[:space:]]*\[/ { exit }
  in_top && /^[[:space:]]*model[[:space:]]*=/ {
    print
    exit
  }
' "$TEST_CONFIG")

[[ "$top_model" == 'model = "deepseek-v4-flash-vision-exp"' ]] || fail "顶层 model 未正确替换"
/usr/bin/grep -Fq 'model = "nested-model-must-survive"' "$TEST_CONFIG" || fail "嵌套 model 被误改"

backup_count=$(/usr/bin/find "$TEST_SWITCHER_DIR/backups" -type f -name 'bootstrap_config_*.toml' | /usr/bin/wc -l | /usr/bin/tr -d ' ')
[[ "$backup_count" == "1" ]] || fail "config 兼容修改前应生成 1 份备份"

/usr/bin/grep -R -Fq 'test-only-key' "$TEST_SWITCHER_DIR/backups" || fail "备份未保留原 config（测试夹具）"

print -r -- "PASS: stale CDN catalog 补齐 Vision、字段继承、原子配置目标切换与备份均通过。"
