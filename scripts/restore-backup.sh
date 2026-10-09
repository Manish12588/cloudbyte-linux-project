#!/bin/bash
# restore-backup.sh: CloudByte interactive restore tool.
# Author: Manish Kumar
# Lists every backup tarball in /shared/backups, asks you to pick one,
# extracts it to a directory of your choice (running as root). Refuses
# to extract over /shared (live data).
#
# Usage: sudo bash scripts/restore-backup.sh

set -eo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Run with sudo. /shared/backups is mode 2770 root:admins." >&2
    exit 1
fi

BACKUP_DIR=/shared/backups
DEFAULT_PATH="/tmp/restore-$(date +%F-%H%M%S)"

if ! ls "$BACKUP_DIR"/cloudbyte-shared-*.tar.gz > /dev/null 2>&1; then
    echo "No backup archives in $BACKUP_DIR. Run backup-shared.sh first." >&2
    exit 1
fi

#----------Picking an archive--------
echo "Available backups in $BACKUP_DIR:"
PS3="Pick a number (or Ctrl-D to cancel): "
select ARCHIVE in "$BACKUP_DIR"/cloudbyte-shared-*.tar.gz; do
    if [ -n "$ARCHIVE" ]; then
        break
    fi
    echo "Not a valid choice. Try again."
done

if [ -z "$ARCHIVE" ]; then
    echo "Cancelled."
    exit 0
fi

read -rp "Extract path [default: $DEFAULT_PATH]: " EXTRACT_DIR
if [ -z "$EXTRACT_DIR" ]; then
    EXTRACT_DIR="$DEFAULT_PATH"
fi

case "$EXTRACT_DIR" in
	/shared*)
        echo "Refusing to extract over /shared. That's the live data." >&2
        exit 1
        ;;
esac

confirm() {
    local prompt="$1"
    read -rp "$prompt [y/N] " reply
    case "$reply" in
        y|Y|yes|Yes) return 0 ;;
        *)           return 1 ;;
    esac
}

if ! confirm "Extract $ARCHIVE to $EXTRACT_DIR?"; then
    echo "Cancelled."
    exit 0
fi

cleanup() {
    if [ -d "$EXTRACT_DIR" ]; then
        rm -rf "$EXTRACT_DIR"
        echo "Cleanup: removed partial extract $EXTRACT_DIR" >&2
    fi
}
trap cleanup EXIT ERR INT

mkdir -p "$EXTRACT_DIR"
tar -xzf "$ARCHIVE" -C "$EXTRACT_DIR"

trap - EXIT ERR INT

echo "Restored to $EXTRACT_DIR."
echo "Verify with: ls $EXTRACT_DIR/shared/"