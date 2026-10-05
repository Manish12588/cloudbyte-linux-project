#!/bin/bash
# verify-all.sh: run every verify-*.sh in order and print one summary.
# Run on the VM:  bash /host/verify-all.sh
# Note: verify-onboarding.sh creates testuser1-3; see the handbook for cleanup.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$(basename "${BASH_SOURCE[0]}")"
FAILED=()
TOTAL=0

for f in "$SCRIPT_DIR"/verify-*.sh; do
    name=$(basename "$f")
    [ "$name" = "$SELF" ] && continue
    TOTAL=$((TOTAL+1))
    echo ""
    echo "################ $name ################"
    if ! bash "$f"; then
        FAILED+=("$name")
    fi
done

echo ""
echo "################ SUMMARY ################"
if [ "${#FAILED[@]}" -eq 0 ]; then
    echo "✅ All $TOTAL verify scripts passed."
    exit 0
fi
echo "❌ ${#FAILED[@]} of $TOTAL verify scripts failed:"
printf '   - %s\n' "${FAILED[@]}"
exit 1
