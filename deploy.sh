#!/bin/bash
set -e

# Load .env nếu chạy local (CI/CD dùng secrets)
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Kiểm tra biến bắt buộc
: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN chưa được set}"
: "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID chưa được set}"

# Generate alertmanager.yml từ template
envsubst '${TELEGRAM_BOT_TOKEN} ${TELEGRAM_CHAT_ID}' \
  < alertmanager/alertmanager.yml.template \
  > alertmanager/alertmanager.yml
echo "Generated alertmanager/alertmanager.yml"

# Cập nhật containers
docker compose up -d --remove-orphans
echo "Containers updated"

# Lấy commit đã deploy lần trước (lưu ngoài git để không bị ghi đè)
DEPLOYED_FILE="/tmp/abp-monitor-deployed-commit"
PREV=$(cat "$DEPLOYED_FILE" 2>/dev/null || echo "")
CURRENT=$(git rev-parse HEAD)

# Restart Grafana chỉ khi provisioning thay đổi (hoặc lần đầu deploy)
if [ -z "$PREV" ] || git diff --name-only "$PREV" "$CURRENT" -- grafana/provisioning/ | grep -q .; then
  docker restart grafana
  echo "Grafana restarted (provisioning changed)"
fi

# Reload Prometheus chỉ khi config/rules thay đổi (hoặc lần đầu deploy)
if [ -z "$PREV" ] || git diff --name-only "$PREV" "$CURRENT" -- prometheus/ | grep -q .; then
  sleep 3
  curl -s -X POST http://localhost:9901/-/reload && echo "Prometheus reloaded"
fi

# Lưu commit hiện tại làm baseline cho lần sau
echo "$CURRENT" > "$DEPLOYED_FILE"
echo "Deploy done: $CURRENT"
