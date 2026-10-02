#!/bin/bash
# verify-backup.sh: CloudByte Section 4 self-check

# Adjust these two lines if your layout differs.
# Vagrant default:
#BACKUP_SCRIPT=/vagrant/scripts/backup-shared.sh
#CLEANUP_SCRIPT=/vagrant/scripts/cleanup-backups.sh
# Lima users: comment the two lines above and uncomment these.
BACKUP_SCRIPT=/host/scripts/backup-shared.sh
CLEANUP_SCRIPT=/host/scripts/cleanup-backups.sh

#SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#BACKUP_SCRIPT="$SCRIPT_DIR/backup-shared.sh"
#CLEANUP_SCRIPT="$SCRIPT_DIR/cleanup-backups.sh"

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

echo "=== CloudByte Section 4 check ==="

# --- /shared/backups directory ------------------------------------------
check "sudo test -d /shared/backups" \
      "/shared/backups exists"
check "[ \"\$(sudo stat -c '%U:%G %a' /shared/backups)\" = 'root:admins 2770' ]" \
      "/shared/backups is mode 2770 root:admins"

# --- backup-shared.sh ----------------------------------------------------
check "test -x \"$BACKUP_SCRIPT\"" \
      "backup-shared.sh exists and is executable"
check "head -n 30 \"$BACKUP_SCRIPT\" | grep -q 'set -eo pipefail'" \
      "backup-shared.sh enables strict mode (set -eo pipefail)"
check "grep -q 'trap cleanup' \"$BACKUP_SCRIPT\"" \
      "backup-shared.sh registers a cleanup trap"
check "grep -q -- '--exclude' \"$BACKUP_SCRIPT\" && grep -q 'BACKUP_DIR=/shared/backups' \"$BACKUP_SCRIPT\"" \
      "backup-shared.sh excludes BACKUP_DIR=/shared/backups"

# --- cleanup-backups.sh --------------------------------------------------
check "test -x \"$CLEANUP_SCRIPT\"" \
      "cleanup-backups.sh exists and is executable"
check "head -n 30 \"$CLEANUP_SCRIPT\" | grep -q 'set -eo pipefail'" \
      "cleanup-backups.sh enables strict mode (set -eo pipefail)"
check "grep -qE 'mtime \\+7|RETENTION_DAYS=7' \"$CLEANUP_SCRIPT\"" \
      "cleanup-backups.sh uses 7-day retention"
check "grep -q -- '--preview' \"$CLEANUP_SCRIPT\"" \
      "cleanup-backups.sh supports --preview"

# --- Latest archive contents --------------------------------------------
# Glob expansion runs under sudo because /shared/backups is mode 2770; without
# this, the unprivileged shell silently fails to expand the * .
LATEST=$(sudo bash -c 'ls -t /shared/backups/cloudbyte-shared-*.tar.gz 2>/dev/null | head -1')
check "[ -n \"$LATEST\" ] && sudo tar -tzf \"$LATEST\" | grep -q '^shared/engineering' && sudo tar -tzf \"$LATEST\" | grep -q '^shared/marketing' && sudo tar -tzf \"$LATEST\" | grep -q '^shared/operations'" \
      "Latest archive contains all team folders"
check "[ -n \"$LATEST\" ] && ! sudo tar -tzf \"$LATEST\" | grep -q '^shared/backups'" \
      "Latest archive does not contain /shared/backups"

# --- Cron ----------------------------------------------------------------
check "sudo crontab -l 2>/dev/null | grep -q backup-shared.sh" \
      "Root crontab contains backup-shared.sh"
check "sudo crontab -l 2>/dev/null | grep -q cleanup-backups.sh" \
      "Root crontab contains cleanup-backups.sh"
check "sudo crontab -l 2>/dev/null | grep backup-shared.sh | grep -qE '(^|[[:space:]])/[^[:space:]]*backup-shared\.sh'" \
      "Backup cron uses an absolute path"
check "sudo crontab -l 2>/dev/null | grep backup-shared.sh | grep -qE '>> .*\\.log 2>&1'" \
      "Backup cron redirects output to a log"

# --- Daemon --------------------------------------------------------------
check "systemctl is-active --quiet crond" \
      "crond is active"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]