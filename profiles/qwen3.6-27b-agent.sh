#!/usr/bin/env bash
# Qwen3.6-27B (dense), Instruct / non-thinking / tool-calling profile.
#
# Endpoint: http://${HOST_BIND}:11434/v1   (OpenAI-compatible)
# Served alias: qwen3.6-27b-agent
#
# Used by TradingAgents and other tool-calling clients. See docs/profiles.md
# for the rationale of choosing 27B dense over 35B-A3B MoE for agentic flows.
#
# Sampler: Unsloth's published Qwen3 non-thinking preset
# (temp 0.7, top-p 0.8, top-k 20, presence-penalty 1.5).
# See docs/sampler-rationale.md and https://unsloth.ai/docs/models/qwen3.6.
#
# Required env (from hosts/${LLM_STACK_HOST}.env):
#   AGENT_MODEL_DIR, AGENT_MODEL_FILE, AGENT_CTX_SIZE, THREADS
#
# Exits: 1 if host config missing or model file not found.

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

: "${AGENT_MODEL_DIR:?missing AGENT_MODEL_DIR in hosts/${HOST}.env}"
: "${AGENT_MODEL_FILE:?missing AGENT_MODEL_FILE in hosts/${HOST}.env}"
: "${AGENT_CTX_SIZE:?missing AGENT_CTX_SIZE in hosts/${HOST}.env}"
: "${THREADS:?missing THREADS in hosts/${HOST}.env}"

MODEL_PATH="${AGENT_MODEL_DIR}/${AGENT_MODEL_FILE}"
if [ ! -f "${MODEL_PATH}" ]; then
    echo "llm-stack: model not found at ${MODEL_PATH}" >&2
    echo "Run: ${REPO}/bin/models qwen3.6-27b-agent" >&2
    exit 1
fi

# shellcheck disable=SC2086
exec llama-server \
    --model "${MODEL_PATH}" \
    --alias qwen3.6-27b-agent \
    --host "${HOST_BIND}" \
    --port 11434 \
    --ctx-size "${AGENT_CTX_SIZE}" \
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
    ${EXTRA_AGENT_FLAGS:-} \
    --perf
