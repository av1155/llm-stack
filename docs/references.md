# References

Source of truth for configuration decisions in this repo.

## Unsloth

- **Canonical config guide**: https://unsloth.ai/docs/models/qwen3.6
  - Sampler presets (instruct vs thinking), recommended quants, vision tower (mmproj) usage.
- **27B dense GGUF**: https://huggingface.co/unsloth/Qwen3.6-27B-GGUF
- **35B-A3B MoE GGUF**: https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF
  - mmproj-F32.gguf for vision; F16 and BF16 variants also exist (smaller, less precise).

## llama.cpp

- **Repo**: https://github.com/ggml-org/llama.cpp
- **Build docs**: https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
- **CUDA notes**: see `ggml/src/ggml-cuda/CMakeLists.txt` for the architectures list (Blackwell SM 120a-real lands at CUDA ≥ 12.8).
- **Releases (Windows / Docker)**: https://github.com/ggml-org/llama.cpp/releases — note: no Linux-CUDA prebuilts; that's why this repo source-builds.
- **Blackwell migration**: NVIDIA's [Software Migration Guide for Blackwell RTX GPUs](https://forums.developer.nvidia.com/t/software-migration-guide-for-nvidia-blackwell-rtx-gpus-a-guide-to-cuda-12-8-pytorch-tensorrt-and-llama-cpp/321330) (currently points users at CUDA 12.8 specifically).

## Hugging Face CLI

- **Install**: https://huggingface.co/docs/huggingface_hub/main/en/guides/cli
- **`huggingface-cli download`**: takes positional file args, idempotent (checksum-checks before re-downloading).

## Background reading

- [SSM / hybrid-recurrent context cache limitation](https://github.com/ggml-org/llama.cpp/pull/13194#issuecomment-2868343055) — explains the `forcing full prompt re-processing due to lack of cache data` log line you'll see in Qwen3.6 multi-turn runs. Architectural limitation, not config-fixable without `--swa-full` (which trades VRAM).
- [`--cache-idle-slots` PR](https://github.com/ggml-org/llama.cpp/pull/16391) — what `--kv-unified` unlocks; useful for variable-prompt agent workloads like TradingAgents.
