#!/bin/bash
# setup-permissions.sh: CloudByte Section 2 permissions setup
# Author: Manish Kumar
# Purpose: Add setgid to the team folders, create the sticky-bit dropbox,
#          and seed sample files so tests/verify-permissions.sh can pass.
# Usage: sudo bash scripts/setup-permissions.sh
# Safe to re-run: every step checks before it changes anything.
# Run scripts/create-foundations.sh first (groups and folders must exist).

set -eo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Error: setup-permissions.sh must be run as root."
    echo "Hint: sudo bash $0"
    exit 1
fi

for g in engineering marketing operations admins; do
    getent group "$g" > /dev/null || { echo "Error: group '$g' missing. Run create-foundations.sh first."; exit 1; }
done

# --- 1. Team folders: setgid (2770) so new files inherit the team group ---
for team in engineering marketing operations; do
    [ -d "/shared/$team" ] || { echo "Error: /shared/$team missing. Run create-foundations.sh first."; exit 1; }
    chgrp "$team" "/shared/$team"
    chmod 2770 "/shared/$team"
    echo "Team folder: /shared/$team -> root:$team 2770"
done

# --- 2. Dropbox: sticky bit (1773); others can write but not list ---------
mkdir -p /shared/dropbox
chgrp admins /shared/dropbox
chmod 1773 /shared/dropbox
echo "Dropbox: /shared/dropbox -> root:admins 1773"

# --- 3. Sample files (the setgid folders hand them the team group) --------
seed() {
    local file=$1 content=$2
    if [ -e "$file" ]; then
        echo "Skip: $file already exists"
    else
        printf '%s\n' "$content" > "$file"
        echo "Created: $file"
    fi
}

seed /shared/engineering/notes.txt   "Sprint notes for the engineering team"
seed /shared/engineering/app.conf    "log_level=info"
seed /shared/marketing/campaign.csv  "campaign,channel,budget"
seed /shared/operations/server.log   "2026-10-05 02:00:01 ERROR backup job failed (sample entry)"
seed /shared/operations/deploy.sh    "#!/bin/bash"

# Heal step: make sure every file carries its folder's team group.
for team in engineering marketing operations; do
    find "/shared/$team" -type f ! -group "$team" -exec chgrp "$team" {} +
done

echo "Done. Verify with: bash tests/verify-permissions.sh"
