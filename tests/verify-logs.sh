#!/bin/bash
# verify-logs.sh: CloudByte Section 7 self-check (runs on EC2).
# Author:  Manish Kumar
# Created: 08-10-2026
# Purpose: Test the log-analysis deliverables: both scripts present and
#          runnable, a generated log carrying every severity, a report with all
#          three sections, and the hourly cron entry.
# Usage:   bash verify-logs.sh

REPO_DIR="${REPO_DIR:-$HOME/cloud-course/linux-project}"
LOG=/var/log/cloudbyte-loganalysis.log

PASS=0
FAIL=0

check() {
    if eval "$1" > /dev/null 2>&1; then
        echo "✅ PASS: $2"
        PASS=$((PASS+1))
    else
        echo "❌ FAIL: $2"
        FAIL=$((FAIL+1))
    fi
}

echo "=== CloudByte Section 7 log-analysis check ==="

# --- Scripts present and executable -------------------------------------
check "test -x \"$REPO_DIR/scripts/log-generator.sh\"" \
      "log-generator.sh exists and is executable"
check "test -x \"$REPO_DIR/scripts/analyse-logs.sh\"" \
      "analyse-logs.sh exists and is executable"

# --- A log was generated, carrying every severity -----------------------
check "sudo test -s $LOG" "$LOG exists and is non-empty"
for lvl in INFO WARN ERROR CRITICAL; do
    check "sudo grep -q '\\[$lvl\\]' $LOG" "log contains $lvl entries"
done

# --- A report exists with all three sections ----------------------------
REPORT=$(sudo ls -1t /logs/reports/log-analysis-*.txt 2>/dev/null | head -1)
check "test -n \"$REPORT\"" "a log-analysis report exists in /logs/reports/"
check "sudo grep -Eq '[0-9]+[[:space:]]+\[?(INFO|WARN|ERROR|CRITICAL)\]?' \"$REPORT\"" \
      "report counts entries by severity"
check "sudo grep -iq 'hour' \"$REPORT\""     "report names the busiest hour"
check "sudo grep -iq 'critical' \"$REPORT\"" "report covers CRITICAL entries"

# --- Cron entry ---------------------------------------------------------
check "sudo crontab -l 2>/dev/null | grep -q analyse-logs.sh" \
      "root crontab contains analyse-logs.sh"
check "sudo crontab -l 2>/dev/null | grep analyse-logs.sh | grep -q /home/ec2-user/" \
      "analysis cron uses an EC2-absolute path"

# --- Self-check ---------------------------------------------------------
check "test -f \"$REPO_DIR/verify-logs.sh\"" \
      "verify-logs.sh exists at repo root (self-check)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
