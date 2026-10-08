# ai-gateway-ops

> **Research site:** [CheckpointRouter — selective model routing for long-horizon agents](https://cs24mtech15016-oss.github.io/ai-gateway-ops/)

This repository also hosts a grounded research proposal for deciding **when** an agent
should reconsider its model and **which model** should execute the next phase. The static,
dependency-free site lives in [`docs/`](docs/) and is deployed through GitHub Pages.

A self-hosted LLM gateway: [**LiteLLM**](https://docs.litellm.ai) as the OpenAI-compatible
front door, routing to open-weight models served locally by [**Ollama**](https://ollama.com)
on Apple Silicon (Metal GPU).

```
                       ┌─────────────────────────────┐
   OpenAI-compatible   │          LiteLLM            │      Ollama on the Mac host
   clients  ─────────► │  proxy / router (:4000)     │────► (Metal GPU, :11434)
   (SDKs, curl, apps)  │  auth · keys · spend · LB   │        ├─ qwen2.5:7b
                       │  + Auto Router              │        └─ llama3.1:8b
                       └──────────┬──────────────────┘
                                  │  Postgres (keys/spend)
                                  │  Redis    (routing)
                                  └── (Docker Compose)
```

## Why this shape (and why not vLLM here)

vLLM's Docker image is CUDA/NVIDIA-only and macOS has no GPU passthrough, so on this
laptop vLLM can only run CPU-from-source (slow). GPU-accelerated local inference on
Apple Silicon goes through Metal — so **Ollama runs natively on the host** and gets the
GPU, while **LiteLLM + Postgres + Redis run in Docker** and reach Ollama over
`host.docker.internal`. LiteLLM stays the single front door: one endpoint, virtual API
keys, spend limits, logging, load balancing, and an Auto Router — clients never touch
Ollama directly.

> Deploying to a real NVIDIA GPU host later? Swap the Ollama backends in
> `litellm/config.yaml` for `openai/`-prefixed vLLM endpoints; nothing else changes.

## Requirements

- macOS on Apple Silicon (built/tested on M2 Max, 64 GB)
- Docker Desktop
- Ollama: `brew install ollama && brew services start ollama`

## Quick start

```bash
make init                 # creates .env from the template
# edit .env: set LITELLM_MASTER_KEY (sk-...) and LITELLM_SALT_KEY
make models               # pulls qwen2.5:7b + llama3.1:8b via Ollama
make up                   # starts LiteLLM + Postgres + Redis
make health               # confirm the gateway is up and list models
make test                 # chat completion through the load-balanced "chat" alias
make test-router          # request through the Auto Router
```

## Models & what fits your 64 GB M2 Max

| Ollama tag | Params | ~RAM (Q4) | Notes |
|---|---|---|---|
| `qwen2.5:7b` *(installed)* | 7B | ~5 GB | Fast, great default |
| `llama3.1:8b` *(installed)* | 8B | ~5 GB | Strong general model |
| `qwen2.5:14b` | 14B | ~9 GB | Fast, noticeably smarter |
| `qwen2.5:32b` | 32B | ~20 GB | Comfortable sweet spot |
| `llama3.3:70b` | 70B | ~40 GB | Runs, but ~5–8 tok/s (ceiling) |

7B–32B is the comfortable range; 70B is the practical ceiling.

## Model names exposed by the gateway

| Request `model:` | Routes to |
|---|---|
| `qwen2.5-7b` | Ollama `qwen2.5:7b` |
| `llama-3.1-8b` | Ollama `llama3.1:8b` |
| `chat` | Load-balanced across both |
| `smart-router` | **Auto Router** — picks a model from prompt complexity |

## Auto Router

`smart-router` (in `litellm/config.yaml`) uses LiteLLM's Auto Router. The default
**heuristic** classifier scores each prompt locally (no extra API calls) into a tier and
routes to the model mapped for that tier:

```yaml
tiers:
  SIMPLE:    qwen2.5-7b      # short / trivial -> fast small model
  MEDIUM:    qwen2.5-7b
  COMPLEX:   llama-3.1-8b    # multi-step / technical -> stronger model
  REASONING: llama-3.1-8b
```

Point more tiers at a bigger model (e.g. pull `qwen2.5:32b`, add it to `model_list`, and
map `COMPLEX`/`REASONING` to it) to trade latency for quality. Auto Router is **beta**
(LiteLLM ≥ v1.94) — config keys may shift between releases.

## Using it

```python
from openai import OpenAI
client = OpenAI(base_url="http://localhost:4000", api_key="sk-...")  # LITELLM_MASTER_KEY

resp = client.chat.completions.create(
    model="smart-router",                       # or qwen2.5-7b / llama-3.1-8b / chat
    messages=[{"role": "user", "content": "Hello!"}],
)
print(resp.choices[0].message.content)
```

Admin UI (virtual keys, spend): **http://localhost:4000/ui**

## Benchmarking with Terminal-Bench (Harbor)

[Terminal-Bench](https://github.com/harbor-framework/terminal-bench) evaluates agents on
real terminal tasks. It runs via the **Harbor** harness (`harbor` CLI, installed with `uv`),
executes each task in a **Docker sandbox**, and uses **LiteLLM** for model calls — so it
points straight at this gateway.

```bash
make install-harbor       # uv tool install harbor  (also done by `make setup`)
make bench-smoke          # validate harbor + Docker with the oracle agent (no model)
make bench                # terminus-2 agent driving your local gateway model
make bench-view           # browse results
```

How it's wired: the Harbor agent (`terminus-2`) runs on the **host** and reaches the gateway
at `http://localhost:4000/v1` via `OPENAI_API_KEY` + `OPENAI_API_BASE`; the model name is
`openai/<gateway-model>` (e.g. `openai/qwen2.5-7b`, or `openai/smart-router` to benchmark the
Auto Router). Tasks run in Docker; the gateway forwards to Ollama on Metal.

Tunables (override on the command line):

| Var | Default | Meaning |
|---|---|---|
| `BENCH_MODEL` | `openai/qwen2.5-7b` | Gateway model to benchmark (`openai/<name>`) |
| `BENCH_AGENT` | `terminus-2` | Harbor agent |
| `BENCH_TASKS` | `3` | Max tasks (`-l`); full set is 100+ |
| `BENCH_CONCURRENCY` | `2` | Parallel trials (`-n`) |

```bash
make bench BENCH_MODEL=openai/llama-3.1-8b BENCH_TASKS=5 BENCH_CONCURRENCY=1
```

> Reality check: small local models (7–8B) score near 0 on Terminal-Bench — the tasks are hard
> (frontier models land ~30–50%). The point here is a working local eval loop, not a high score.
> Each task runs a full agent loop, so expect several minutes per task on a laptop.

## Benchmarking LLM routing (LLMRouterBench)

[LLMRouterBench](https://github.com/ynulihao/LLMRouterBench) (arXiv 2601.07206) evaluates
LLM *routing* algorithms — the same idea as this gateway's Auto Router — over pre-collected
outputs from 33 models across 21 datasets. Model inference is offline; the only live call is
**embeddings**, which run on the same local Ollama this gateway uses.

```bash
make router-bench         # clones the repo, downloads data, trains + scores a router
make router-bench-clean   # remove the checkout + data
```

`benchmarks/router-bench.sh` is self-contained and idempotent: it clones a pinned upstream
commit into `.router-bench/` (git-ignored), sets up a venv, downloads the ~6.5 GB
pre-collected dataset, applies two local-compat patches, and trains the **AvengersPro** cluster
router — reporting its accuracy on the held-out split.

Tunables (env vars): `EMBED_MODEL` / `EMBED_URL` (default `nomic-embed-text` @ Ollama),
`SEED`, `SPLIT`, `SKIP_ANALYSIS=1` (skip the slow Oracle/baseline tables), `BENCH_HOME`.

> Reality check: with local `nomic-embed-text` embeddings the router lands ~70% (above the best
> single model ~67% and Random ~49%), confirming the pipeline. Absolute numbers won't match the
> paper's leaderboard, which uses `gte_Qwen2-7B-instruct` — point `EMBED_MODEL`/`EMBED_URL` at a
> hosted gte/Qwen endpoint to reproduce it exactly.

## Adding a model

1. `ollama pull <model>` (and add it to `MODELS` in the `Makefile`).
2. Add a `model_list` entry in `litellm/config.yaml` with `model: ollama_chat/<model>`.
3. `make up` to reload.

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | LiteLLM + Postgres + Redis (Ollama runs on the host) |
| `litellm/config.yaml` | Model routing, load balancing, Auto Router, gateway settings |
| `.env.example` | Config template (keys) |
| `Makefile` | One-click `make setup`, plus `up / health / test / bench` |
| `jobs/` | Terminal-Bench run results (git-ignored) |

## Requirements (full)

- macOS Apple Silicon, Docker Desktop, Ollama (`brew install ollama`)
- [`uv`](https://docs.astral.sh/uv/) — for the Harbor / Terminal-Bench CLI (benchmarks only)
