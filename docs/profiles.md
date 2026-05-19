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
