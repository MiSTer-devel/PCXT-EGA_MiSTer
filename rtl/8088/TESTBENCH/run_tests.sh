#!/usr/bin/env bash
#
# Run the 8088 core testbenches.
#
#   ./run_tests.sh                 every bench
#   ./run_tests.sh -n              niced, to share the machine with a synthesis
#   ./run_tests.sh adder           benches whose name matches "adder"
#   ./run_tests.sh -w adder        dump a VCD next to the build (Icarus only)
#
# Its siblings in rtl/KFPC-XT and rtl/video cover the chipset and the EGA path.
# This one covers rtl/8088, the MCL86 core.
#
# The core as a whole has no bench here and is not straightforward to give one:
# it needs the microcode ROM image, the BIU, a bus model and a clock-enable
# generator before it will do anything observable. What lives here instead are
# benches for the pieces this fork has changed, each one pinned against the
# behaviour it replaced.
#
set -uo pipefail

BUILD_DIR=${TB_BUILD:-$HOME/.cache/pcxt-8088-tb}
NICE=""
WAVE=""
FILTER=""

while [ $# -gt 0 ]; do
    case "$1" in
        -n|--nice)  NICE="nice -n 19" ;;
        -w|--wave)  WAVE="-DIVERILOG" ;;
        -h|--help)  sed -n '2,18p' "$0"; exit 0 ;;
        *)          FILTER="$1" ;;
    esac
    shift
done

cd "$(dirname "$0")/.." || exit 1
mkdir -p "$BUILD_DIR"

# Each bench names the sources it needs.
declare -A SOURCES=(
    [mcl86_adder_tb]="mcl86_adder.sv"
)

pass=0; fail=0; skip=0

for stem in $(printf '%s\n' "${!SOURCES[@]}" | sort); do
    if [ -n "$FILTER" ] && [[ "$stem" != *"$FILTER"* ]]; then continue; fi

    tb="TESTBENCH/$stem.sv"
    if [ ! -f "$tb" ]; then
        printf '  %-34s MISSING\n' "$stem"; skip=$((skip+1)); continue
    fi

    log=$BUILD_DIR/$stem.log
    start=$(date +%s)

    $NICE iverilog -g2012 $WAVE -o "$BUILD_DIR/$stem.vvp" \
        "$tb" ${SOURCES[$stem]} > "$log" 2>&1 \
        && (cd "$BUILD_DIR" && $NICE timeout 600 vvp "$BUILD_DIR/$stem.vvp") >> "$log" 2>&1
    rc=$?

    elapsed=$(( $(date +%s) - start ))

    if [ $rc -ne 0 ] && ! grep -qE 'RESULT|PASS|FAIL' "$log"; then
        printf '  %-34s BUILD FAIL  (%ss)  %s\n' "$stem" "$elapsed" "$log"
        skip=$((skip+1))
    elif grep -qE 'RESULT: FAIL|TIMEOUT|^FAIL|[1-9][0-9]* mismatches' "$log"; then
        printf '  %-34s FAIL        (%ss)\n' "$stem" "$elapsed"
        grep -E '^ *FAIL|TIMEOUT|RESULT: FAIL' "$log" | head -20 | sed 's/^/      /'
        fail=$((fail+1))
    else
        printf '  %-34s pass        (%ss)\n' "$stem" "$elapsed"
        pass=$((pass+1))
    fi
done

echo
echo "8088: $pass passed, $fail failed, $skip did not build"
[ $fail -eq 0 ] && [ $skip -eq 0 ]
