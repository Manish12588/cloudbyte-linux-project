#!/bin/bash
# log-generator.sh: simulate a CloudByte application log with severity levels.
# Author:  <your name>
# Created: <date>
# Purpose: Append COUNT synthetic timestamped lines to /logs/cloudbyte-app.log,
#          spread across the last 24 hours, for analyse-logs.sh to summarise.
# Usage:   sudo bash log-generator.sh [count]   (count defaults to 200)

set -eo pipefail

# --- Sudo guard -----------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo "Error: log-generator.sh must be run as root (it writes to /logs)."
    echo "Hint: sudo bash $0"
    exit 1
fi

# --- Config ---------------------------------------------------------------
LOG=/logs/cloudbyte-app.log
COUNT="${1:-200}"

# --- Generate -------------------------------------------------------------
for (( i = 0; i < COUNT; i++ )); do
    # Pick a severity by bucketing a 0-9 random number, weighted so INFO is
    # common and CRITICAL is rare but reliably present over a full run.
    case $(( RANDOM % 10 )) in
        0|1|2|3|4|5) level=INFO ;;
        6|7)         level=WARN ;;
        8)           level=ERROR ;;
        9)           level=CRITICAL ;;
    esac

    # Give each level a matching message.
    case $level in
        INFO)     msg="request served" ;;
        WARN)     msg="slow response" ;;
        ERROR)    msg="request failed" ;;
        CRITICAL) msg="service unavailable" ;;
    esac

    # Backdate each entry a random whole number of hours so the log spans the
    # day. This is the same -d relative-time form you used with touch earlier.
    ts=$(date -d "$(( RANDOM % 24 )) hours ago" '+%Y-%m-%d %H:%M:%S')

    echo "$ts [$level] $msg" >> "$LOG"
    sleep 0.02
done

echo "Wrote $COUNT lines to $LOG."
