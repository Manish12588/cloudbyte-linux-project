#!/bin/bash
# verify-foundations.sh: CloudByte Server Foundations self-check

# Resolve the script's own directory so repo-relative checks (like the
# setup log on the host) work no matter where the script is invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

dir_check() {
    local path=$1 group=$2 modes=$3
    local g m
    g=$(stat -c %G "$path" 2>/dev/null)
    m=$(stat -c %a "$path" 2>/dev/null)
    if [ "$g" = "$group" ] && echo " $modes " | grep -q " $m "; then
        echo "✅ PASS: $path (group=$group, mode=$m)"
        PASS=$((PASS+1))
    else
        echo "❌ FAIL: $path (want group=$group mode=$modes, got group=$g mode=$m)"
        FAIL=$((FAIL+1))
    fi
}

echo "=== CloudByte Server Foundations check ==="

for g in engineering marketing operations admins; do
    check "getent group $g" "Group '$g' exists"
done

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

dir_check /shared/engineering  engineering "770 2770"
dir_check /shared/marketing    marketing   "770 2770"
dir_check /shared/operations   operations  "770 2770"
dir_check /shared/company-docs admins      "775 2775"
dir_check /logs/reports        admins      "775 2775"

check "test -s \"$SCRIPT_DIR/docs/server-setup-log.txt\"" \
      "Setup log exists in host repo and is non-empty"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]