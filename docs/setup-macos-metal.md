# Setup: macOS + Apple Silicon (Metal)

Reproduce the MacBook stack from scratch. Tested on M4 Max with 64 GB unified memory.

## One-shot install

```bash
git clone https://github.com/av1155/llm-stack.git ~/llm-stack
~/llm-stack/install.sh
```

`install.sh` runs `platform/darwin-metal/bootstrap.sh`, which:

1. Verifies Homebrew is present (errors with the install link if not).
2. `brew install llama.cpp` (skips if already installed).
3. `brew install hf` for the Hugging Face CLI (skips if already installed).

It then writes an idempotent block to `~/.zshrc` setting `LLM_STACK_HOME`, `LLM_STACK_HOST`, the `qwen-agent` alias, the `qwen` alias (the thinking profile is configured on Mac), and `llama-update`.

## Download models

```bash
~/llm-stack/bin/models all
```

Downloads to `~/models/Qwen3.6-27B-GGUF/` and `~/models/Qwen3.6-35B-A3B-GGUF/`.

## If you already have the models via LM Studio

Skip the download and symlink the existing dirs into the canonical layout:

```bash
mkdir -p ~/models
ln -s ~/.cache/lm-studio/models/unsloth/Qwen3.6-27B-GGUF      ~/models/Qwen3.6-27B-GGUF
ln -s ~/.cache/lm-studio/models/unsloth/Qwen3.6-35B-A3B-GGUF  ~/models/Qwen3.6-35B-A3B-GGUF
```

LM Studio keeps seeing the models in its UI; `llm-stack` reads them from `~/models/`. No duplication.

## Verify

```bash
qwen-agent &                                          # port 11434
sleep 20
curl -s http://127.0.0.1:11434/v1/models | jq

qwen &                                                # port 1235 (thinking)
sleep 20
curl -s http://127.0.0.1:1235/v1/models | jq
```

## Update llama.cpp

```bash
llama-update    # brew upgrade llama.cpp
```

`brew` handles version pinning and rollback if needed.
