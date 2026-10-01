#!/bin/bash
# onboard-user.sh: CloudByte Solutions onboarding automation
# Author: Manish Kumar
# Created: 2026-09-30
# Purpose: Create a new user, set a temporary password, add them to a
#          team group, and force a password change on first login.
# Usage: sudo bash onboard-user.sh                       # interactive
# Usage: sudo bash onboard-user.sh --csv path/to/new-hires.csv
# Usage: sudo bash onboard-user.sh --dry-run             # combinable

set -eo pipefail

# --- Sudo guard -----------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo "Error: this script must be run as root."
    echo "Try: sudo bash $0 $*"
    exit 1
fi

# --- Argument parsing ----------------------------------------------------
DRY_RUN=false
CSV_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --csv)
            CSV_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            grep '^# Usage:' "$0" | sed 's/^# //'
            exit 0
            ;;
        *)
            echo "Error: unknown argument '$1'." >&2
            exit 1
            ;;
    esac
done

# --- Constants ------------------------------------------------------------
TEMP_PASSWORD="ChangeMe123!"

create_user() {
 local username=$1
 local group=$2
 local fullname=$3

 if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] would create $username in $group with temp password"
    return 0
 fi

 # --- Guard: target group must exist ---------------------------------------
 if ! getent group "$group" >/dev/null 2>&1; then
    echo "Error: group '$group' does not exist for user '$username'"
    #echo "Hint: getent group | cut -d: -f1   to list available groups."
    return 1
 fi

 # --- Guard: skip if user already exists -----------------------------------
 if getent passwd "$username" >/dev/null 2>&1; then
    echo "Skip: user '$username' already exists."
    return 0
 else
    # --- Create the user ------------------------------------------------------
    useradd -m -c "$fullname" "$username"
    echo "$username:$TEMP_PASSWORD" | chpasswd
    usermod -aG "$group" "$username"
    chage -d 0 "$username"
    echo "Created $username in group $group with temp password (must change on first login)."
 fi

}

# --- Main: dispatch ------------------------------------------------------
if [ -n "$CSV_FILE" ]; then
    if [ ! -f "$CSV_FILE" ]; then
        echo "Error: CSV file '$CSV_FILE' not found."
        exit 3
    fi
    failures=0
    { read -r _header
      while IFS=, read -r u g f || [ -n "$u" ]; do
          [ -z "$u" ] && continue
          if ! create_user "$u" "$g" "$f"; then
              failures=$((failures + 1))
          fi
      done
    } < "$CSV_FILE"
    [ "$failures" -gt 0 ] && exit 4 || exit 0
else
    read -rp "Username: "  username
    read -rp "Group: "     group
    read -rp "Full name: " fullname
    create_user "$username" "$group" "$fullname"
fi