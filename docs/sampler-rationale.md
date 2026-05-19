# Sampler rationale

Both profiles use Unsloth's published per-mode presets verbatim. See [`references.md`](references.md) for the upstream doc URL.

## Instruct / non-thinking (`qwen3.6-27b-agent`)

```
--temp 0.7
--top-p 0.8
--top-k 20
--min-p 0.0
--presence-penalty 1.5
--repeat-penalty 1.0
```

Tuned for tool-calling and agent flows: low temperature to keep JSON arguments deterministic, modest presence-penalty to avoid the model getting stuck repeating tool calls, top-k 20 to constrain token choice tightly.

## Thinking (`qwen3.6-35b-a3b-thinking`)

```
--temp 1.0
--top-p 0.95
--top-k 20
--min-p 0.0
--presence-penalty 1.5
```

Higher temperature + top-p to let the model explore reasoning paths during the `<think>` block. The same top-k and presence-penalty values still apply outside the think tags.

## Why these exact values

These are Unsloth's recommendations per their Qwen3.6 GGUF cards. Deviating from them tends to cause one of two failures:

- Lower temp/top-p → repetition loops, especially in long Deep runs.
- Higher temp/top-p → JSON argument corruption in tool calls.

The presence-penalty of 1.5 is unusually high; that's intentional to combat the SSM layers' tendency to drift into preferred-token attractors over long contexts.

## What stays at default

- `--top-n-sigma`, `--xtc-*`, `--dry-*`, `--mirostat*` — all disabled (Unsloth doesn't recommend them for Qwen3.6).
- `--typical-p` — disabled (1.0).
