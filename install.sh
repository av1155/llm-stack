#!/usr/bin/env bash
# llm-stack top-level installer.
#
# Detects the platform, runs the matching bootstrap, and writes an
# idempotent block to the user's shell rc that defines:
#   LLM_STACK_HOME   (path to this repo)
#   LLM_STACK_HOST   (which file in hosts/ to source at run-time)
#   PATH             (so bin/llama-update etc. are callable)
#   alias qwen-agent (Instruct, port 11434)
#   alias qwen       (Thinking, port 1235, only if configured)
#
# Re-running is safe. The block is rewritten in place via marker matching,
# so values change on disk but nothing duplicates.
#
# Exits: 0 on success; 1 on unsupported platform or missing host config.

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"

log()  { printf '[install] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

OS="$(uname -s)"
case "${OS}" in
    Linux)
        PLATFORM="linux-cuda"
        DEFAULT_HOST="andrea-pc"
        DEFAULT_RC="${HOME}/.bashrc"
        ;;
    Darwin)
        PLATFORM="darwin-metal"
        DEFAULT_HOST="mac-m4-max"
        DEFAULT_RC="${HOME}/.zshrc"
        ;;
    *)
        echo "install: unsupported platform: ${OS}" >&2
        exit 1
        ;;
esac

HOST="${LLM_STACK_HOST:-${DEFAULT_HOST}}"
if [ ! -f "${REPO}/hosts/${HOST}.env" ]; then
    echo "install: no host config at hosts/${HOST}.env" >&2
    echo "Copy one of the example files and adjust:" >&2
    echo "  cp hosts/example.${PLATFORM}.env hosts/${HOST}.env" >&2
    echo "Or run again with LLM_STACK_HOST=<existing-name>" >&2
    exit 1
fi
log "platform: ${PLATFORM}   host: ${HOST}"

log "running platform/${PLATFORM}/bootstrap.sh"
bash "${REPO}/platform/${PLATFORM}/bootstrap.sh"

RC="${LLM_STACK_RC:-${DEFAULT_RC}}"
log "shell rc: ${RC}"

BLOCK_MARKER_START="# >>> llm-stack >>>"
BLOCK_MARKER_END="# <<< llm-stack <<<"

# Only emit conditional aliases when the host actually configures the
# corresponding profile. Otherwise a typo would quietly launch a server
# that errors out.
HAS_THINKING=0
if grep -q '^THINKING_MODEL_DIR=' "${REPO}/hosts/${HOST}.env"; then
    HAS_THINKING=1
fi

HAS_MTP=0
if grep -q '^MTP_AGENT_MODEL_DIR=' "${REPO}/hosts/${HOST}.env"; then
    HAS_MTP=1
fi

THINKING_ALIAS=""
if [ "${HAS_THINKING}" = 1 ]; then
    THINKING_ALIAS='alias qwen="$LLM_STACK_HOME/profiles/qwen3.6-35b-a3b-thinking.sh"'
fi

MTP_ALIAS=""
if [ "${HAS_MTP}" = 1 ]; then
    MTP_ALIAS='alias qwen-agent-mtp="$LLM_STACK_HOME/profiles/qwen3.6-27b-agent-mtp.sh"'
fi

BLOCK="${BLOCK_MARKER_START}
export LLM_STACK_HOME=\"${REPO}\"
export LLM_STACK_HOST=\"${HOST}\"
export PATH=\"\$LLM_STACK_HOME/bin:\$PATH\"
alias qwen-agent=\"\$LLM_STACK_HOME/profiles/qwen3.6-27b-agent.sh\"
${MTP_ALIAS}
${THINKING_ALIAS}
alias llama-update=\"\$LLM_STACK_HOME/bin/llama-update\"
${BLOCK_MARKER_END}"

touch "${RC}"
if grep -qF "${BLOCK_MARKER_START}" "${RC}"; then
    log "updating existing llm-stack block in ${RC}"
    # Read via sed, write via cat-and-redirect. Avoids sed -i because:
    #   (1) BSD awk on macOS choked on -v multi-line values (old bug);
    #   (2) BSD sed -i refuses to edit symlinks, and the user's rc is
    #       a stow-managed symlink. cat > "${RC}" follows the symlink
    #       and writes through to the underlying file, preserving the
    #       link.
    TMP_RC="${RC}.llm-stack.tmp"
    sed "/^${BLOCK_MARKER_START}\$/,/^${BLOCK_MARKER_END}\$/d" \
        "${RC}" > "${TMP_RC}"
    cat "${TMP_RC}" > "${RC}"
    rm -f "${TMP_RC}"
fi
log "appending llm-stack block to ${RC}"
printf '\n%s\n' "${BLOCK}" >> "${RC}"

if have llama-server; then
    log "llama-server: $(llama-server --version 2>&1 | head -1)"
else
    log "WARNING: llama-server not on PATH yet. Open a new shell or 'source ${RC}'."
fi

cat <<EOF

[install] Done.

Next:
  - Open a new shell (or 'source ${RC}') to pick up aliases.
  - 'qwen-agent' starts the Instruct/tool-calling server on port 11434.
EOF

if [ "${HAS_MTP}" = 1 ]; then
    cat <<EOF
  - 'qwen-agent-mtp' starts the MTP variant on port 11434 (~1.4x faster).
EOF
fi

if [ "${HAS_THINKING}" = 1 ]; then
    cat <<EOF
  - 'qwen' starts the Thinking/vision server on port 1235.
EOF
fi

cat <<EOF
  - 'llama-update' refreshes llama.cpp (source rebuild on Linux, brew on macOS).
  - '\$LLM_STACK_HOME/bin/models all' downloads model GGUFs if they're missing.
EOF
