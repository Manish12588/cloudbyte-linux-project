#!/bin/bash
# verify-onboarding.sh: CloudByte Section 3 self-check

# Adjust these two lines if your layout differs.
# Vagrant default:
#SCRIPT=/vagrant/scripts/onboard-user.sh
#CSV=/vagrant/data/new-hires.csv
# Lima users: comment the two lines above and uncomment these.
SCRIPT=/host/scripts/onboard-user.sh
CSV=/host/data/new-hires.csv

#SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#SCRIPT="$SCRIPT_DIR/onboard-user.sh"
#CSV="$SCRIPT_DIR/new-hires.csv"

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

echo "=== CloudByte Section 3 check ==="

# --- Static checks against the script file -------------------------------
check "test -f \"$SCRIPT\"" "$SCRIPT exists"
check "head -n 20 \"$SCRIPT\" | grep -q 'set -eo pipefail'" \
      "Script enables strict mode (set -eo pipefail)"
check "grep -Eq '^create_user *\\(\\)' \"$SCRIPT\"" \
      "Script defines create_user function"
check "[ \"\$(grep -c '^# Usage:' \"$SCRIPT\")\" -ge 3 ]" \
      "Script header carries at least three # Usage: lines"

# --- Static checks against the CSV ---------------------------------------
check "test -f \"$CSV\"" "$CSV exists"
check "[ \"\$(wc -l < \"$CSV\")\" -ge 2 ]" \
      "CSV has a header row plus at least one data row"

# --- Behaviour: non-root invocation refuses politely ---------------------
NONROOT_OUT=$(bash "$SCRIPT" --help 2>&1)
NONROOT_RC=$?
check "[ \"$NONROOT_RC\" -ne 0 ] && echo \"$NONROOT_OUT\" | grep -qi 'root'" \
      "Non-root invocation prints an error and exits non-zero"

# --- Behaviour: --help prints Usage and exits 0 --------------------------
HELP_OUT=$(sudo bash "$SCRIPT" --help 2>&1)
HELP_RC=$?
check "[ \"$HELP_RC\" -eq 0 ] && echo \"$HELP_OUT\" | grep -qi 'usage'" \
      "--help exits 0 and prints a Usage line"

# --- Behaviour: --dry-run creates no users -------------------------------
DRY_CSV=$(mktemp /tmp/verify-dry-XXXXXX.csv)
cat > "$DRY_CSV" <<'EOF'
username,group,fullname
verify_dry_a,engineering,Dry Run A
verify_dry_b,marketing,Dry Run B
EOF
sudo bash "$SCRIPT" --csv "$DRY_CSV" --dry-run > /dev/null 2>&1
check "! getent passwd verify_dry_a >/dev/null && ! getent passwd verify_dry_b >/dev/null" \
      "--dry-run does not create any users"
rm -f "$DRY_CSV"

# --- Behaviour: real CSV run + idempotency -------------------------------
sudo bash "$SCRIPT" --csv "$CSV" > /dev/null 2>&1
check "getent passwd testuser1 >/dev/null && getent passwd testuser2 >/dev/null && getent passwd testuser3 >/dev/null" \
      "CSV run creates testuser1, testuser2, testuser3"
check "id -nG testuser1 2>/dev/null | grep -qw engineering" \
      "testuser1 is a member of engineering"
check "id -nG testuser2 2>/dev/null | grep -qw marketing" \
      "testuser2 is a member of marketing"
check "id -nG testuser3 2>/dev/null | grep -qw operations" \
      "testuser3 is a member of operations"

RERUN_OUT=$(sudo bash "$SCRIPT" --csv "$CSV" 2>&1)
RERUN_RC=$?
check "[ \"$RERUN_RC\" -eq 0 ] && [ \"\$(echo \"$RERUN_OUT\" | grep -c '^Skip:')\" -ge 3 ]" \
      "Second CSV run is idempotent (three Skip lines, exit 0)"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]