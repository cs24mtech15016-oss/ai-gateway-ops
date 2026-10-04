#!/usr/bin/env bash
# router-bench.sh — run LLMRouterBench locally against this Ollama setup.
#
# LLMRouterBench (arXiv 2601.07206) benchmarks LLM *routing* algorithms over
# pre-collected model outputs (33 models x 21 datasets). No model inference runs
# here — the only live call is embeddings, which we serve locally from Ollama
# (the same backend this gateway uses). One live model, fully offline otherwise.
#
# Self-contained: clones the upstream repo, sets up its venv, downloads the
# pre-collected data, applies the two local-compat patches, and trains the
# AvengersPro cluster router, printing its accuracy on the test split.
# Every step is idempotent — re-running skips work that's already done.
#
# Requirements:  uv (https://docs.astral.sh/uv), Ollama running on :11434, curl.
# Usage:
#   ./benchmarks/router-bench.sh                 # full pipeline (~6.5 GB download first run)
#   SKIP_ANALYSIS=1 ./benchmarks/router-bench.sh # skip the slow Oracle/baseline tables
#   BENCH_HOME=/path ./benchmarks/router-bench.sh # clone elsewhere (default: .router-bench/)
set -euo pipefail

# --- config (override via env) ---------------------------------------------
REPO_URL="${REPO_URL:-https://github.com/ynulihao/LLMRouterBench.git}"
REPO_REF="${REPO_REF:-c77cb0506949d8f959e97967d2fefca0e8ff1b05}"  # pinned; verified locally
SEED="${SEED:-42}"
SPLIT="${SPLIT:-0.7}"
EMBED_MODEL="${EMBED_MODEL:-nomic-embed-text}"
EMBED_URL="${EMBED_URL:-http://localhost:11434/v1}"   # Ollama's OpenAI-compatible endpoint
DATA_URL="https://huggingface.co/datasets/NPULH/LLMRouterBench/resolve/main/bench-release.tar.gz"

HERE="$(cd "$(dirname "$0")" && pwd)"
BENCH_HOME="${BENCH_HOME:-$HERE/../.router-bench/LLMRouterBench}"

ADAPTOR_DIR="baselines/AvengersPro/data/small_models_seed_${SEED}"
SPLIT_DIR="${ADAPTOR_DIR}/seed${SEED}_split${SPLIT}"
ROUTER_CFG="baselines/AvengersPro/config/local_ollama_seed_${SEED}.json"
ROUTER_OUT="baselines/AvengersPro/logs/local_ollama_seed_${SEED}.json"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

command -v uv   >/dev/null || die "uv not found — install from https://docs.astral.sh/uv/"
command -v curl >/dev/null || die "curl not found"

# --- 0. clone upstream ------------------------------------------------------
log "LLMRouterBench checkout ($BENCH_HOME)"
if [[ ! -d "$BENCH_HOME/.git" ]]; then
  mkdir -p "$(dirname "$BENCH_HOME")"
  git clone "$REPO_URL" "$BENCH_HOME"
  git -C "$BENCH_HOME" checkout "$REPO_REF"
else
  echo "Already cloned — skipping."
fi
cd "$BENCH_HOME"

# --- 1. venv + deps ---------------------------------------------------------
log "Python environment"
if [[ ! -x .venv/bin/python ]]; then
  uv venv --python 3.12 .venv
  uv pip install -r requirements.txt
  uv pip install matplotlib seaborn joblib   # extra deps for the AvengersPro baseline
fi
PY=.venv/bin/python
"$PY" -c "import loguru, pandas, sklearn" 2>/dev/null || {
  log "Installing missing deps"
  uv pip install -r requirements.txt
  uv pip install matplotlib seaborn joblib
}

# --- 2. benchmark data ------------------------------------------------------
log "Benchmark data (results/bench)"
if [[ ! -d results/bench ]]; then
  mkdir -p results
  ( cd results
    echo "Downloading pre-collected model outputs (~1.28 GB, extracts to ~6.5 GB)…"
    curl -fL "$DATA_URL" -o bench-release.tar.gz
    tar xzf bench-release.tar.gz
    mv bench-release bench                    # config/baseline_config.yaml expects results/bench
    rm -f bench-release.tar.gz )
else
  echo "results/bench present — skipping download."
fi

# --- 3. local-compat patches ------------------------------------------------
# pandas >= 2.1 rejects assigning formatted strings into float columns
# (LossySetitemError). Cast the display frames to object dtype. Idempotent.
log "pandas 3.x compatibility patch"
if grep -q "perf_df.copy().astype(object)" baselines/aggregators.py; then
  echo "Already patched."
else
  sed -i.bak \
    -e 's/perf_display = perf_df\.copy()/perf_display = perf_df.copy().astype(object)/' \
    -e 's/cost_display = cost_df\.copy()/cost_display = cost_df.copy().astype(object)/' \
    baselines/aggregators.py
  rm -f baselines/aggregators.py.bak
  echo "Patched baselines/aggregators.py."
fi

# --- 4. local embeddings via Ollama ----------------------------------------
log "Embedding model on Ollama ($EMBED_MODEL @ $EMBED_URL)"
if command -v ollama >/dev/null; then
  curl -sf http://localhost:11434/api/tags >/dev/null 2>&1 \
    || die "Ollama not responding on :11434 — start it (brew services start ollama)"
  ollama list 2>/dev/null | grep -q "^${EMBED_MODEL}" || ollama pull "$EMBED_MODEL"
else
  echo "WARNING: ollama CLI not found; assuming an embedding endpoint at $EMBED_URL"
fi

# --- 5. router config (local embeddings, seed data paths) -------------------
log "Router config ($ROUTER_CFG)"
"$PY" - "$ROUTER_CFG" "$SPLIT_DIR" "$EMBED_MODEL" "$EMBED_URL" <<'PYEOF'
import json, sys, pathlib
cfg_path, split_dir, model, url = sys.argv[1:5]
cfg = {
    "train_data_path": f"{split_dir}/train.jsonl",
    "test_data_path": f"{split_dir}/test.jsonl",
    "baseline_scores_path": f"{split_dir}/baseline_scores.json",
    "n_clusters": 30, "seed": 42, "max_router": 1, "top_k": 1, "beta": 9.0,
    "max_workers": 8, "cluster_batch_size": 1000,
    "embedding_model": model,
    "embedding_base_url": url,
    "embedding_api_key": "ollama",
    "embedding_config_path": None,
    "excluded_models": [], "ood_datasets": [],
}
p = pathlib.Path(cfg_path); p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(json.dumps(cfg, indent=2))
print(f"Wrote {cfg_path}")
PYEOF

# --- 6. analysis baselines (optional) --------------------------------------
if [[ "${SKIP_ANALYSIS:-0}" != "1" ]]; then
  log "Analysis baselines (Random / Max-Expert / Oracle)"
  "$PY" - <<'PYEOF'
from baselines import BaselineDataLoader, BaselineAggregator
loader = BaselineDataLoader("config/baseline_config.yaml")
agg = BaselineAggregator(loader.load_all_records(), data_loader=loader)
agg.print_summary_tables(score_as_percent=True, test_mode=False)
PYEOF
else
  echo "SKIP_ANALYSIS=1 — skipping baseline tables."
fi

# --- 7. adaptor split -------------------------------------------------------
log "Adaptor train/test split (seed=$SEED, ratio=$SPLIT)"
if [[ -f "${SPLIT_DIR}/train.jsonl" && -f "${SPLIT_DIR}/test.jsonl" ]]; then
  echo "Split present at ${SPLIT_DIR} — skipping."
else
  "$PY" -m baselines.adaptors.avengerspro_adaptor \
    --config config/baseline_config.yaml --seed "$SEED" --split-ratio "$SPLIT" \
    --output-dir "$ADAPTOR_DIR"
fi

# --- 8. cluster router ------------------------------------------------------
log "AvengersPro cluster router"
mkdir -p "$(dirname "$ROUTER_OUT")"
"$PY" -m baselines.AvengersPro.simple_cluster_router \
  --config "$ROUTER_CFG" --output "$ROUTER_OUT"

# --- result -----------------------------------------------------------------
log "Result"
"$PY" - "$ROUTER_OUT" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
def find(o, key):
    if isinstance(o, dict):
        if key in o: return o[key]
        for v in o.values():
            r = find(v, key)
            if r is not None: return r
    return None
acc = find(d, "accuracy") or find(d, "router_accuracy") or find(d, "test_accuracy")
if isinstance(acc, (int, float)):
    print(f"Router accuracy: {acc*100:.2f}%" if acc <= 1 else f"Router accuracy: {acc:.2f}%")
else:
    print("Router run complete — inspect the log for metrics.")
print(f"Full log: {sys.argv[1]}")
PYEOF

cat <<EOF

Done. LLMRouterBench lives at:
  $BENCH_HOME

Note: local $EMBED_MODEL embeddings differ from the paper's gte_Qwen2-7B-instruct,
so absolute numbers won't match the published leaderboard — this validates the
pipeline locally. Point EMBED_MODEL / EMBED_URL at a hosted gte/Qwen endpoint to
reproduce the paper exactly.
EOF
