#!/usr/bin/env bash
# Qwen3.6-35B-A3B (MoE, ~3B active params/token), Thinking / vision profile
# for agentic coding (OpenCode, Claude Code, etc.).
#
# Endpoint: http://${HOST_BIND}:1235/v1   (OpenAI-compatible)
# Served alias: qwen3.6-35b-a3b
#
# Vision tower (mmproj) is loaded so multimodal coding flows work.
# `preserve_thinking` keeps <think> traces accessible to clients that echo
# them back across turns (DeepSeek-style). See docs/profiles.md.
#
# Sampler: Unsloth's Qwen3 thinking preset
# (temp 1.0, top-p 0.95, top-k 20, presence-penalty 1.5).
#
# Required env (from hosts/${LLM_STACK_HOST}.env):
#   THINKING_MODEL_DIR, THINKING_MODEL_FILE, THINKING_MMPROJ_FILE,
#   THINKING_CTX_SIZE, THREADS
#
# Exits: 1 if host config or model files missing; 2 if the host has no
#        THINKING_* block (thinking profile not enabled on this host).

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

if [ -z "${THINKING_MODEL_DIR:-}" ]; then
    echo "llm-stack: hosts/${HOST}.env has no THINKING_* config" >&2
    echo "This host doesn't run the thinking profile. See docs/profiles.md." >&2
    exit 2
fi

: "${THINKING_MODEL_FILE:?missing THINKING_MODEL_FILE in hosts/${HOST}.env}"
: "${THINKING_MMPROJ_FILE:?missing THINKING_MMPROJ_FILE in hosts/${HOST}.env}"
: "${THINKING_CTX_SIZE:?missing THINKING_CTX_SIZE in hosts/${HOST}.env}"
: "${THREADS:?missing THREADS in hosts/${HOST}.env}"

MODEL_PATH="${THINKING_MODEL_DIR}/${THINKING_MODEL_FILE}"
MMPROJ_PATH="${THINKING_MODEL_DIR}/${THINKING_MMPROJ_FILE}"

if [ ! -f "${MODEL_PATH}" ] || [ ! -f "${MMPROJ_PATH}" ]; then
    echo "llm-stack: missing files in ${THINKING_MODEL_DIR}" >&2
    [ ! -f "${MODEL_PATH}" ]  && echo "  ${THINKING_MODEL_FILE}"  >&2
    [ ! -f "${MMPROJ_PATH}" ] && echo "  ${THINKING_MMPROJ_FILE}" >&2
    echo "Run: ${REPO}/bin/models qwen3.6-35b-a3b-thinking" >&2
    exit 1
fi

exec llama-server \
    --model "${MODEL_PATH}" \
    --mmproj "${MMPROJ_PATH}" \
    --alias qwen3.6-35b-a3b \
    --host "${HOST_BIND}" \
    --port 1235 \
    --ctx-size "${THINKING_CTX_SIZE}" \
    --n-gpu-layers 999 \
    --flash-attn on \
    --reasoning on \
    --reasoning-format deepseek \
    --chat-template-kwargs '{"preserve_thinking":true}' \
    --image-min-tokens 1024 \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 20 \
    --min-p 0.0 \
    --presence-penalty 1.5 \
    --threads "${THREADS}" \
    --perf
