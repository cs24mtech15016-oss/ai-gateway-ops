# Long-horizon auto-routing rubric

Compares published routing methods against the parameters a long-horizon router needs, and
marks where CheckpointRouter (CPR) is novel. Edit the cells as evidence changes.

**v1 scope: a single-agent session.** One agent loop, one model active at a time; the router
picks the model and context at checkpoints. Sub-agents, worker assignment, execution-graph
revision and merge/coordination cost are out of scope for v1 and are listed under *Deferred*.

**Legend:** `✅` has it · `◐` partial / weaker form · `·` absent · `–` not applicable ·
`☐` CPR planned, not yet implemented (CPR is proposed; nothing is built).

Evidence: abstracts plus the summaries in `docs/index.html`, checked 2026-10-18. Full papers
not read except SAAR (blog plus the vllm-project/semantic-router code) and HORIZON (partial).
Re-verify any cell before citing it.

## Methods

| Code | Method | Type | Source |
|---|---|---|---|
| RL | RouteLLM | single-turn router | arXiv 2406.18665 |
| AvP | Avengers-Pro | single-turn cluster router | arXiv 2508.12631 |
| FG | FrugalGPT | single-query cascade | arXiv 2305.05176 |
| LLM | LiteLLM complexity router (this repo today) | single-turn heuristic | `litellm/config.yaml` |
| SAAR | vLLM Session-Aware Agentic Routing | session router | vllm.ai blog 2026-06-02 |
| SWE | SWE-Router | explore-then-escalate | arXiv 2607.00053 |
| TAC | TACIT-Switch | adaptive permanent handoff | see `docs/index.html` |
| ReD | ReDAct | uncertainty deferral | arXiv 2604.07036 |
| MTR | MTRouter | per-turn, outcome-supervised | see `docs/index.html` |
| SEQ | SeqRoute | budget-aware sequential (offline RL) | arXiv 2605.25424 |
| ARES | Ares | per-step reasoning effort | arXiv 2603.07915 |
| TAB | Turn-Adaptive Budgets | per-turn thinking budget | arXiv 2604.05164 |
| ACON | ACON | context compression | arXiv 2510.00615 |
| TRC | TRACE | compaction evaluation | arXiv 2608.06503 |
| TWN | TwinRouterBench | per-step routing benchmark | github.com/CommonstackAI/TwinRouterBench |
| CPR | CheckpointRouter (ours) | checkpoint model/context allocation, single agent | this repo |

Dropped for v1 (multi-agent only): ProgRouter, MasRouter, CASTER.

## Matrix

| # | Criterion | RL | AvP | FG | LLM | SAAR | SWE | TAC | ReD | MTR | SEQ | ARES | TAB | ACON | TRC | TWN | CPR |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **A** | **When the router decides** | | | | | | | | | | | | | | | | |
| A1 | Decides beyond the first prompt | · | · | · | · | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | ✅ | ☐ |
| A2 | Uses partial-trajectory execution evidence (tests, errors, progress) | · | · | · | · | ◐ | ✅ | ✅ | ◐ | ✅ | · | ◐ | ◐ | – | – | ◐ | ☐ |
| A3 | Explicit stay/switch checkpoints | · | · | · | · | ◐ | ✅ | ✅ | ◐ | · | · | · | · | – | – | · | ☐ |
| A4 | Compares fixed vs. per-call vs. adaptive timing on matched tasks | · | · | · | · | · | · | · | · | · | · | · | · | – | – | · | ☐ |
| A5 | Reversible switching (can return to the cheap model) | · | · | · | · | ✅ | · | · | ✅ | ✅ | ✅ | ✅ | – | – | – | ✅ | ☐ |
| **B** | **Continuity and cost of switching** | | | | | | | | | | | | | | | | |
| B1 | Tool-loop / provider-state hard locks | · | · | · | · | ✅ | · | · | · | · | · | – | – | – | – | · | ☐ |
| B2 | Cache-aware switch cost | · | · | · | · | ✅ | · | · | · | · | · | – | – | – | – | · | ☐ |
| B3 | Idle / task-drift reset points | · | · | · | · | ✅ | · | · | · | · | · | – | – | – | – | · | ☐ |
| B4 | Charges handoff overhead (re-reading context, lost state) in the objective | · | · | · | · | ✅ | · | ◐ | · | · | · | – | – | – | – | · | ☐ |
| **C** | **Objective** | | | | | | | | | | | | | | | | |
| C1 | Episode success is the objective or the training label | · | · | · | · | · | ✅ | ✅ | ◐ | ✅ | ◐ | ◐ | ✅ | ✅ | ✅ | ✅ | ☐ |
| C2 | Remaining session budget is part of the router's state | · | · | · | · | · | · | · | · | · | ✅ | · | ✅ | – | – | · | ☐ |
| C3 | Latency / wall time in the objective | · | ◐ | · | · | ◐ | · | · | · | · | · | · | ◐ | – | – | · | ☐ |
| **D** | **What gets allocated** | | | | | | | | | | | | | | | | |
| D1 | Model choice | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | · | · | · | · | ✅ | ☐ |
| D2 | Reasoning effort / thinking budget | · | · | · | · | · | · | · | · | · | · | ✅ | ✅ | · | · | · | ☐ (optional) |
| D3 | Context packet (full vs. compact) as a decision | · | · | · | · | · | · | · | · | · | · | · | · | ◐ | ◐ | · | ☐ |
| D4 | Model and context chosen jointly | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | ☐ |
| **E** | **Evaluation** | | | | | | | | | | | | | | | | |
| E1 | Real long-horizon agent benchmark | · | · | · | · | ◐ | ✅ | ◐ | ◐ | ◐ | ◐ | ✅ | ✅ | ✅ | ✅ | ✅ | ☐ |
| E2 | Measures continuation value from the same mid-run state | · | · | · | · | · | ◐ | ◐ | · | · | · | ◐ | · | · | ✅ | · | ☐ |
| E3 | Run-to-run reliability (seeds, pass^k) | · | · | · | · | ◐ | · | · | · | · | · | · | · | · | ✅ | · | ☐ |
| E4 | Oracle / upper-bound reported | ◐ | ◐ | · | · | · | · | · | · | · | · | ✅ | · | · | · | ✅ | ☐ |

Notes on contested cells:
- **E2:** TRACE runs paired continuations from the same environment state, but only to judge
  compaction events. TACIT-Switch uses paired full Cheap/Strong rollouts, not continuations
  from a checkpoint. SWE-Router reads the prefix and does not measure counterfactual continuations.
- **A4:** SWE-Router compares against prompt-only routing, not against other timing policies.
- **B4:** SAAR's handoff penalty comes from a lookup table learned from replayed switches
  (`lookuptable/builder.go`); it is a per-switch cost, not a measured continuation outcome.
- **E1 / E3 for SAAR:** the blog's headline numbers come from a Python simulation
  (`bench/agentic_routing_experiment.py`), not the live Go router.

## Where CPR is novel (v1)

Rows where no prior method has even a `◐`:

| Row | Claim | Strength | Main risk |
|---|---|---|---|
| **D4** | Choosing model and context together at a checkpoint, measuring model ability, context size and token use separately | Strongest | Needs a targeted search for "joint model–context routing"; CASTER (multi-agent, out of v1 scope) is the closest and must still be cited |
| **A4** | Head-to-head comparison of fixed-prefix, per-call and adaptive timing on matched state, model pool and budget | Strong but empirical | A comparison, not a new method; reviewers may call it a benchmark contribution |
| **E2 + A3 together** | Training checkpoint decisions on continuation value measured from the same mid-run state | Moderate | TRACE uses the same paired-continuation method for compaction; cite it and set CPR apart by what is decided |

**Not novel; adopt and cite:** decisions beyond the first prompt (MTR, SWE, ReD); episode-success
supervision (MTR, TWN); budget in the router's state (SEQ, TAB); per-step effort (ARES, TAB);
continuity locks, cache cost, reset points and handoff penalty (SAAR, available as code in
vllm-project/semantic-router); optimised compaction (ACON, CompactionRL).

**One-line positioning:** CPR's open question is *how much it is worth to change the model–context
configuration of a single agent at a checkpoint, measured from that same state*. No surveyed
method answers it. The individual parts (per-turn routing, budgets, effort, locks) all exist already.

## CPR v1 build checklist

- [ ] B1 Session ID plus tool-loop / provider-state locks in the gateway (reuse or mirror vSR)
- [ ] E4 Baselines: always-strong, always-cheap, sticky, LiteLLM complexity router, SAAR/vSR, oracle
- [ ] B2 / B4 Cache-aware switch and handoff cost (on Ollama: prompt re-processing time)
- [ ] A3 Checkpoint hook in the Terminal-Bench runner (stay / switch)
- [ ] E2 Paired continuations from saved checkpoint state (Cheap vs. Strong)
- [ ] A4 Fixed-prefix vs. per-call vs. adaptive timing, matched
- [ ] E3 Multiple seeds, pass^k
- [ ] D3 Full vs. compact context packets
- [ ] D4 Joint model × context selector vs. independently tuned selectors
- [ ] D2 Small effort menu (only if the earlier results justify it)

## Deferred (post-v1, multi-agent)

Not scored in v1. Revisit once the single-agent results are in.

| Criterion | Closest prior work |
|---|---|
| Sub-agent worker model assignment | ProgRouter, MasRouter, CASTER |
| Revising the execution graph mid-run (spawn / replan) | MasRouter, ProgRouter, CASTER (all ◐) |
| Coordination and merge cost in the objective | none found |
