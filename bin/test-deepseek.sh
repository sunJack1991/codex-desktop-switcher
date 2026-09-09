#!/bin/zsh
set -euo pipefail

# DeepSeek Responses API manual POC
# Usage:
#   test-deepseek.sh
#   test-deepseek.sh deepseek-v4-pro
#
# API Key is read via `read -s`, never echoed, never written to Git or logs.

MODEL="${1:-deepseek-v4-flash}"

case "$MODEL" in
  deepseek-v4-flash|deepseek-v4-pro)
    ;;
  *)
    print -u2 -r -- "❌ 不支持的测试模型：$MODEL"
    print -u2 -r -- "允许：deepseek-v4-flash | deepseek-v4-pro"
    exit 2
    ;;
esac

command -v curl >/dev/null 2>&1 || {
  print -u2 -r -- "❌ 未找到 curl。"
  exit 1
}

echo "DeepSeek API POC"
echo "Model: $MODEL"
echo "API Key 仅用于本次请求，不会写入 Git 或日志。"
read -r -s "API_KEY?请输入 DeepSeek API Key: "
echo

if [[ -z "${API_KEY:-}" ]]; then
  print -u2 -r -- "❌ API Key 为空。"
  exit 1
fi

BODY="$(/usr/bin/mktemp -t codex-switcher-deepseek)"
trap 'rm -f "$BODY"; unset API_KEY' EXIT INT TERM

PAYLOAD="{\"model\":\"$MODEL\",\"input\":\"Return exactly: DEEPSEEK_API_OK\"}"

if ! HTTP_CODE="$(
  /usr/bin/curl \
    --silent \
    --show-error \
    --connect-timeout 10 \
    --max-time 60 \
    --output "$BODY" \
    --write-out '%{http_code}' \
    --request POST \
    'https://api.deepseek.com/responses' \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer $API_KEY" \
    --data "$PAYLOAD"
)"; then
  unset API_KEY
  print -u2 -r -- "❌ DeepSeek API 网络请求失败。请检查网络、代理和 api.deepseek.com 可达性。"
  exit 1
fi

unset API_KEY

if [[ "$HTTP_CODE" != "200" ]]; then
  print -u2 -r -- "❌ DeepSeek API 测试失败，HTTP $HTTP_CODE"
  print -u2 -r -- "---- response (first 2000 bytes) ----"
  /usr/bin/head -c 2000 "$BODY" >&2 || true
  echo >&2
  exit 1
fi

if ! /usr/bin/grep -q 'DEEPSEEK_API_OK' "$BODY"; then
  print -u2 -r -- "⚠️ API 返回 HTTP 200，但未发现预期测试文本。"
  print -u2 -r -- "请人工检查返回内容："
  /usr/bin/head -c 4000 "$BODY" >&2 || true
  echo >&2
  exit 1
fi

echo "✅ DeepSeek Responses API POC PASS"
echo "✅ Model: $MODEL"
