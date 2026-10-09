#!/bin/bash
# system-health.sh: snapshot CloudByte server health into a timestamped report.
# Author:  Manish Kumar
# Created: 08-10-2026
# Purpose: Capture uptime/load, memory, disk, the top processes, service status,
#          and logged-in users; format with printf; write to /logs/health-reports/
#          and print it. (Alerts and archiving added in later steps.)
# Usage:   sudo bash system-health.sh

set -eo pipefail

# --- Sudo guard -----------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo "Error: system-health.sh must be run as root (it writes to /logs)."
    echo "Hint: sudo bash $0"
    exit 1
fi

# --- Config ---------------------------------------------------------------
REPORT_DIR=/logs/health-reports
ARCHIVE_DIR="$REPORT_DIR/archive"
mkdir -p "$ARCHIVE_DIR"
REPORT="$REPORT_DIR/health-$(date +%F-%H%M%S).txt"
SERVICES="crond sshd"
DISK_THRESHOLD=80

{

	printf "=== CloudByte system health: %s ===\n" "$(date)"
	printf "Host: %s\n" "$(hostname)"
	printf "\n"

	printf '%s\n' "--- Uptime and load ---"
	uptime
	printf "\n"

	printf '%s\n' "--- Memory ---"
	free -h
	printf "\n"

	printf '%s\n' "--- Disk ---"
	df -h | awk 'NR ==1 || $1 == "/dev/nvme0n1p1"'
	printf "\n"

	printf '%s\n' "--- Top processes by CPU ---"
	ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 2
	printf "\n"

	printf '%s\n' "--- Services ---"
    	for svc in $SERVICES; do
        	printf '%-12s %s\n' "$svc" "$(systemctl is-active "$svc")"
    	done
    	printf '\n'

	printf '%s\n' "--- Logged-in users ---"
	who
	printf "\n"

	printf '%s\n' "--- Alerts ---"
	alert=0
	disk_use=$(df --output=pcent / | tail -1 | tr -d ' %')
	if [ "$disk_use" -gt "$DISK_THRESHOLD" ]; then
		printf "ALERT: disk usage is %s%% (threshold %s%%)\n" "$disk_use" "$DISK_THRESHOLD"
		alert=$((alert + 1))
	fi

	zombies=$(ps -eo stat= | grep -c '^Z' || true)
	if [ "$zombies" -gt 0 ]; then
		printf "ALERT: %s zombie process found\n" "$zombies"
		alert=$((alert + 1))
	fi

	for svc in $SERVICES; do
    	if ! systemctl is-active --quiet "$svc"; then
        	printf "ALERT: %s service is down\n" "$svc"
		alert=$((alert + 1))
		# this service is down: raise an alert for "$svc"
    	fi
	done

	if [ "$alert" -eq 0 ]; then
		printf "No alerts. All checks within thresholds.\n"
	fi


} | tee "$REPORT"

# --- Archive reports older than a week ------------------------------------
find "$REPORT_DIR" -maxdepth 1 -name 'health-*.txt' -mtime +7 -exec mv {} "$ARCHIVE_DIR"/ \;