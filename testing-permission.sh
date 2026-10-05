#!/bin/bash

echo "========== Testing Permission Directory =========="
echo

for dir in engineering marketing operations; do
    path="/shared/$dir"

    if sudo -u alice bash -c "cd '$path'"; then
        if [ "$dir" = "engineering" ]; then
            echo "i️ INFO: Testing file creation"
            file="$path/alice_test.txt"
            if sudo -iu alice bash -c "cd '$path' && touch alice_test.txt && ls -l $path"; then
                echo -e "✅ PASS: Alice can write to $path\n"
            else
                echo -e "❌ FAIL: Alice cannot write to $path\n"
            fi
        else
            echo -e "❌ FAIL: Alice should NOT access $path\n"
        fi
    else
        if [ "$dir" = "engineering" ]; then
            echo -e "❌ FAIL: Alice should access $path\n"
        else
            echo -e "✅ PASS: Alice cannot access $path\n"
        fi
    fi
done
echo
echo "=================================================="
