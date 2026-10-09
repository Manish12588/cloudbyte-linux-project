#!/bin/bash
# verify-health.sh: CloudByte Section 8 self-check (runs on EC2).
# Author:  Manish Kumar
# Created: 08-10-2026
# Purpose: Test the system-health deliverables: the script is present and
#          runnable, a report exists carrying every section plus ALERTS, the
#          archive directory exists, and the */2 cron entry is in place.
# Usage:   bash verify-health.sh   (run system-health.sh at least once first)

REPO_DIR="${REPO_DIR:-$HOME/cloud-course/linux-project}"
REPORT_DIR=/logs/health-reports

PASS=0
FAIL=0

check() {
    if eval "$1" > /dev/null 2>&1; then
        echo "✅ PASS: $2"
        PASS=$((PASS + 1))
    else
        echo "❌ FAIL: $2"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== CloudByte Section 8 system-health check ==="

# --- Script present and executable --------------------------------------
check "test -x \"$REPO_DIR/scripts/system-health.sh\"" \
      "system-health.sh exists and is executable"

# --- A report exists carrying every section -----------------------------
REPORT=$(sudo ls -1t $REPORT_DIR/health-*.txt 2>/dev/null | head -1)
check "test -n \"$REPORT\"" "a health report exists in $REPORT_DIR/"
check "sudo grep -q 'Uptime and load' \"$REPORT\"" "report has the uptime/load section"
check "sudo grep -q 'Memory'          \"$REPORT\"" "report has the memory section"
check "sudo grep -q 'Disk'            \"$REPORT\"" "report has the disk section"
check "sudo grep -q 'Top processes'   \"$REPORT\"" "report has the top-processes section"
check "sudo grep -q 'Services'        \"$REPORT\"" "report has the services section"
check "sudo grep -q 'Logged-in users' \"$REPORT\"" "report has the logged-in-users section"
check "sudo grep -q 'Alerts'          \"$REPORT\"" "report has the ALERTS section"

# --- Archive directory --------------------------------------------------
check "sudo test -d $REPORT_DIR/archive" "archive directory exists"

# --- Cron entry ---------------------------------------------------------
check "sudo crontab -l 2>/dev/null | grep -q system-health.sh" \
      "root crontab contains system-health.sh"
check "sudo crontab -l 2>/dev/null | grep system-health.sh | grep -q '\\*/2'" \
      "health cron uses the */2 schedule"
check "sudo crontab -l 2>/dev/null | grep system-health.sh | grep -q /home/ec2-user/" \
      "health cron uses an EC2-absolute path"

# --- Self-check ---------------------------------------------------------
check "test -f \"$REPO_DIR/verify-health.sh\"" \
      "verify-health.sh exists at repo root (self-check)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
