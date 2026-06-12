#!/bin/bash
set -e

# Load .env nếu chạy local (CI/CD dùng secrets nên không cần)
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

docker compose up -d --remove-orphans

# Reload Prometheus để áp dụng rules mới (cần --web.enable-lifecycle)
sleep 5
curl -s -X POST http://localhost:9901/-/reload && echo "Prometheus reloaded"
