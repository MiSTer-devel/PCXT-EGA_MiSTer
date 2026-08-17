#!/usr/bin/env bash
#
# Run the EGA testbenches.
#
#   ./run_tests.sh                 every bench, Icarus
#   ./run_tests.sh -v              every bench, Verilator
#   ./run_tests.sh cursor          benches whose name matches "cursor"
#   ./run_tests.sh -v -n status    Verilator, niced, name matches "status"
#
# Which backend to use is a time trade-off, measured on this tree:
#
#   Verilator runs ~15x faster but pays ~55 s of C++ compilation every time a
#   source changes. Icarus compiles in seconds. So Icarus wins while iterating
#   on a bench, and Verilator wins for a full pass or for anything whose Icarus
#   run is over a minute.
#
# Run from rtl/video: $readmemh in the splash renderer resolves relative to the
# working directory.
#
set -uo pipefail

BUILD_DIR=${TB_BUILD:-$HOME/.cache/pcxt-ega-tb}
BACKEND=icarus
NICE=""
JOBS=${TB_JOBS:-4}
FILTER=""

while [ $# -gt 0 ]; do
    case "$1" in
        -v|--verilator) BACKEND=verilator ;;
        -i|--icarus)    BACKEND=icarus ;;
        -n|--nice)      NICE="nice -n 19" ;;
        -j)             shift; JOBS="$1" ;;
        -h|--help)      sed -n '2,20p' "$0"; exit 0 ;;
        *)              FILTER="$1" ;;
    esac
    shift
done

cd "$(dirname "$0")/.." || exit 1
mkdir -p "$BUILD_DIR"

# ega_io_stretch and the BRAM frontend live in the chipset tree; three benches
# need them. video_monochrome_converter is left out on purpose: it assigns whole
# arrays, which Icarus 12 cannot elaborate, and ega_top does not need it.
SOURCES=(UM6845R.v ega_*.v vga_*.v video_scandoubler.v
         ../KFPC-XT/HDL/ega_io_stretch.sv ../KFPC-XT/HDL/ega_vram_bram_frontend.sv)

pass=0; fail=0; skip=0

for tb in TESTBENCH/*.v TESTBENCH/*.sv; do
    name=$(basename "$tb"); stem=${name%.*}
    case "$name" in jtframe*) continue ;; esac
    if [ -n "$FILTER" ] && [[ "$stem" != *"$FILTER"* ]]; then continue; fi

    log=$BUILD_DIR/$stem.log
    start=$(date +%s)

    if [ "$BACKEND" = verilator ]; then
        # --public-flat-rw keeps hierarchical references alive; the benches read
        # internal signals and one of them forces the blink counter.
        # --binary --timing runs the Verilog benches as they are, no C++ harness.
        $NICE verilator --binary --timing --public-flat-rw -Wno-fatal -j "$JOBS" \
            --Mdir "$BUILD_DIR/$stem.obj" -o "$stem" --top-module "$stem" \
            "$tb" "${SOURCES[@]}" > "$log" 2>&1 \
            && $NICE "$BUILD_DIR/$stem.obj/$stem" >> "$log" 2>&1
        rc=$?
    else
        $NICE iverilog -g2012 -o "$BUILD_DIR/$stem.vvp" "$tb" "${SOURCES[@]}" > "$log" 2>&1 \
            && $NICE vvp "$BUILD_DIR/$stem.vvp" >> "$log" 2>&1
        rc=$?
    fi

    elapsed=$(( $(date +%s) - start ))

    if [ $rc -ne 0 ] && ! grep -qE 'RESULT|PASS|FAIL' "$log"; then
        printf '  %-34s BUILD FAIL  (%ss)  %s\n' "$stem" "$elapsed" "$log"
        skip=$((skip+1))
    elif grep -qE 'RESULT: FAIL|TIMEOUT|[1-9][0-9]* failed' "$log"; then
        printf '  %-34s FAIL        (%ss)\n' "$stem" "$elapsed"
        grep -E '^FAIL|TIMEOUT' "$log" | sed 's/^/      /'
        fail=$((fail+1))
    else
        printf '  %-34s pass        (%ss)\n' "$stem" "$elapsed"
        pass=$((pass+1))
    fi
done

echo
echo "$BACKEND: $pass passed, $fail failed, $skip did not build"
[ $fail -eq 0 ] && [ $skip -eq 0 ]
