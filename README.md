# llm-stack

Personal cross-platform launch + maintenance stack for [Unsloth's Qwen3.6 GGUFs](https://unsloth.ai/docs/models/qwen3.6) running on [llama.cpp](https://github.com/ggml-org/llama.cpp). Runs on both Linux + NVIDIA CUDA (WSL2 or bare metal) and macOS + Apple Silicon (Metal) from one repo.

## What's in here

- **Profile scripts** for two well-tuned launch configurations:
  - `qwen3.6-27b-agent` (Instruct / tool-calling, port 11434) — for agentic tool callers like TradingAgents.
  - `qwen3.6-35b-a3b-thinking` (Thinking / vision / coding, port 1235) — for OpenCode and similar.
- **Per-host env files** that own the resource-side knobs (model path, ctx-size, threads, host bind, extra flags). The profile scripts are platform-agnostic.
- **Platform bootstraps** that handle the install:
  - Linux: CUDA toolkit + build-from-source llama.cpp with Blackwell-friendly flags.
  - macOS: `brew install llama.cpp` + `huggingface-cli`.
- **`bin/llama-update`** that knows the right refresh path per platform.
- **`bin/models`** that downloads the canonical model layout from Hugging Face into `~/models/`.
- **`docs/`** with the rationale, sampler presets, and tuning notes.

## Quickstart

```bash
git clone https://github.com/av1155/llm-stack.git ~/llm-stack
~/llm-stack/install.sh
```

`install.sh` detects the platform, runs the matching bootstrap, and writes an idempotent block to your shell rc (`~/.bashrc` on Linux, `~/.zshrc` on macOS). After opening a new shell:

```bash
qwen-agent          # Instruct / tool-calling server, port 11434
qwen                # Thinking / vision server, port 1235 (where configured)
llama-update        # refresh llama.cpp (source rebuild on Linux, brew on macOS)
```

Download models if they're not already present:

```bash
~/llm-stack/bin/models all
```

## Repo layout

```
llm-stack/
├── install.sh                              # top-level installer
├── bin/
│   ├── llama-update                        # cross-platform update dispatcher
│   └── models                              # HF-CLI model downloader
├── profiles/
│   ├── qwen3.6-27b-agent.sh                # Instruct / tool-calling profile
│   └── qwen3.6-35b-a3b-thinking.sh         # Thinking / vision profile
├── hosts/
│   ├── default.env                         # shared defaults
│   ├── andrea-pc.env                       # WSL2 + RTX 5090
│   ├── mac-m4-max.env                      # macOS + M4 Max
│   └── example.*.env                       # templates for new machines
├── platform/
│   ├── linux-cuda/{bootstrap,update}.sh
│   └── darwin-metal/{bootstrap,update}.sh
└── docs/                                   # see docs/README.md
```

## Adding a new host

```bash
cp hosts/example.linux-cuda.env hosts/myhost.env   # or example.macos-metal.env
$EDITOR hosts/myhost.env                            # set MODEL_DIR, CTX, THREADS, etc.
LLM_STACK_HOST=myhost ~/llm-stack/install.sh
```

## Adding a new profile

Drop a script in `profiles/` that sources `hosts/default.env` then `hosts/${LLM_STACK_HOST}.env` and execs `llama-server` with the right model and sampler. Use the existing profile scripts as templates. Then re-run `install.sh` to refresh aliases.

## License

MIT — see [`LICENSE`](LICENSE).
