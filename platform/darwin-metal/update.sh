#!/usr/bin/env bash
# Refresh llama.cpp on macOS via Homebrew.

set -euo pipefail

brew update
brew upgrade llama.cpp
