#!/bin/bash
# analyse-logs.sh: Analyse the generated logs by severity,by hour and on CRITICAL entries
# Author: Manish Kumar
# Created: 2026-10-07
# Purpose: Read the log from /logs/cloudbyte-app.log input file and after analyse write it to /logs/reports/ 
# Usage: sudo bash analyse-logs.sh
#

LOG_FILE="/logs/cloudbyte-app.log"
OUTPUT_FILE="/logs/reports/log-analysis-$(date +%F_%H-%M-%S).txt"

set -eo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Error: analyse-logs.sh must be run as root."
    echo "Hint: sudo bash $0"
    exit 1
fi

{
echo "======== Count By Severity =========="
awk '{print $3}' "$LOG_FILE" | sort | uniq -c | sort -rn
echo

echo "========= Count By Busiest Hours =========="
awk '{ print $2 }' "$LOG_FILE" | cut -c1-2 | sort | uniq -c | sort -rn | sed -n 1p
echo 

echo "======== CRITICAL Entries ============"
grep "\[CRITICAL\]" "$LOG_FILE" || echo "(none)"
echo
} | tee "$OUTPUT_FILE"
