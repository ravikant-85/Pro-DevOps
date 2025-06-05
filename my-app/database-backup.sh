#!/bin/bash

BACKUP_DIR="/backup/databases"
DATE=$(date +%F)
WEBHOOK_URL="https://swaraatech.webhook.office.com/webhookb2/498caa4a-77c1-429c-b934-c205a75e414f@9867cd77-685e-45c7-81a2-8f893300a12b/IncomingWebhook/0652aea94ce94331a494d818386559c7/3e3db847-bbc9-4af3-94fb-9de9e2461665/V2fwWq5iD8yhm30vw5tXK6AGcwE3gQQ3D5oj23hupcwJ81"
SERVER_NAME="WebServer-1-OVH"
SERVER_IP=$(hostname -I | awk '{print $1}')

send_webhook() {
    local status="$1"
    local details="$2"
    curl -s -X POST -H "Content-Type: application/json" -d "{
        \"text\": \"[$status] Backup process\nDetails: $details\nServer: $SERVER_NAME ($SERVER_IP)\"
    }" "$WEBHOOK_URL" >/dev/null 2>&1
}

mkdir -p "$BACKUP_DIR"

ALL_SUCCESS=true
FAILED_DBS=()

DATABASES=$(sudo mysql -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")

for DB in $DATABASES; do
  FILE="$BACKUP_DIR/${DB}_${DATE}.sql.gz"

  if sudo mysqldump --single-transaction "$DB" | gzip > "$FILE"; then
    continue
  else
    ALL_SUCCESS=false
    FAILED_DBS+=("$DB")
  fi
done

if $ALL_SUCCESS; then
  find "$BACKUP_DIR" -type f -name "*.sql.gz" -mtime +0 -delete
  send_webhook "SUCCESS" "Backup successful for all databases."
else
  send_webhook "FAILURE" "Backup failed for databases: ${FAILED_DBS[*]}"
fi
