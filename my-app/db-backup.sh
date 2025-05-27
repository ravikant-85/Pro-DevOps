#!/bin/bash
set -e
set -o pipefail

BACKUP_ROOT="/backup"
WEBHOOK_URL="https://swaraatech.webhook.office.com/webhookb2/498caa4a-77c1-429c-b934-c205a75e414f@9867cd77-685e-45c7-81a2-8f893300a12b/IncomingWebhook/4f70ad504da4478586415c3c2803ee56/3e3db847-bbc9-4af3-94fb-9de9e2461665/V2qg6ICMUI0C3_V-73e8u8ej28aOiqrGzxfPB3hVqDd6A1"
MYSQL_USER="root"
DATE=$(date +%F)
RETENTION_DAYS=4

IP_ADDRESS=$(hostname -I | awk '{print $1}')
SERVER_NAME=$(hostname)

STATUS="success"
MSG="Backup completed successfully."

function send_webhook() {
  curl -X POST -H "Content-Type: application/json" -d "{\"status\":\"$STATUS\",\"date\":\"$DATE\",\"message\":\"$MSG\",\"ip\":\"$IP_ADDRESS\",\"server\":\"$SERVER_NAME\"}" $WEBHOOK_URL
}

function on_exit() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    STATUS="failure"
    MSG="Backup failed or interrupted."
  fi
  send_webhook
}
trap on_exit EXIT INT TERM

mkdir -p "$BACKUP_ROOT/$DATE"

DATABASES=$(mysql -u$MYSQL_USER -e "SHOW DATABASES;" -s --skip-column-names | grep -Ev "(information_schema|performance_schema|mysql|sys)")

for DB in $DATABASES; do
  DB_FOLDER="$BACKUP_ROOT/$DATE/${DB}"
  mkdir -p "$DB_FOLDER"

  # Dump with retry function
  if ! ( mysqldump -u$MYSQL_USER --single-transaction --quick --max-allowed-packet=1G --skip-triggers "$DB" | gzip > "$DB_FOLDER/${DB}.sql.gz" ); then
    STATUS="failure"
    MSG="Backup failed for database: $DB"
    exit 1
  fi
done

if [ "$STATUS" = "success" ]; then
  find "$BACKUP_ROOT" -maxdepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;
fi

exit 0

