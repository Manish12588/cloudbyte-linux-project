#!/bin/bash

set -eo pipefail

print_header() {
        local header=$1
        echo "===== $header ====="
}

confirm() {
        local prompt=$1
        local reply
        read -rp "$prompt " reply
        if [ "$reply" = "y" ] || [ "$reply" = "Y" ] || [ "$reply" = "yes" ] || [ "$reply" = "Yes" ]; then
                return 0
        else
                return 1
        fi
}

print_header "User Audit"
print_header "Backup Report"
print_header "Done"

if confirm "Delete /tmp/scratch-demo?"; then
        echo "Deleting.."
else
        echo "Cancelled."
fi