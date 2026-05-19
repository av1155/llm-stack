# llm-stack docs

`profiles.md`, `sampler-rationale.md`, and `references.md` cover the currently shipped Qwen3.6 profiles. Future profiles (other open-weights models) get their own additions to these docs.

| Doc | What it covers |
|---|---|
| [`profiles.md`](profiles.md) | Why 27B dense for tool-calling, why 35B-A3B MoE for thinking and coding. Per-profile rationale carried over from the original launcher comments. |
| [`sampler-rationale.md`](sampler-rationale.md) | The Unsloth sampler preset blocks (Instruct vs Thinking) and why those exact values. |
| [`setup-wsl-cuda.md`](setup-wsl-cuda.md) | Reproducing the WSL2 + RTX 5090 (Blackwell) setup from scratch. |
| [`setup-macos-metal.md`](setup-macos-metal.md) | Reproducing the macOS + Apple Silicon (Metal) setup from scratch. |
| [`vram-tuning.md`](vram-tuning.md) | Tradeoffs for `--ctx-size`, KV-cache quantization, `--fit-target`. |
| [`references.md`](references.md) | Canonical external links (Unsloth docs, HF model pages, relevant llama.cpp guidance). |
