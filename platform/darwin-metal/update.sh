#!/usr/bin/env bash
# Refresh llama.cpp on macOS via Homebrew.
#
# Modes:
#   (no flag)    brew update + brew upgrade llama.cpp.
#   --reinstall  brew reinstall llama.cpp. Re-fetches the bottle and
#                re-links the formula even when the version hasn't moved.
#   --clean      brew reinstall + brew cleanup --prune=all llama.cpp.
#                Also drops cached bottles for the formula. Implies
#                --reinstall.

set -euo pipefail

REINSTALL=0
CLEAN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --reinstall)  REINSTALL=1 ;;
        --clean)      CLEAN=1; REINSTALL=1 ;;
        -h|--help)
            sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *)
            echo "llama-update: unknown flag: $1" >&2
            echo "run 'llama-update --help' to see valid flags" >&2
            exit 1 ;;
    esac
    shift
done

brew update

if [ "${REINSTALL}" = 1 ]; then
    brew reinstall llama.cpp
else
    brew upgrade llama.cpp
fi

if [ "${CLEAN}" = 1 ]; then
    brew cleanup --prune=all llama.cpp
fi
