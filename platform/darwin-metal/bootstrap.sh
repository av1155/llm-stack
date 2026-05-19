#!/usr/bin/env bash
# Bootstrap for macOS + Apple Silicon (Metal backend). Idempotent: installs
# only what's missing via Homebrew. Safe to re-run.
#
# Exits: 0 on success; 1 if Homebrew is missing.

set -euo pipefail

log()  { printf '[bootstrap] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

if ! have brew; then
    echo "Homebrew is required. Install from https://brew.sh and re-run." >&2
    exit 1
fi

if brew list --formula llama.cpp >/dev/null 2>&1; then
    log "llama.cpp already installed: $(llama-server --version 2>&1 | head -1)"
else
    log "installing llama.cpp via brew"
    brew install llama.cpp
fi

# The formula was renamed from `huggingface-cli` to `hf` upstream. The `hf`
# formula still ships a `huggingface-cli` shim for the old binary name.
if have hf; then
    log "hf present: $(hf version 2>/dev/null | head -1)"
else
    log "installing hf via brew"
    brew install hf
fi

log "darwin-metal bootstrap complete"
