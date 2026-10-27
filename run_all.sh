#!/usr/bin/env bash
# run_all.sh - Mac/Linux version of run_all.ps1
# usage: bash ./run_all.sh            (rebuild libs, then run all tests)
#        bash ./run_all.sh --skip-libs

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
MOCHA="$DIR/mocha"
LIMIT_MB=9
TMP="$(mktemp -d)"
libs_ok=1
found=0
bad=()

# --- 1. libraries ---
if [ "$1" != "--skip-libs" ]; then
    echo "=== Rebuilding libraries ==="
    if ! bash "$MOCHA" libs; then
        libs_ok=0
    fi
    echo ""
    echo "=== Running tests ==="
fi

# --- 2. tests: test_a..test_z, then test_aa..test_zz ---
for f in test_[a-z].mch test_[a-z][a-z].mch; do
    [ -e "$f" ] || continue
    found=1
    n="${f%.mch}"
    rm -f "$n"

    if ! bash "$MOCHA" "$f" > /dev/null 2>&1 || [ ! -x "./$n" ]; then
        echo "❌ $n  COMPILE FAIL"
        bad+=("$n")
        continue
    fi

    /usr/bin/time -l "./$n" > /dev/null 2> "$TMP/time.txt" < /dev/null
    code=$?

    peak_bytes=$(grep "maximum resident set size" "$TMP/time.txt" | awk '{print $1}')
    peak=$(awk -v b="${peak_bytes:-0}" 'BEGIN { printf "%.1f", b / 1048576 }')

    verdict="ok"
    if [ "$code" -eq 97 ]; then
        verdict="RC FATAL"
    elif [ "$code" -ne 0 ]; then
        verdict="EXIT $code"
    elif awk -v p="$peak" -v l="$LIMIT_MB" 'BEGIN { exit !(p > l) }'; then
        verdict="LEAK?"
    fi

    if [ "$verdict" = "ok" ]; then
        printf "✅ %-10s peak %6s MB  exit %-4s %s\n" "$n" "$peak" "$code" "$verdict"
    else
        printf "❌ %-10s peak %6s MB  exit %-4s %s\n" "$n" "$peak" "$code" "$verdict"
        head -n 3 "$TMP/time.txt"
        bad+=("$n")
    fi
done

echo ""
if [ "$found" -eq 0 ]; then
    echo "No test_*.mch files found in this folder."
fi
if [ "$libs_ok" -eq 0 ]; then
    echo "LIBRARIES: some failed to build (see the list above)"
fi
if [ "${#bad[@]}" -eq 0 ] && [ "$libs_ok" -eq 1 ]; then
    echo "ALL CLEAN ✅"
elif [ "${#bad[@]}" -gt 0 ]; then
    echo "PROBLEMS: ${bad[*]}"
fi

rm -rf "$TMP"
exit 0