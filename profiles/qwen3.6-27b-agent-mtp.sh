#!/usr/bin/env bash
# Qwen3.6-27B MTP (Multi-Token Prediction), Instruct / non-thinking /
# tool-calling profile. Same model architecture + sampler block as
# qwen3.6-27b-agent.sh; the difference is the GGUF (Unsloth's MTP variant
# of the weights, which embeds speculative-decoding draft heads) and the
# `--spec-type draft-mtp` flag.
#
# Output distribution is identical to the non-MTP variant by construction
# (rejection-sampling verification at every step). Expect roughly 1.4x
# faster generation on dense 27B per Unsloth's benchmarks. MTP draft heads
# add ~1 GB VRAM overhead; on VRAM-constrained hosts (Andrea-PC), pair
# with `--cache-type-k q8_0 --cache-type-v q8_0` via MTP_EXTRA_AGENT_FLAGS
# to free ~3 GB from the KV cache.
#
# Endpoint: http://${HOST_BIND}:11434/v1   (OpenAI-compatible)
# Served alias: qwen3.6-27b-agent   (same as the non-MTP server so clients
#                                    like TradingAgents reach it unchanged)
#
# Required env (from hosts/${LLM_STACK_HOST}.env):
#   MTP_AGENT_MODEL_DIR, MTP_AGENT_MODEL_FILE, MTP_AGENT_CTX_SIZE, THREADS
#
# Exits: 1 if host config or model file missing; 2 if the host has no
#        MTP_AGENT_* block (MTP not enabled on this host).

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${LLM_STACK_HOST:-$(hostname -s | tr '[:upper:]' '[:lower:]')}"

if [ ! -f "${REPO}/hosts/${HOST}.env" ]; then
    echo "llm-stack: no host config at ${REPO}/hosts/${HOST}.env" >&2
    echo "Available host files:" >&2
    ls "${REPO}/hosts/" | grep -vE '^(default|example\.)' | sed 's/^/  /' >&2
    echo "Set LLM_STACK_HOST=<name> or create the file." >&2
    exit 1
fi

# shellcheck disable=SC1091
source "${REPO}/hosts/default.env"
# shellcheck disable=SC1090
source "${REPO}/hosts/${HOST}.env"

if [ -z "${MTP_AGENT_MODEL_DIR:-}" ]; then
    echo "llm-stack: hosts/${HOST}.env has no MTP_AGENT_* block" >&2
    echo "MTP agent profile is not configured on this host. See docs/profiles.md." >&2
    exit 2
fi

: "${MTP_AGENT_MODEL_FILE:?missing MTP_AGENT_MODEL_FILE in hosts/${HOST}.env}"
: "${MTP_AGENT_CTX_SIZE:?missing MTP_AGENT_CTX_SIZE in hosts/${HOST}.env}"
: "${THREADS:?missing THREADS in hosts/${HOST}.env}"

MODEL_PATH="${MTP_AGENT_MODEL_DIR}/${MTP_AGENT_MODEL_FILE}"
if [ ! -f "${MODEL_PATH}" ]; then
    echo "llm-stack: model not found at ${MODEL_PATH}" >&2
    echo "Run: ${REPO}/bin/models qwen3.6-27b-agent-mtp" >&2
    exit 1
fi

# MTP_EXTRA_AGENT_FLAGS takes precedence; falls back to EXTRA_AGENT_FLAGS
# if a host doesn't bother with an MTP-specific set (e.g. macOS, where
# you don't need KV-quant to fit MTP in unified memory).
EXTRA_FLAGS="${MTP_EXTRA_AGENT_FLAGS:-${EXTRA_AGENT_FLAGS:-}}"

# shellcheck disable=SC2086
exec llama-server \
    --model "${MODEL_PATH}" \
    --alias qwen3.6-27b-agent \
    --host "${HOST_BIND}" \
    --port 11434 \
    --ctx-size "${MTP_AGENT_CTX_SIZE}" \
    --parallel 1 \
    --cache-ram "${CACHE_RAM}" \
    --n-gpu-layers 999 \
    --flash-attn on \
    --reasoning off \
    --temp 0.7 \
    --top-p 0.8 \
    --top-k 20 \
    --min-p 0.0 \
    --presence-penalty 1.5 \
    --repeat-penalty 1.0 \
    --threads "${THREADS}" \
    --spec-type draft-mtp \
    --spec-draft-n-max 2 \
    ${EXTRA_FLAGS} \
    --perf
