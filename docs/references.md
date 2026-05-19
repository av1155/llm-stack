# References

Source of truth for configuration decisions in this repo.

## Unsloth

- Canonical config guide: https://unsloth.ai/docs/models/qwen3.6. Covers sampler presets (instruct vs thinking), recommended quants, vision tower (mmproj) usage.
- 27B dense GGUF: https://huggingface.co/unsloth/Qwen3.6-27B-GGUF
- 35B-A3B MoE GGUF: https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF. `mmproj-F32.gguf` is the vision tower; F16 and BF16 variants also exist (smaller, less precise).

## llama.cpp

- Repo: https://github.com/ggml-org/llama.cpp
- Build docs: https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
- CUDA notes: see `ggml/src/ggml-cuda/CMakeLists.txt` for the architectures list. Blackwell SM 120a-real lands at CUDA 12.8 or higher.
- Releases (Windows / Docker): https://github.com/ggml-org/llama.cpp/releases. There are no Linux-CUDA prebuilts, which is why this repo source-builds.
- Blackwell migration: NVIDIA's [Software Migration Guide for Blackwell RTX GPUs](https://forums.developer.nvidia.com/t/software-migration-guide-for-nvidia-blackwell-rtx-gpus-a-guide-to-cuda-12-8-pytorch-tensorrt-and-llama-cpp/321330) (currently points users at CUDA 12.8 specifically).

## Hugging Face CLI

- Install: https://huggingface.co/docs/huggingface_hub/main/en/guides/cli
- `hf download` takes positional file args and is idempotent (checksum-checks before re-downloading). The CLI was renamed from `huggingface-cli` to `hf` upstream; the Homebrew formula and Python package both ship the old name as a backwards-compat shim.

## Background reading

- [SSM / hybrid-recurrent context cache limitation](https://github.com/ggml-org/llama.cpp/pull/13194#issuecomment-2868343055). Explains the `forcing full prompt re-processing due to lack of cache data` log line you'll see in Qwen3.6 multi-turn runs. Architectural limitation, not config-fixable without `--swa-full` (which trades VRAM).
- [`--cache-idle-slots` PR](https://github.com/ggml-org/llama.cpp/pull/16391). What `--kv-unified` unlocks; useful for variable-prompt agent workloads like TradingAgents.
