# VRAM and context tuning

llama.cpp's boot-time fit logic prints a memory breakdown like:

```
common_memory_breakdown_print: | memory breakdown [MiB] | total    free     self   model   context   compute    unaccounted |
common_memory_breakdown_print: |   - CUDA0 (RTX 5090)   | 32606 = 30777 + (29938 = 23150 +    6293 +     495) +      -28109 |
```

Read it as: `total = free + (self = model + context + compute) + unaccounted`. The interesting numbers for tuning are **model**, **context**, and **compute**; **free** is what's left for the OS + other apps.

## Where memory goes

- **Model**: roughly the GGUF file size. Q6_K_XL of 27B is ~23 GiB; Q4_K_XL of 35B-A3B is ~17 GiB.
- **Context (KV cache)**: scales linearly with `--ctx-size`. For Qwen3.6 with default FP16 KV, the per-token cost is ~64 KiB per layer per token; at 98K context that's ~6 GiB.
- **Compute buffer**: small (~500 MiB), driven by `--batch-size` and `--ubatch-size`. Leave at defaults.

## Knobs that actually move the needle

### `--ctx-size`

The biggest VRAM lever. Cut it in half → KV cache halves. Andrea-PC runs `--ctx-size 98304` because the trained 262144 won't fit. macOS runs `--ctx-size 131072` for the agent profile and the full `--ctx-size 262144` for thinking.

If you hit OOM mid-generation, drop ctx by ~16K and try again. Past the model's trained context, you also lose quality regardless of fit.

### `--cache-type-k` and `--cache-type-v`

Quantize the KV cache. `q8_0` halves the KV footprint at near-zero quality cost. `q4_0` halves again at noticeable quality cost. Default is `f16`.

```
--cache-type-k q8_0 --cache-type-v q8_0
```

Worth it on Andrea-PC if you ever want to bump ctx-size back up.

### `--fit-target N`

Free-VRAM safety margin in MiB. Default 1024. llama.cpp's `-fit on` (default) tries to reduce other knobs until at least this much VRAM is free. If your fit prints `cannot meet free memory target of 1024 MiB, need to reduce device memory by N MiB`, lower `--fit-target` to a value that accepts the actual headroom. Andrea-PC uses 256.

### `--n-gpu-layers`

Pin all layers to GPU with `999`. Lower values offload tail layers to CPU (slow). Only useful when the model doesn't fit at any ctx-size.

## Recommended starting points

| Host | Profile | ctx | KV type | n-gpu-layers |
|---|---|---|---|---|
| 24 GB VRAM (3090/4090) | 27B-agent | 65536 | f16 | 999 |
| 32 GB VRAM (5090) | 27B-agent | 98304 | f16 | 999 |
| 32 GB VRAM (5090) | 35B-thinking | 65536 | q8_0 | 999 |
| 64 GB unified (M4 Max) | either | 131072+ | f16 | 999 |

If you find yourself dropping `n-gpu-layers` below 999 to fit, take a quant level down (Q4_K_XL → Q3_K_M) instead — partial CPU offload murders throughput.
