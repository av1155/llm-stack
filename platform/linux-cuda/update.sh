#!/usr/bin/env bash
# Refresh llama.cpp from upstream master and rebuild with the project's
# tuned CUDA flags. Idempotent: a no-op pull triggers a quick CMake
# regen + ccache-backed link-only rebuild in ~1-2 minutes.

set -euo pipefail

REPO_DIR="${LLAMACPP_REPO:-$HOME/llama.cpp}"
cd "${REPO_DIR}"

git pull --ff-only origin master

cmake -B build \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCH:-120}" \
    -DGGML_CUDA_F16=ON \
    -DGGML_CUDA_FA_ALL_QUANTS=ON

cmake --build build --config Release -j"$(nproc)"
