# Setup: WSL2 + NVIDIA CUDA

Reproduce the Andrea-PC stack from scratch. Tested with RTX 5090 (Blackwell, SM 120). The procedure works for any CUDA arch 7.5 or higher; set `CUDA_ARCH` accordingly.

## Hardware and OS assumptions

- Windows 11 host with NVIDIA GPU.
- WSL2 + Ubuntu 24.04 (`wsl --install -d Ubuntu`).
- Recent NVIDIA GeForce driver installed on the Windows host. The CUDA toolkit on the WSL side does NOT install drivers; the host driver carries through via `/dev/dxg`.

## One-shot install

After Ubuntu first-run setup:

```bash
git clone https://github.com/av1155/llm-stack.git ~/llm-stack
~/llm-stack/install.sh
```

`install.sh` runs `platform/linux-cuda/bootstrap.sh`, which installs only what's missing:

1. CUDA toolkit 12.9 (`cuda-toolkit-12-9` from the NVIDIA WSL repo). 12.x is the Blackwell-supported line per NVIDIA's [Blackwell migration guide](https://forums.developer.nvidia.com/t/software-migration-guide-for-nvidia-blackwell-rtx-gpus-a-guide-to-cuda-12-8-pytorch-tensorrt-and-llama-cpp/321330); 13.1/13.2 have known kernel bugs on Blackwell (gibberish output on certain quants, cuBLAS FP4 scaling regression) — avoid until 13.3+ ships the documented fix.
2. Build deps (`build-essential cmake git ccache ninja-build libcurl4-openssl-dev libssl-dev pkg-config`).
3. `hf` (the Hugging Face CLI, from `huggingface_hub[cli]`) via `pipx`.
4. `~/llama.cpp/` cloned from `ggml-org/llama.cpp`.
5. CUDA-enabled build with these CMake flags:
   ```
   -DGGML_CUDA=ON
   -DCMAKE_CUDA_ARCHITECTURES=120         # Blackwell; override CUDA_ARCH env for other cards
   -DGGML_CUDA_F16=ON
   -DGGML_CUDA_FA_ALL_QUANTS=ON
   ```

It then writes an idempotent block to `~/.bashrc` setting `LLM_STACK_HOME`, `LLM_STACK_HOST`, and the `qwen-agent` / `llama-update` aliases.

## What each CMake flag does

| Flag | Effect |
|---|---|
| `GGML_CUDA=ON` | Enables the CUDA backend. |
| `CMAKE_CUDA_ARCHITECTURES=120` | Native cubin for SM 12.0 (Blackwell / RTX 5090); cmake auto-rewrites to `120a-real`, unlocking `BLACKWELL_NATIVE_FP4`. |
| `GGML_CUDA_F16=ON` | FP16 intermediates in CUDA kernels. |
| `GGML_CUDA_FA_ALL_QUANTS=ON` | Compile flash-attention kernels for every quant type (matters for Q4/Q5/Q6 GGUFs). |

Confirm the server banner reports `ARCHS = 1200 | FA_ALL_QUANTS = 1 | BLACKWELL_NATIVE_FP4 = 1` after first boot.

## Download models

```bash
~/llm-stack/bin/models qwen3.6-27b-agent      # 27B dense Q6_K_XL (~24 GiB)
# Skip the thinking profile on Andrea-PC unless you also do agentic coding here.
```

## Verify

```bash
qwen-agent &
sleep 30
curl -s http://127.0.0.1:11434/v1/models | jq
curl -s http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3.6-27b-agent","messages":[{"role":"user","content":"Say exactly: hello world"}],"max_tokens":20}' | jq
```

## VRAM math at this profile

See [`vram-tuning.md`](vram-tuning.md). On the 5090:

```
Total VRAM:  32606 MiB
Model:       23150 MiB  (27B Q6_K_XL)
Context:      6293 MiB  (98K ctx, FP16 KV)
Compute:       495 MiB
---
Free:         2668 MiB
```

`--fit-target 256` is in `hosts/andrea-pc.env`'s `EXTRA_AGENT_FLAGS` to silence the boot-time "cannot meet free memory target of 1024 MiB" warning at this ratio.
