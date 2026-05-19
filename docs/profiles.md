# Profiles

Two launch profiles, each tuned for a specific class of client.

## `qwen3.6-27b-agent`, Instruct and tool-calling

| Field | Value |
|---|---|
| Model | Qwen3.6-27B (dense) at Q6_K_XL (Unsloth GGUF) |
| Port | 11434 (canonical Ollama port; matches TradingAgents' hardcoded `ollama` provider entry) |
| Served alias | `qwen3.6-27b-agent` |
| Sampler | Unsloth's published Qwen3 non-thinking preset (`temp 0.7 / top-p 0.8 / top-k 20 / presence 1.5 / repeat 1.0`) |
| Reasoning | off |

### Why 27B dense over 35B-A3B MoE for this profile

- BenchLM agentic average 59.3 vs 51.5. 27B wins.
- Terminal-Bench 2.0 59.3 vs 51.5. SWE-bench Verified 77.2 vs 73.4.
- Q6_K_XL retains an order-of-magnitude lower KL-divergence vs BF16 than the 35B-A3B Q4_K_XL, so tool-call argument fidelity is better.
- Dense routing avoids the per-token expert variance that occasionally produces malformed JSON in MoE tool calls.

### Why `--reasoning off`

Clients that don't echo `reasoning_content` back across turns (e.g. langchain-openai's default function-calling path used by TradingAgents) leak `<think>` traces into tool arguments and break `tool_call` parsing. Instruct mode emits clean `tool_calls` only.

### Why `--parallel 1`

Qwen3.6 has hybrid SSM + attention layers whose recurrent state can't be shared via the prompt cache. With `--parallel 4`, every slot switch caused a full `forcing full prompt re-processing due to lack of cache data` reprefill, wasting 1-3 minutes per Deep run. TradingAgents is strictly sequential, so the extra slots provide no benefit, only thrash. Bump back to 2 or higher only if running multiple concurrent clients against this server.

### Why `--cache-ram 16384`

Doubles the upstream default (8 GiB) so long Deep runs stop hitting `cache size limit reached` and evicting useful checkpoints. Costs system RAM only (not VRAM); fits the budget on both machines.

## `qwen3.6-35b-a3b-thinking`, Thinking, vision, and coding

| Field | Value |
|---|---|
| Model | Qwen3.6-35B-A3B (MoE, ~3B active params per token) at Q4_K_XL |
| mmproj | `mmproj-F32.gguf` (vision tower from the same Unsloth HF repo) |
| Port | 1235 (deliberately not 11434, so it can co-exist with the agent server) |
| Served alias | `qwen3.6-35b-a3b` |
| Sampler | Unsloth's Qwen3 thinking preset (`temp 1.0 / top-p 0.95 / top-k 20 / presence 1.5`) |
| Reasoning | on, `--reasoning-format deepseek`, `--chat-template-kwargs '{"preserve_thinking":true}'` |

### Use case

Agentic coding harnesses (OpenCode, Claude Code, generic function-calling MCP setups) that benefit from chain-of-thought or vision input. The MoE's lower active-param count makes per-token latency competitive with much smaller dense models while preserving the larger model's reasoning depth.

### Why not enabled on Andrea-PC

Use case, not VRAM. 35B-A3B Q4_K_XL fits on the 5090 fine (~17-18 GiB weights plus KV cache). Andrea-PC is the TradingAgents workstation; agentic coding lives on the Mac. If you start doing coding on Windows, add a `THINKING_*` block to `hosts/andrea-pc.env` and the `qwen` alias becomes available after re-running `install.sh`.

## `qwen3.6-27b-agent-mtp`, MTP variant of the agent profile

| Field | Value |
|---|---|
| Model | Qwen3.6-27B (dense) at Q6_K_XL from `unsloth/Qwen3.6-27B-MTP-GGUF` |
| Port | 11434 (same as the non-MTP agent server; mutually exclusive at runtime) |
| Served alias | `qwen3.6-27b-agent` (so TradingAgents reaches it unchanged) |
| Sampler | Identical to the non-MTP agent profile |
| Reasoning | off |
| Extra flag | `--spec-type draft-mtp --spec-draft-n-max 2` |

### What MTP does

MTP (Multi-Token Prediction) is speculative decoding with rejection sampling. Draft heads built into the model weights propose N future tokens; the main model verifies them in parallel. Accepted tokens are emitted; rejected ones fall back to the main model's sampling. Output distribution is **identical to the non-MTP variant by construction**, not approximately equal. The speedup comes purely from amortizing forward passes.

### Speedup

Roughly 1.4x faster generation on dense Qwen3.6-27B per Unsloth's benchmarks at `--spec-draft-n-max 2`. Acceptance rate at N=2 hovers around 83% in their tests; raising N to 4 drops acceptance to ~50% and the speedup shrinks, which is why 2 is the recommended default. MoE models (Qwen3.6-35B-A3B) get a smaller 1.15-1.2x boost since per-token expert routing already amortizes some of what MTP would help.

### VRAM cost

MTP draft heads add ~1 GB of VRAM overhead beyond the base model. On Andrea-PC at ctx=98304, that's the difference between fitting and OOMing. Solution: pair MTP with KV cache quantization (`--cache-type-k q8_0 --cache-type-v q8_0`) in `MTP_EXTRA_AGENT_FLAGS`. The KV cache footprint halves (~6.3 GB → ~3.2 GB at this ctx), recovering ~3 GB. Quality cost of q8_0 KV is empirically near-zero on tool-calling workloads. Net: keep your full 98K context, gain the speedup, and end up with more headroom than the non-MTP setup.

### How to enable

1. Download the MTP weights: `~/llm-stack/bin/models qwen3.6-27b-agent-mtp` (~24 GB).
2. Confirm the host env file has the `MTP_AGENT_*` block (Andrea-PC ships with it filled in; copy from `hosts/example.linux-cuda.env` if needed).
3. Re-run `~/llm-stack/install.sh` so `install.sh` writes the `qwen-agent-mtp` alias.
4. Launch with `qwen-agent-mtp`. Same port (11434) so TradingAgents and other clients reach it identically.

The non-MTP `qwen-agent` alias stays available as a baseline. Only one can serve on 11434 at a time; stop one before starting the other.
