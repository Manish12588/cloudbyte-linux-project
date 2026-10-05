#!/bin/bash
# setup-backups.sh: CloudByte Section 4 backup directory setup
# Author: Manish Kumar
# Purpose: Create /shared/backups (root:admins, 2770) for backup-shared.sh.
# Usage: sudo bash scripts/setup-backups.sh
# Safe to re-run.

set -eo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Error: setup-backups.sh must be run as root."
    echo "Hint: sudo bash $0"
    exit 1
fi

getent group admins > /dev/null || { echo "Error: group 'admins' missing. Run create-foundations.sh first."; exit 1; }

mkdir -p /shared/backups
chgrp admins /shared/backups
chmod 2770 /shared/backups
echo "Backups: /shared/backups -> root:admins 2770"
echo "Done. Run a backup with: sudo bash scripts/backup-shared.sh"