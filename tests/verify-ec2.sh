#!/bin/bash
# verify-ec2.sh: CloudByte Section 6 self-check (runs on EC2)
# Author:  Manish Kumar
# Created: 06-10-2026
# Purpose: Test every Section 6 deliverable on the EC2 instance:
#          users, groups, directories, docs, scripts, cron, differences-log.
# Usage:   bash verify-ec2.sh

# REPO_DIR is the symmetric path used on both host and EC2.
# Override the default by exporting REPO_DIR before running.
REPO_DIR="${REPO_DIR:-$HOME/cloud-course/linux-project}"

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

# dir_check accepts a space-separated list of acceptable modes (e.g. "770 2770")
# so setgid-bit upgrades from Section 2 still pass on directories created with
# a base-mode-only chmod.
dir_check() {
    local path=$1 group=$2 modes=$3
    local g m
    g=$(sudo stat -c %G "$path" 2>/dev/null)
    m=$(sudo stat -c %a "$path" 2>/dev/null)
    if [ "$g" = "$group" ] && echo " $modes " | grep -q " $m "; then
        echo "✅ PASS: $path (group=$group, mode=$m)"
        PASS=$((PASS+1))
    else
        echo "❌ FAIL: $path (want group=$group mode=$modes, got group=$g mode=$m)"
        FAIL=$((FAIL+1))
    fi
}

# docs_check confirms a file in /shared/company-docs/ is owned root:admins
# at mode 664. Used for all three docs.
docs_check() {
    local path=$1
    local og
    og=$(sudo stat -c '%U:%G %a' "$path" 2>/dev/null)
    if [ "$og" = "root:admins 664" ]; then
        echo "✅ PASS: $path (root:admins, mode 664)"
        PASS=$((PASS+1))
    else
        echo "❌ FAIL: $path (want root:admins 664, got $og)"
        FAIL=$((FAIL+1))
    fi
}

echo "=== CloudByte Section 6 EC2 check ==="

# --- Groups -------------------------------------------------------------
for g in engineering marketing operations admins; do
    check "getent group $g" "Group '$g' exists"
done

# --- Users with primary team groups -------------------------------------
for u in alice bob carol dave; do
    check "id -nG $u | grep -qw engineering" "$u is in engineering"
done
for u in emma frank grace; do
    check "id -nG $u | grep -qw marketing" "$u is in marketing"
done
for u in henry iris jack; do
    check "id -nG $u | grep -qw operations" "$u is in operations"
done
for u in kate leo; do
    check "id -nG $u | grep -qw operations" "$u is in operations"
    check "id -nG $u | grep -qw admins"     "$u is in admins"
done

# --- /shared/ tree ------------------------------------------------------
dir_check /shared/engineering  engineering "2770"
dir_check /shared/marketing    marketing   "2770"
dir_check /shared/operations   operations  "2770"
dir_check /shared/company-docs admins      "775 2775"
dir_check /shared/backups      admins      "2770"
dir_check /logs/reports        admins      "775 2775"

# --- Docs in /shared/company-docs/ --------------------------------------
docs_check /shared/company-docs/server-setup-log.txt
docs_check /shared/company-docs/permissions-test-report.md
docs_check /shared/company-docs/differences-log.txt

# --- Scripts present and executable -------------------------------------
check "test -x \"$REPO_DIR/scripts/onboard-user.sh\"" \
      "onboard-user.sh exists and is executable"
check "test -x \"$REPO_DIR/scripts/backup-shared.sh\"" \
      "backup-shared.sh exists and is executable"
check "test -x \"$REPO_DIR/scripts/cleanup-backups.sh\"" \
      "cleanup-backups.sh exists and is executable"

# --- CSV present with 12+ data rows -------------------------------------
check "test -f \"$REPO_DIR/data/cloudbyte-users.csv\" && \
       [ \"\$(tail -n +2 \"$REPO_DIR/data/cloudbyte-users.csv\" | wc -l)\" -ge 12 ]" \
      "data/cloudbyte-users.csv has at least 12 data rows"

# --- verify-ec2.sh self-check -------------------------------------------
check "test -f \"$REPO_DIR/verify-ec2.sh\"" \
      "verify-ec2.sh exists at repo root (self-check)"

# --- Cron entries -------------------------------------------------------
check "sudo crontab -l 2>/dev/null | grep -q backup-shared.sh" \
      "Root crontab contains backup-shared.sh"
check "sudo crontab -l 2>/dev/null | grep -q cleanup-backups.sh" \
      "Root crontab contains cleanup-backups.sh"
check "sudo crontab -l 2>/dev/null | grep backup-shared.sh | grep -q /home/ec2-user/" \
      "Backup cron uses an EC2-absolute path"
check "sudo crontab -l 2>/dev/null | grep backup-shared.sh | grep -qE '>> .*\\.log 2>&1'" \
      "Backup cron redirects output to a log"

# --- Daemon -------------------------------------------------------------
check "systemctl is-active --quiet crond" \
      "crond is active"

# --- Active behaviour: cleanup removes an aged file ---------------------
# Manufacture an 8-day-old stub, run cleanup, confirm it's gone.
sudo touch -d "8 days ago" /shared/backups/old-test.tar.gz 2>/dev/null
sudo "$REPO_DIR/scripts/cleanup-backups.sh" > /dev/null 2>&1
check "! sudo test -f /shared/backups/old-test.tar.gz" \
      "cleanup-backups.sh removes an 8-day-old archive"

# --- Differences log exists and is non-empty ----------------------------
check "sudo test -s /shared/company-docs/differences-log.txt" \
      "/shared/company-docs/differences-log.txt exists and is non-empty"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]