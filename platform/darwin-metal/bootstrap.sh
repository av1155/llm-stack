#!/usr/bin/env bash
# Idempotent bootstrap for macOS + Apple Silicon (Metal backend).
# Installs only what's missing via Homebrew. Safe to re-run.

set -euo pipefail

log()  { printf '[bootstrap] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

if ! have brew; then
    echo "Homebrew is required. Install from https://brew.sh and re-run." >&2
    exit 1
fi

# --- llama.cpp via Homebrew -------------------------------------------------
if brew list --formula llama.cpp >/dev/null 2>&1; then
    log "llama.cpp already installed: $(llama-server --version 2>&1 | head -1)"
else
    log "installing llama.cpp via brew"
    brew install llama.cpp
fi

# --- huggingface-cli --------------------------------------------------------
if have huggingface-cli; then
    log "huggingface-cli present"
else
    log "installing huggingface-cli via brew"
    brew install huggingface-cli
fi

log "darwin-metal bootstrap complete"
