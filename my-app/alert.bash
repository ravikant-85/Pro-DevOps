* * * * * bash /root/scripts/alert.bash
root@Database-server-1:~# cat scripts/alert.bash
#!/bin/bash
#* * * * * bash /root/scripts/alert.bash

# Webhook URL
WEBHOOK_URL="https://swaraatech.webhook.office.com/webhookb2/498caa4a-77c1-429c-b934-c205a75e414f@9867cd77-685e-45c7-81a2-8f893300a12b/IncomingWebhook/32b315979045461b8399ed4ecc3f9dd8/3e3db847-bbc9-4af3-94fb-9de9e2461665/V2EwVhHUT4y7gS3q0xlEsz_GBhtPbV34knwJiUDZcuPQM1"

# Get hostname and public IP
HOSTNAME=$(hostname)
PUBLIC_IP=$(curl -s ifconfig.me)

# Function to send alerts with hostname and IP
send_alert() {
    local message="$1"
    curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"${HOSTNAME} (${PUBLIC_IP}): ${message}\"}" $WEBHOOK_URL
}

# Check Disk Space
disk_usage=$(df / | awk 'NR==2{print $(NF-1)}' | sed 's/%//')
if [ "$disk_usage" -ge 90 ]; then
    send_alert "Disk space alert: More than 90% used."
fi

# Check Load Average
load_average=$(uptime | awk -F 'load average:' '{ print $2 }' | cut -d, -f1 | xargs)
if (( $(echo "$load_average >= 10" | bc -l) )); then
    send_alert "Load average alert: Current load is $load_average."
fi

# Check Disk I/O using iostat
disk_io_read=$(iostat -d | awk '/^sda/{print $3}') # kB_read/s for device sda
disk_io_write=$(iostat -d | awk '/^sda/{print $4}') # kB_wrtn/s for device sda

# Convert kB/s to MB/s
disk_io_read_mb=$(echo "$disk_io_read / 1024" | bc -l)
disk_io_write_mb=$(echo "$disk_io_write / 1024" | bc -l)

# Check if read or write exceeds 20MB/s
if (( $(echo "$disk_io_read_mb > 20" | bc -l) )) || (( $(echo "$disk_io_write_mb > 20" | bc -l) )); then
    send_alert "Disk I/O alert: Read or Write I/O exceeds 20MB/s. Read: ${disk_io_read_mb}MB/s, Write: ${disk_io_write_mb}MB/s"
fi

# Check Connections
total_connections=$(netstat -an | grep -E ":80|:443|:3306" | wc -l)
if [ "$total_connections" -gt 19000 ]; then
    send_alert "Connection alert: More than 19000 connections on ports 80, 443, 3306."
fi

