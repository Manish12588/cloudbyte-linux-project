#!/bin/bash
#================================
# Author: Manish
# Cleanup for user-management practice
# Order matters:
#   1. users (with home dirs)
#   2. leftover private groups (userdel skips them if primary group was changed)
#   3. custom groups (only possible once no user has them as primary)
#   4. leftover home dirs
#   5. verify
#================================

users=("alice" "bob" "carol" "dave" "emma" "frank" "grace" "henry" "iris" "jack" "kate" "leo")
groups=("engineering" "marketing" "operations" "admins")

echo -e "\n========== 1. Deleting users ==========\n"
for user in "${users[@]}"; do
    if ! getent passwd "$user" > /dev/null; then
        echo "User '$user' does not exist. Skipping."
    else
        sudo userdel -r "$user"
        # verify the RESULT, not just the exit code
        if getent passwd "$user" > /dev/null; then
            echo "User '$user' could NOT be deleted."
        else
            echo "User '$user' deleted."
        fi
    fi
done

echo -e "\n========== 2. Deleting leftover private groups ==========\n"
for group in "${users[@]}"; do
    if ! getent group "$group" > /dev/null; then
        echo "No leftover group '$group'. Skipping."
    elif sudo groupdel "$group"; then
        echo "Leftover group '$group' deleted."
    else
        echo "Group '$group' could NOT be deleted."
    fi
done

echo -e "\n========== 3. Deleting custom groups ==========\n"
for group in "${groups[@]}"; do
    if ! getent group "$group" > /dev/null; then
        echo "Group '$group' does not exist. Skipping."
    elif sudo groupdel "$group"; then
        echo "Group '$group' deleted."
    else
        echo "Group '$group' could NOT be deleted."
    fi
done

echo -e "\n========== 4. Removing leftover home dirs ==========\n"
for user in "${users[@]}"; do
    dir="/home/${user:?}"
    if [ ! -d "$dir" ]; then
        echo "No leftover dir '$dir'. Skipping."
    elif sudo rm -rf -- "$dir"; then
        echo "Leftover dir '$dir' removed."
    else
        echo "Dir '$dir' could NOT be removed."
    fi
done

echo -e "\n========== 5. Verify (empty output = clean) ==========\n"
echo "--- Users still present:"
getent passwd "${users[@]}"
echo "--- Groups still present:"
getent group "${users[@]}" "${groups[@]}"
echo "--- /home contents (only your own login user should be here):"
ls -A /home
echo "--- Orphaned files (owner or group no longer exists):"
sudo find / -xdev \( -nouser -o -nogroup \) 2>/dev/null
echo -e "\nCleanup finished."
