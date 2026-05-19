#!/usr/bin/env bash
# Bootstrap for Linux + NVIDIA CUDA hosts (e.g. WSL2 Ubuntu). Idempotent:
# installs only what's missing. Safe to re-run; verifies state at the end.
#
# Env vars:
#   LLAMACPP_REPO   where to clone llama.cpp (default: $HOME/llama.cpp)
#   CUDA_ARCH       SM architecture for the CUDA build (default: 120, Blackwell)
#
# Exits: 0 on success; non-zero on package install or build failure.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

log()  { printf '[bootstrap] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

if have nvcc; then
    log "CUDA toolkit present: $(nvcc --version | grep release | sed 's/^ *//')"
else
    log "CUDA toolkit missing, installing cuda-toolkit-13-2"
    cd /tmp
    wget -q https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    sudo apt-get update
    sudo apt-get install -y cuda-toolkit-13-2
    rm -f cuda-keyring_1.1-1_all.deb

    BLOCK_MARKER_START="# >>> llm-stack cuda >>>"
    BLOCK_MARKER_END="# <<< llm-stack cuda <<<"
    # grep silenced because ~/.bashrc may not yet exist on a fresh box.
    if ! grep -qF "${BLOCK_MARKER_START}" "${HOME}/.bashrc" 2>/dev/null; then
        cat >> "${HOME}/.bashrc" <<EOF

${BLOCK_MARKER_START}
export PATH=/usr/local/cuda-13.2/bin:\$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-13.2/lib64:\${LD_LIBRARY_PATH:-}
${BLOCK_MARKER_END}
EOF
        log "wrote CUDA PATH/LD_LIBRARY_PATH block to ~/.bashrc"
    fi
    # shellcheck disable=SC1090
    source "${HOME}/.bashrc"
fi

APT_DEPS=(build-essential cmake git ccache ninja-build libcurl4-openssl-dev libssl-dev pkg-config)
MISSING=()
for pkg in "${APT_DEPS[@]}"; do
    # dpkg-query exits non-zero if pkg not installed; the || via grep handles both.
    dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed" || MISSING+=("$pkg")
done
if [ "${#MISSING[@]}" -gt 0 ]; then
    log "installing missing apt packages: ${MISSING[*]}"
    sudo apt-get install -y "${MISSING[@]}"
else
    log "apt build deps already installed"
fi

# hf (Hugging Face CLI). Only used by bin/models; the rest of the stack
# doesn't need it. The Python package is still `huggingface_hub[cli]`; the
# binary it ships was renamed from `huggingface-cli` to `hf`.
if have hf; then
    log "hf present"
elif have pipx; then
    log "installing huggingface_hub[cli] via pipx"
    pipx install "huggingface_hub[cli]"
else
    log "skipping hf (pipx not installed)"
    log "  to install later: sudo apt-get install pipx && pipx install 'huggingface_hub[cli]'"
fi

LLAMACPP_REPO="${LLAMACPP_REPO:-$HOME/llama.cpp}"
if [ ! -d "${LLAMACPP_REPO}/.git" ]; then
    log "cloning llama.cpp into ${LLAMACPP_REPO}"
    git clone https://github.com/ggml-org/llama.cpp "${LLAMACPP_REPO}"
fi

if [ ! -x "${LLAMACPP_REPO}/build/bin/llama-server" ]; then
    log "building llama.cpp (~10 min cold, ~2-3 min with ccache)"
    cd "${LLAMACPP_REPO}"
    cmake -B build \
        -DGGML_CUDA=ON \
        -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCH:-120}" \
        -DGGML_CUDA_F16=ON \
        -DGGML_CUDA_FA_ALL_QUANTS=ON
    cmake --build build --config Release -j"$(nproc)"
else
    log "llama-server already built: $("${LLAMACPP_REPO}/build/bin/llama-server" --version 2>&1 | head -1)"
fi

BLOCK_MARKER_START="# >>> llm-stack llama.cpp >>>"
BLOCK_MARKER_END="# <<< llm-stack llama.cpp <<<"
# grep silenced because ~/.bashrc may not exist on a brand-new box.
if ! grep -qF "${BLOCK_MARKER_START}" "${HOME}/.bashrc" 2>/dev/null; then
    cat >> "${HOME}/.bashrc" <<EOF

${BLOCK_MARKER_START}
export PATH="${LLAMACPP_REPO}/build/bin:\$PATH"
${BLOCK_MARKER_END}
EOF
    log "wrote llama.cpp PATH block to ~/.bashrc"
fi

log "linux-cuda bootstrap complete"
