# ai-gateway-ops — LiteLLM + Ollama gateway, with Terminal-Bench (Harbor) benchmarks.
#
# One-click:  make setup   (installs everything + starts the gateway)
#             make bench    (runs the benchmark against the local gateway)

.PHONY: help setup up down logs ps health test test-router \
        models install-ollama install-harbor \
        bench bench-smoke bench-view bench-clean \
        router-bench router-bench-clean clean

# --- Models served by Ollama ---
MODELS := qwen2.5:7b llama3.1:8b

# --- Benchmark config (override on the CLI, e.g. `make bench BENCH_TASKS=5`) ---
DATASET          ?= terminal-bench/terminal-bench@latest
BENCH_AGENT      ?= terminus-2
BENCH_MODEL      ?= openai/qwen2.5-7b   # openai/<gateway-model-name>; also try openai/smart-router
BENCH_TASKS      ?= 3                   # max tasks to run (-l); the full set is 100+
BENCH_CONCURRENCY?= 2                   # parallel trials (-n); keep low for a laptop
JOBS_DIR         ?= jobs

# harbor + ollama install to ~/.local/bin and Homebrew; make them findable.
export PATH := $(HOME)/.local/bin:/opt/homebrew/bin:$(PATH)
KEY = $$(grep LITELLM_MASTER_KEY .env | cut -d= -f2)

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-16s %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# One-click setup
# ---------------------------------------------------------------------------
setup: install-ollama models install-harbor .env up ## One-click: install deps, pull models, start the gateway
	@echo
	@echo "✅ Gateway up on http://localhost:4000  (UI: /ui)"
	@echo "   Try:  make test   |   make test-router   |   make bench"

.env: ## Create .env with generated keys if missing
	@test -f .env || { \
	  cp .env.example .env; \
	  python3 -c "import pathlib,secrets; p=pathlib.Path('.env'); t=p.read_text(); \
t=t.replace('LITELLM_MASTER_KEY=sk-change-me','LITELLM_MASTER_KEY=sk-'+secrets.token_hex(24)); \
t=t.replace('LITELLM_SALT_KEY=change-me','LITELLM_SALT_KEY='+secrets.token_hex(24)); \
p.write_text(t)"; \
	  echo "Generated .env with random keys."; }

install-ollama: ## Install Ollama (Homebrew) and start it as a service
	@command -v ollama >/dev/null || { echo "==> installing ollama"; brew install ollama; }
	@brew services list | grep -q "ollama.*started" || { echo "==> starting ollama"; brew services start ollama; sleep 3; }
	@curl -sf http://localhost:11434/api/version >/dev/null && echo "ollama running" || { echo "ollama not responding on :11434"; exit 1; }

models: ## Pull the Ollama models used by the gateway
	@for m in $(MODELS); do echo "==> pulling $$m"; ollama pull $$m; done

install-harbor: ## Install the Harbor / Terminal-Bench CLI (via uv)
	@command -v uv >/dev/null || { echo "uv required: https://docs.astral.sh/uv/getting-started/installation/"; exit 1; }
	@command -v harbor >/dev/null || { echo "==> installing harbor"; uv tool install harbor; }
	@harbor --version

# ---------------------------------------------------------------------------
# Gateway stack (LiteLLM + Postgres + Redis; Ollama runs on the host)
# ---------------------------------------------------------------------------
up: ## Start the gateway stack
	docker compose up -d

down: ## Stop the stack
	docker compose down

logs: ## Tail logs (make logs S=litellm)
	docker compose logs -f $(S)

ps: ## Show container status
	docker compose ps

health: ## Check the gateway is up and list served models
	curl -s http://localhost:4000/health/liveliness && echo
	curl -s http://localhost:4000/v1/models -H "Authorization: Bearer $(KEY)" | python3 -m json.tool

test: ## Chat completion through the load-balanced "chat" alias
	curl -s http://localhost:4000/v1/chat/completions \
	  -H "Authorization: Bearer $(KEY)" -H "Content-Type: application/json" \
	  -d '{"model":"chat","messages":[{"role":"user","content":"Say hello in one sentence."}]}' \
	  | python3 -m json.tool

test-router: ## Request through the Auto Router ("smart-router")
	curl -s http://localhost:4000/v1/chat/completions \
	  -H "Authorization: Bearer $(KEY)" -H "Content-Type: application/json" \
	  -d '{"model":"smart-router","messages":[{"role":"user","content":"Write a Python function to merge two sorted lists and analyze its complexity."}]}' \
	  | python3 -m json.tool

# ---------------------------------------------------------------------------
# Terminal-Bench (Harbor) — runs against the LOCAL gateway
#
# The Harbor agent runs on the HOST, so it reaches the gateway at localhost:4000
# using standard LiteLLM env vars. Tasks execute in Docker sandboxes.
# ---------------------------------------------------------------------------
bench-smoke: ## Validate harbor+Docker with the oracle agent (no model needed)
	harbor run -d $(DATASET) -l 1 -a oracle -n 1 -o $(JOBS_DIR) -y

bench: ## Run the benchmark: terminus-2 agent + local gateway model
	OPENAI_API_KEY="$(KEY)" OPENAI_API_BASE="http://localhost:4000/v1" \
	harbor run -d $(DATASET) -l $(BENCH_TASKS) \
	  -a $(BENCH_AGENT) -m $(BENCH_MODEL) \
	  -n $(BENCH_CONCURRENCY) -o $(JOBS_DIR) -y

bench-view: ## Open the interactive results viewer
	harbor view $(JOBS_DIR)

bench-clean: ## Delete benchmark job results
	rm -rf $(JOBS_DIR)

# ---------------------------------------------------------------------------
# LLMRouterBench — offline LLM-routing benchmark, embeddings via local Ollama
# ---------------------------------------------------------------------------
router-bench: ## Run LLMRouterBench locally (clones repo, ~6.5 GB data on first run)
	./benchmarks/router-bench.sh

router-bench-clean: ## Delete the local LLMRouterBench checkout + data
	rm -rf .router-bench

clean: ## Stop the stack and remove volumes (deletes the LiteLLM DB!)
	docker compose down -v
