#!/usr/bin/env bash
# Refresh llama.cpp from upstream master and rebuild with the project's
# tuned CUDA flags.
#
# Modes:
#   (no flag)    Incremental: git pull + cmake --build. ccache-backed
#                relinks are seconds; full rebuilds ~2-3 min.
#   --reinstall  Wipe ~/llama.cpp/build/ and rebuild. ccache still serves
#                object files, so this is "fast cold" (~2-3 min).
#   --clean      Wipe ~/llama.cpp/build/ AND wipe ccache. True
#                from-scratch compile (~10 min). Implies --reinstall.

set -euo pipefail

REPO_DIR="${LLAMACPP_REPO:-$HOME/llama.cpp}"
REINSTALL=0
CLEAN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --reinstall)  REINSTALL=1 ;;
        --clean)      CLEAN=1; REINSTALL=1 ;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *)
            echo "llama-update: unknown flag: $1" >&2
            echo "run 'llama-update --help' to see valid flags" >&2
            exit 1 ;;
    esac
    shift
done

cd "${REPO_DIR}"
git pull --ff-only origin master

if [ "${CLEAN}" = 1 ]; then
    if command -v ccache >/dev/null 2>&1; then
        echo "[update] --clean: wiping ccache"
        ccache -C
    else
        echo "[update] --clean: ccache not installed, nothing to wipe"
    fi
fi

if [ "${REINSTALL}" = 1 ]; then
    echo "[update] --reinstall: removing ${REPO_DIR}/build for fresh cmake configure"
    rm -rf "${REPO_DIR}/build"
fi

cmake -B build \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCH:-120}" \
    -DGGML_CUDA_F16=ON \
    -DGGML_CUDA_FA_ALL_QUANTS=ON

cmake --build build --config Release -j"$(nproc)"
