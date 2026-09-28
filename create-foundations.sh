#!/bin/bash
# create-foundations.sh: CloudByte Server Create Foundations
# Author: Manish

PASS=0
FAIL=0
groups=("engineering" "marketing" "operations","admins")

check_group() {
    local group="$1"
    if getent group "$group" > /dev/null 2>&1; then
        echo "⚠️ Group '$group' already exists."
        return 1
    else
        echo "Group '$group' does not exist."
        return 0
    fi
}

check_user(){
   local user="$1"
      if getent passwd "$user" > /dev/null 2>&1; then
          echo "⚠️ User '$user' already exists."
          return 1
      else
          echo "User '$user' does not exist."
          return 0
      fi
}

echo -e "========== Group Creation ==========\n"
for group in engineering marketing operations admins; do
    if check_group "$group"; then
        sudo groupadd "$group"
        if getent group "$group" > /dev/null 2>&1; then
            echo "✅ PASS: Group '$group' created successfully."
            PASS=$((PASS+1))
        else
            echo "❌ FAIL: Group '$group' was not created."
            FAIL=$((FAIL+1))
        fi
    else
        echo "⏭️ Skipping creation of '$group'."
    fi
done
echo -e "\n======================================="

echo -e "========== User Creation ==========\n"
for user in alice bob carol dave emma frank grace henry iris jack kate leo; do
    if check_user "$user"; then
      #Adding into corresponding group
      department_group=""
      secondary_group=""
      case "$user" in
      alice|bob|carol|dave)
        department_group="engineering"
        ;;
      emma|frank|grace)
        department_group="marketing"
        ;;
      henry|iris|jack)
        department_group="operations"
        ;;
      kate|leo)
        department_group="operations"
        secondary_group="admins"
        ;;
      esac

      #Creating User
      sudo useradd -m -c "$user ($department_group)" "$user"

      if getent passwd "$user" > /dev/null 2>&1; then
           echo "✅ PASS: User '$user' created successfully."
            PASS=$((PASS+1))
      else
            echo "❌ FAIL: User '$user' was not created."
            FAIL=$((FAIL+1))
      fi

      #Adding into primary group
      if [ -n "$department_group" ]; then
        sudo usermod -aG "$department_group" "$user"
        echo "ℹ️ INFO: Adding user '$user' to group '$department_group'"
      fi

      #Adding into secondary group
      if [ -n "$secondary_group" ]; then
        sudo usermod -aG "$secondary_group" "$user"
        echo "ℹ️ INFO: Adding user '$user' to group '$secondary_group'"
      fi

    else
        echo "⏭️ Skipping creation of '$user'."
    fi
done
echo -e "\n======================================="

echo -e "========== Building Directory Structure ==========\n"
for dir in engineering marketing operations company-docs reports; do
  #Setting the path of directory
  if [ "$dir" = "reports" ]; then
     path="/logs/$dir"
  else
     path="/shared/$dir"
  fi

  #Creating Directory
  echo "ℹ️ INFO: Creating directory '$path'"
  if sudo mkdir -p "$path"; then
    echo "✅ PASS: Directory '$path' created."
    PASS=$((PASS+1))
  else
    echo "❌ FAIL: Could not create '$path'."
    FAIL=$((FAIL+1))
  fi
done
echo -e "\n=================================================="

echo -e "========== Change Owner Group of Directory =========\n"
for g in admins engineering marketing operations; do
  if [ "$g" = "admins" ]; then
      if sudo chgrp "$g" "/shared/company-docs"; then
         echo "✅ PASS: /shared/company-docs → $g"
         PASS=$((PASS+1))
      else
         echo "❌ FAIL: Could not change group of /shared/company-docs"
         FAIL=$((FAIL+1))
      fi
      if sudo chgrp "$g" "/logs/reports"; then
         echo "✅ PASS: /logs/reports → $g"
         PASS=$((PASS+1))
      else
         echo "❌ FAIL: Could not change group of /logs/reports"
         FAIL=$((FAIL+1))
      fi
  else
      if sudo chgrp "$g" "/shared/$g"; then
         echo "✅ PASS: /shared/$g → $g"
         PASS=$((PASS+1))
      else
         echo "❌ FAIL: Could not change group of /shared/$g"
         FAIL=$((FAIL+1))
      fi
  fi
done
echo -e "\n====================================================="


echo -e "========== Change Permission of Directory =========\n"
for dir in company-docs engineering marketing operations reports; do
  case $dir in
  company-docs)
    path="/shared/$dir"
    permission=775
    ;;
  reports)
    path="/logs/$dir"
    permission=755
    ;;
  engineering|marketing|operations)
    path="/shared/$dir"
    permission=770
    ;;
  *)
    echo "FAIL: Unknown directory /shared/$dir"
    continue
    ;;
  esac

  if sudo chmod "$permission" "$path"; then
       echo "✅ PASS: $path → Permission $permission"
       PASS=$((PASS+1))
    else
       echo "❌ FAIL: Could not change permission of $path"
       FAIL=$((FAIL+1))
  fi
done
echo -e "\n====================================================="


echo
#Showing total PASS and FAIL count.
echo "PASS: $PASS"
echo "FAIL: $FAIL"