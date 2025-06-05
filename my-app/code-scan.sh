#!/bin/bash
# systemctl restart docker docker.socket ; sleep 5

# Set email details
email_recipient="devops@swaraa.dev"
email_subject="Wordfence Daily Scan Hranker-OVH-WebServer-1"
> /root/wordfence.csv

# Define output file
output_csv="/root/wordfence.csv"

# Webhook URLs
WEBHOOK_URL_SUCCESS="https://swaraatech.webhook.office.com/webhookb2/498caa4a-77c1-429c-b934-c205a75e414f@9867cd77-685e-45c7-81a2-8f893300a12b/IncomingWebhook/4f70ad504da4478586415c3c2803ee56/3e3db847-bbc9-4af3-94fb-9de9e2461665/V2qg6ICMUI0C3_V-73e8u8ej28aOiqrGzxfPB3hVqDd6A1"
WEBHOOK_URL_FAILURE="https://swaraatech.webhook.office.com/webhookb2/498caa4a-77c1-429c-b934-c205a75e414f@9867cd77-685e-45c7-81a2-8f893300a12b/IncomingWebhook/4f70ad504da4478586415c3c2803ee56/3e3db847-bbc9-4af3-94fb-9de9e2461665/V2qg6ICMUI0C3_V-73e8u8ej28aOiqrGzxfPB3hVqDd6A1"


# Get server IP and name
server_ip=$(hostname -I | awk '{print $1}')
server_name="Hranker-OVH-WebServer-1"

# Function to send webhook notification
send_webhook() {
  local status="$1"
  local message="$2"
  local csv_base64="$3"
  local url="$4"
  curl -X POST -H "Content-Type: application/json" -d "{
    \"title\": \"Wordfence Scan Status\",
    \"text\": \"$message\",
    \"summary\": \"Wordfence Scan Notification\",
    \"sections\": [
      {
        \"activityTitle\": \"Wordfence Scan Status\",
        \"activitySubtitle\": \"$message\",
        \"facts\": [
          {
            \"name\": \"Status\",
            \"value\": \"$status\"
          },
          {
            \"name\": \"Server Name\",
            \"value\": \"$server_name\"
          },
          {
            \"name\": \"Server IP\",
            \"value\": \"$server_ip\"
          },
          {
            \"name\": \"Details\",
            \"value\": \"$message\"
          },
          {
            \"name\": \"CSV Content (base64)\",
            \"value\": \"$csv_base64\"
          }
        ],
        \"markdown\": true
      }
    ]
  }" $url
}

# Execute the Wordfence scan
wordfence malware-scan -a --output-path "$output_csv" /var/www

# Check if the CSV has content
if [ $? -eq 0 ] && [ -s "$output_csv" ]; then
  # Read the CSV content and encode it in base64
  csv_base64=$(base64 "$output_csv")

  # Send the email with the CSV attached using sendmail
  (
    echo "Subject: $email_subject"
    echo "To: $email_recipient"
    echo "MIME-Version: 1.0"
    echo "Content-Type: multipart/mixed; boundary=\"fileboundary\""
    echo
    echo "--fileboundary"
    echo "Content-Type: text/plain"
    echo
    echo "Daily Wordfence scan report attached."
    echo
    echo "--fileboundary"
    echo "Content-Type: text/csv; name=\"wordfence_scan.csv\""
    echo "Content-Disposition: attachment; filename=\"wordfence_scan.csv\""
    echo "Content-Transfer-Encoding: base64"
    echo
    base64 "$output_csv"
    echo "--fileboundary--"
  ) | /usr/sbin/sendmail -t -oi

  # Send success webhook with base64 CSV content
  send_webhook "success" "Wordfence scan completed successfully. See attached report." "$csv_base64" $WEBHOOK_URL_SUCCESS
else
  # No content in CSV or scan failed - log this, but no email needed
  echo "Wordfence scan completed, no issues found or scan failed."

  # Send failure webhook
  send_webhook "failure" "Wordfence scan failed or no issues found." "" $WEBHOOK_URL_FAILURE
fi
