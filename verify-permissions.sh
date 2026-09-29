#!/bin/bash
# verify-permissions.sh: CloudByte Section 2 self-check

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

team_folder_check() {
    local path=$1 group=$2
    local g m
    g=$(stat -c %G "$path" 2>/dev/null)
    m=$(stat -c %a "$path" 2>/dev/null)
    if [ "$g" = "$group" ] && [ "$m" = "2770" ]; then
        echo "✅ PASS: $path (group=$group, mode=$m, setgid set)"
        PASS=$((PASS+1))
    else
        echo "❌ FAIL: $path (want group=$group mode=2770, got group=$g mode=$m)"
        FAIL=$((FAIL+1))
    fi
}

echo "=== CloudByte Section 2 check ==="

# Team folders: mode 2770 with the right group.
team_folder_check /shared/engineering engineering
team_folder_check /shared/marketing   marketing
team_folder_check /shared/operations  operations

# Existing files inside each team folder all carry the team group (heal step).
for team in engineering marketing operations; do
    check "! sudo find /shared/$team -type f \\! -group $team 2>/dev/null | grep -q ." \
          "All files under /shared/$team carry group $team"
done

# Setgid propagation: a fresh file by an engineer inherits group engineering.
PROBE=/shared/engineering/.setgid-probe-$$
sudo -u alice touch "$PROBE" 2>/dev/null
PROBE_GROUP=$(sudo stat -c %G "$PROBE" 2>/dev/null)
sudo rm -f "$PROBE"
check "[ \"$PROBE_GROUP\" = engineering ]" \
      "New file by alice in /shared/engineering inherits group engineering"

# Dropbox structural checks.
check "test -d /shared/dropbox" "/shared/dropbox exists"
check "[ \"\$(stat -c %U:%G /shared/dropbox 2>/dev/null)\" = root:admins ]" \
      "/shared/dropbox owned by root:admins"
check "test -k /shared/dropbox" "Sticky bit set on /shared/dropbox"

# Dropbox functional checks: emma (non-admin) can write but cannot list.
check "sudo -u emma test -w /shared/dropbox" \
      "Non-admin can write to /shared/dropbox"
check "! sudo -u emma ls /shared/dropbox > /dev/null 2>&1" \
      "Non-admin cannot list /shared/dropbox (deny is a pass)"

# Five extensions present somewhere under /shared.
for ext in txt conf csv log sh; do
    check "sudo find /shared -type f -name '*.${ext}' 2>/dev/null | grep -q ." \
          "At least one .${ext} file under /shared"
done

# Some file under /shared contains the word ERROR.
check "sudo grep -rl ERROR /shared 2>/dev/null | grep -q ." \
      "At least one file under /shared contains 'ERROR'"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
