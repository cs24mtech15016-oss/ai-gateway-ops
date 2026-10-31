# Long-horizon auto-routing rubric

Compares published routing methods against the parameters a long-horizon router needs, and
marks where CheckpointRouter (CPR) is novel. Edit the cells as evidence changes. Terms used in
the criteria are defined in [`DEFINITIONS.md`](DEFINITIONS.md).

**v1 scope: a single-agent session.** One agent loop, one model active at a time; the router
picks the model and context at checkpoints. Sub-agents, worker assignment, execution-graph
revision and merge/coordination cost are out of scope for v1 and are listed under *Deferred*.

**Legend:** `✅` has it · `◐` partial / weaker form · `·` absent · `–` not applicable ·
`?` not yet verified · `☐` CPR planned, not yet implemented (CPR is proposed; nothing is built).

Evidence: re-checked 2026-10-26 against the method and experiment sections (arXiv HTML) of every
paper below, then against released code where it exists (see *Code availability*). Extraction was
partly model-assisted; quote the paper section or file, not this table, when citing.

## Methods

| Code | Method | Type | Source |
|---|---|---|---|
| RL | RouteLLM | single-turn router | arXiv 2406.18665 |
| AvP | Avengers-Pro | single-turn cluster router | arXiv 2508.12631 |
| FG | FrugalGPT | single-query cascade | arXiv 2305.05176 |
| LLM | LiteLLM complexity router (this repo today) | single-turn heuristic | `litellm/config.yaml` |
| SAAR | vLLM Session-Aware Agentic Routing | session router | vllm.ai blog 2026-06-02; vllm-project/semantic-router |
| ReD | ReDAct | uncertainty deferral | arXiv 2604.07036 |
| MTR | MTRouter | per-turn, outcome-supervised | arXiv 2604.23530 |
| SEQ | SeqRoute | budget-aware sequential (offline RL) | arXiv 2605.25424 |
| ARES | Ares | per-step reasoning effort | arXiv 2603.07915 |
| TAB | Turn-Adaptive Budgets | per-turn thinking budget | arXiv 2604.05164 |
| ACON | ACON | context compression | arXiv 2510.00615 |
| TRC | TRACE | compaction evaluation | arXiv 2608.06503 |
| PAIR | PAIR | compaction prompt adaptation via counterfactual continuations | arXiv 2609.36526 |
| HT | The Handoff Tax | measurement study of mid-trajectory model handoff | arXiv 2608.24358 |
| TWN | TwinRouterBench | per-step routing benchmark | arXiv 2605.18859; github.com/CommonstackAI/TwinRouterBench |
| CPR | CheckpointRouter (ours) | checkpoint model/context allocation, single agent | this repo |

Dropped for v1 (multi-agent only): ProgRouter, MasRouter, CASTER.

Read but not a column (request-level, already covered by RL/AvP): **LongContextRouter**
(OpenReview 0GdLxaSjtZ, ICLR 2027 submission). It picks one model per task "using information
available before task execution" (§3) from a hierarchical encoding of long task inputs, with a
learned success head and a separate cost head, `U_m = π̂_m − λ·φ(ĉ_m)` (Eq. 12). On SWE-bench Pro the
history text C is used only in training; test input is the problem statement only (Eq. 2), and labels
are full-task success from the start, "not continuation from C" (§3). One split, no seeds (§5.5).
Its future work asks for "richer decision-time histories and step-level routing" (§6). Rubric scores:
A1 · (one choice per task), D1 ✅, D3/D4 · (the packet is not a decision), C1 ✅, E1 ✅ (SWE-bench
Pro, MemoryAgentBench), E2 ·, E3 ·, E4 ◐ (any-success oracle).

Dropped as not close matches (one-way escalation only; they never return to the cheap model):
TACIT-Switch (arXiv 2608.27911, permanent handoff, §2.1 and Algorithm 1), SWE-Router
(arXiv 2607.00053, one continue-or-restart decision, Algorithm 1) and Bayesian Self-Escalation
(arXiv 2608.24087, "escalation is terminal", §3). They are still cited as prior art: TACIT ran a
matched fixed/per-step/adaptive timing comparison for one-way handoff (Table 2, Fig. 2b).

## Code availability (checked 2026-10-26)

Cells for methods with code were re-checked against the code (read only; nothing was run). Cells for
methods without code rest on the paper alone. "Not found" means arXiv, Hugging Face, GitHub and web
searches turned up nothing; it does not prove no code exists.

| Code | Repository (commit) | Cells checked against code |
|---|---|---|
| RL | github.com/lm-sys/RouteLLM (`0b64fda`) | A1, C3, E4 |
| FG | github.com/stanford-futuredata/FrugalGPT (`2b23e6a`) | A1, C3, E4 |
| AvP | No authors' release found; re-implementation in github.com/ynulihao/LLMRouterBench `baselines/AvengersPro` (`0b81ba3`) | A1, C3, E4 |
| LLM | github.com/BerriAI/litellm `router_strategy/complexity_router` (`dddbaa8`) | All; see the LLM note |
| SAAR | github.com/vllm-project/semantic-router (`b85ad12`) | A1, A3, A5, B1–B4, C3, D2, E1, E3 |
| MTR | github.com/ZhangYiqun018/MTRouter (`ee9e457`) | A1, A3, C2, E3 |
| ACON | github.com/microsoft/acon (`d63f9ae`) | C1, D3, E1, E3 |
| TRC | github.com/nokia-applied-research/Trace (`9be7d66`) | C1, E2, E3 |
| TWN | github.com/CommonstackAI/TwinRouterBench (`466fb0b`) | A5, B1, B2, D2, D3, E2, E3, E4 |
| ReD, SEQ, ARES, TAB, PAIR, HT, LongContextRouter | Not found | None; paper only |

**Consequence for CPR:** the cells that matter most for the novelty claim, HT's A4, D3 and D4,
come from a paper with no public code, so they cannot be reproduced yet.

## Matrix

| # | Criterion | RL | AvP | FG | LLM | SAAR | ReD | MTR | SEQ | ARES | TAB | ACON | TRC | PAIR | HT | TWN | CPR |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **A** | **When the router decides** | | | | | | | | | | | | | | | | |
| A1 | Decides beyond the first prompt | · | · | · | · | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | ✅ | ☐ |
| A2 | Uses partial-trajectory execution evidence (tests, errors, progress) | · | · | · | · | ◐ | ◐ | ✅ | · | ◐ | ◐ | – | – | – | – | ◐ | ☐ |
| A3 | Explicit stay/switch checkpoints | · | · | · | · | ◐ | ◐ | · | · | · | · | – | – | – | – | · | ☐ |
| A4 | Compares fixed vs. per-call vs. adaptive timing on matched tasks | · | · | · | · | · | · | · | · | · | · | – | – | – | ◐ | · | ☐ |
| A5 | Reversible switching (can return to the cheap model) | · | · | · | · | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | ✅ | ☐ (Phase 3) |
| **B** | **Continuity and cost of switching** | | | | | | | | | | | | | | | | |
| B1 | Tool-loop / provider-state hard locks | · | · | · | · | ✅ | · | · | · | – | – | – | – | – | – | · | ☐ |
| B2 | Cache-aware switch cost | · | · | · | · | ✅ | · | · | · | – | – | – | – | – | ◐ | ◐ | ☐ |
| B3 | Idle / task-drift reset points | · | · | · | · | ✅ | · | · | · | – | – | – | – | – | – | · | ☐ |
| B4 | Charges handoff overhead (re-reading context, lost state) in the objective | · | · | · | · | ✅ | ◐ | · | · | – | – | – | – | – | ◐ | · | ☐ |
| **C** | **Objective** | | | | | | | | | | | | | | | | |
| C1 | Episode success is the objective or the training label | · | · | · | · | · | ◐ | ✅ | ◐ | ◐ | ✅ | ✅ | ◐ | ✅ | ✅ | ✅ | ☐ |
| C2 | Remaining session budget is part of the router's state | · | · | · | · | · | · | · | ✅ | · | · | – | – | – | – | · | ☐ |
| C3 | Latency / wall time in the objective | · | · | · | · | ◐ | · | · | · | · | · | – | – | – | · | · | ☐ |
| **D** | **What gets allocated** | | | | | | | | | | | | | | | | |
| D1 | Model choice | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | · | · | · | · | · | ◐ | ✅ | ☐ |
| D2 | Reasoning effort / thinking budget | · | · | · | · | ◐ | · | · | · | ✅ | ✅ | · | · | · | · | · | ☐ (optional) |
| D3 | Context packet (full / compact / drop / restart) as a decision | · | · | · | · | · | · | · | · | · | · | ◐ | ◐ | ◐ | ◐ | · | ☐ |
| D4 | Model and context chosen jointly | · | · | · | · | · | · | · | · | · | · | · | · | · | ◐ | · | ☐ |
| **E** | **Evaluation** | | | | | | | | | | | | | | | | |
| E1 | Real long-horizon agent benchmark | · | · | · | · | ◐ | ◐ | ◐ | · | ✅ | ✅ | ✅ | ✅ | ? | ✅ | ✅ | ☐ |
| E2 | Measures continuation value from the same mid-run state | · | · | · | · | · | · | · | ◐ | ◐ | · | · | ✅ | ✅ | ? | ◐ | ☐ |
| E3 | Run-to-run reliability (seeds, pass^k, CIs) | · | · | · | · | ◐ | ◐ | ◐ | · | · | · | · | ✅ | ✅ | ◐ | · | ☐ |
| E4 | Oracle / upper-bound reported | · | · | · | · | · | · | · | · | · | · | · | · | · | · | ◐ | ☐ (sampled-branch only) |

Notes on contested cells:
- **HT is a measurement study, not a router.** It switches at seven fixed switch points (percentiles
  of the starting model's step count, per difficulty bucket) with four handoff interfaces (Raw,
  Compact-pre, Compact-suf, Traj-drop) plus restart controls, on all 500 SWE-bench Verified tasks,
  Claude Haiku 4.5 ↔ Opus 4.7 and GPT-5.6 Luna ↔ Sol, both directions. Its D1/D3/D4 cells are `◐`
  because it *measures* model × interface effects but no policy *chooses* them. Its future-work
  section asks for "adaptive, progress-aware policies that jointly decide when to switch and which
  model should continue" and for routers that "treat the handoff interface as part of the switching
  policy". **E2 `?`:** not yet confirmed whether the four interfaces branch from one shared prefix
  run or from independent prefix runs.
- **A4:** no remaining method compares fixed, per-call and adaptive timing on matched tasks. HT
  compares only fixed switch points (`◐`).
- **E2:** TRACE and PAIR run paired continuations from the same restored agent state, but only to
  judge compaction. TwinRouterBench's static labels
  replay prefixes with mixed tiers (`◐`). SeqRoute branches simulated chat turns, not agent state.
- **A5 for ReDAct:** control returns to the small model after each deferred step; the deferred
  action is not undone.
- **B2 for TwinRouterBench:** four-bucket cost (fresh input, cache read, cache write, output;
  `swerouter/pricing.py:151`) with cache writes billed on cold start, tier switch and TTL expiry. The
  router is told the cache state (`RouterContext.cache_state`, `router.py:12-58`). The cache is
  simulated by the harness (5-minute TTL), not reported by the provider.
- **LLM column scores this repo's deployed config** (`litellm/config.yaml`: tiers and a default
  model only). The LiteLLM complexity router has opt-in features that would score higher if
  enabled: session affinity pins, stall escalation from tool-call history (A1/A2/A3 `◐`),
  cache-aware warm-model swaps (B2 `◐`) and a static `reasoning_effort` per tier (D2 `◐`).
- **TRACE E2:** state is reproduced by opening a fresh AppWorld and deterministically replaying the
  recorded code prefix with no model in the loop, not by snapshot restore (AppWorld save/load does
  not round-trip; `trace_cc/collect/runner.py`). Both arms replay the same prefix. Its E3 pass^2
  applies to the optimiser's promotion gate.
- **ACON C1:** the guideline optimiser is driven by baseline-success / compressed-failure flips
  (`unified_update_history_prompt.py:183-214`), i.e. task success as the signal. Its compression
  trigger is a fixed token threshold (4096 history / 256 observation), hence D3 `◐`.
- **B4 for ReDAct:** the discarded small-model call is paid, but re-reading and lost cache are not charged.
- **B4 for SAAR:** the handoff penalty is an EMA of the cost difference between consecutive records
  where the model changed (`lookuptable/builder.go:218-247, 342-346`), default 0.05. It is a
  per-switch cost, not a measured quality or continuation outcome.
- **C3 for SAAR:** true only when an operator configures a `latency_aware` base selector; the
  default base is `hybrid` (`selection/session_aware.go:39, 290-305`).
- **C1 for TRACE:** preference pairs come from a boundary-local burden score; terminal outcomes are
  used only to select templates on dev.
- **C2 for TAB:** the state is history plus the current sub-question, with no remaining-budget
  feature.
- **C3:** TAB and AvP measure or mention latency but do not optimise it. SAAR feeds a
  `latency_aware` base selector into the session score.
- **D2 for SAAR:** `reasoning_effort` is static per decision and model ref
  (`extproc/req_filter_reason_selection.go:70-87`, applied at `fallback_dispatch.go:653-657`). The
  switch gate reads it as quality evidence (`session_switch_gate.go:169`) but never chooses it.
- **E1 for SeqRoute:** a simulated four-turn ShareGPT chat with no tools.
- **E1 / E3 for SAAR:** the blog's headline numbers come from a pure Python simulation with no
  HTTP calls (`bench/agentic_routing_experiment.py:11-21`), run over multiple seeds (`--seeds`,
  `:229`). Live benchmark scripts also exist (`agentic_routing_live_benchmark.py`,
  `agent_task_live_benchmark.py`) but were not read, so E1 stays `◐`.
- **E3 for HT:** task-bootstrap CIs; one rollout per configuration ("repeated rollouts" is listed as
  future work).
- **E4:** no surveyed method reports a true oracle. Ares, AvP and RouteLLM report endpoints or
  random baselines (an any-model-correct Oracle row exists in LLMRouterBench's aggregator, not in
  AvP itself). TwinRouterBench's code has a `GoldTierRouter` "oracle" that replays the published
  per-step gold labels, saturates at the last label on longer runs, and is not available on the
  dynamic SWE track (`routers/gold_tier.py`; README).
- **E2 for TwinRouterBench:** labels come from sequential locking: earlier steps keep their exact
  responses and state, one step tries a candidate tier, and all later steps are forced to `high`
  (`docs/DATA_GENERATION.md:90-106`). Only one step varies per label.

## Where CPR is novel (v1), after the 2026-10-26 re-check

No method in the matrix has a `✅` in **A4, D3, D4, C3 or E4**. E2 has a `✅`, but only for
compaction. A4 was done for one-way handoff by TACIT (dropped above), so it is not claimed as new. Ranked:

| Claim | Prior state | What CPR adds | Strength | Main risk |
|---|---|---|---|---|
| **D3 + D4 as a learned decision:** choose the receiving model *and* the handoff packet per checkpoint state | HT measured that the best interface depends on direction (drop helps escalation, hurts downshift) but used fixed policies | A policy that picks (model, packet) from checkpoint evidence, compared with the best fixed packet and with independently tuned selectors | Strongest | HT already supplies the motivation; reviewers will ask for gains over HT's best fixed interface |
| **E2 for model switching:** label stay/switch decisions with continuations branched from the same saved agent state | TRACE and PAIR do this for compaction only | Branch labels for model × packet actions | Moderate | It is an adoption of TRACE/PAIR's method; the novelty lies in what is decided, not in how it is measured |
| **A4** fixed vs. per-call vs. adaptive timing on matched tasks, with reversible switching | HT compares fixed switch points only; TACIT (dropped, one-way) ran it for permanent handoff | The matched timing comparison with packets and switch-back | Weak (an empirical extension) | Not a novelty claim; frame it as extending TACIT's comparison to reversible switching |
| **C3** latency in the objective | Nobody optimises it | Latency budget B_L in the constrained objective | Minor | Easy to add, low reviewer weight |

**Not novel; adopt and cite:** decisions beyond the first prompt (MTR, ReD, SAAR); episode-success
supervision (MTR, TWN, HT); budget in the router state (SEQ);
per-step effort (ARES, TAB); continuity locks, cache cost, reset points and handoff penalty (SAAR);
cache-aware cost accounting (TWN, HT); handoff interfaces and their measured tax (HT); paired
continuations from a restored state (TRC, PAIR); optimised compaction (ACON, PAIR).

**One-line positioning:** HT shows that the handoff interface matters and depends on direction,
using fixed policies. CPR asks whether a *learned* checkpoint policy can pick the model and the
packet together from execution evidence, trained on continuations branched from the same state,
and beat HT's best fixed interface at matched cost.

## Open verification items

- [x] LongContextRouter (openreview.net/forum?id=0GdLxaSjtZ, ICLR 2027 submission, read 2026-10-31):
      one model per task chosen before execution (§3, §4), so it is a request-level router over long
      task inputs. It does not choose context (D3/D4 absent); "context" is the router's own input.
      D3/D4 claims stand. Not added as a column; listed under Code availability as not found.
- [ ] HT E2: do the interfaces share one prefix run per task and switch point? No public code, so
      this can only be settled by the paper's appendix or by asking the authors.
- [ ] PAIR E1 and C1: benchmarks and outcome definition (abstract only so far; no public code).
- [x] ACON E3: the released code uses one fixed seed (42) and no repeated runs, so `·` stands.
- [x] SAAR E1: live scripts read 2026-10-31 (`agent_task_live_benchmark.py`, `agentic_routing_live_benchmark.py`):
      scripted sessions with canned tool results and stubbed earlier assistant turns, scored by substring
      match. No real agent benchmark, so `◐` stands.
- [ ] "Counterfactual Rollout Replay: forkable environments as process rewards for SWE agents"
      (ResearchGate, unread): possible E2 precedent in SWE agents.
- [ ] "Handoff debt" (arXiv 2606.02875) and "A Model Handoff Also Transfers a State Interface"
      (blog): adjacent work on handoff information.

## CPR v1 build checklist

- [ ] B1 Session ID plus tool-loop / provider-state locks in the gateway (reuse or mirror vSR)
- [ ] E4 Baselines: always-strong, always-cheap, sticky, LiteLLM complexity router, SAAR/vSR,
      **HT best fixed interface per direction**, oracle
- [ ] B2 / B4 Four-bucket cache-aware cost (fresh, cache read, cache write, output), matching HT/TWN
- [ ] A3 Checkpoint decisions in the LiteLLM gateway plugin (stay / switch) at quiescent boundaries only;
      harness adapter supplies the session header plus restart and snapshot callbacks
- [ ] E2 Paired continuations from saved checkpoint state, with a replay-equivalence check
- [ ] D3 Packet menu FULL / STRUCT / DROP / RESTART (DROP added because HT found it best for escalation)
- [ ] D4 Joint model × packet selector vs. best fixed packet vs. independently tuned selectors
- [ ] A4 Fixed-prefix vs. per-call vs. adaptive timing, matched
- [ ] E3 Multiple seeds, pass^k, task-clustered CIs
- [ ] D2 Small effort menu (only if the earlier results justify it)

## Deferred (post-v1, multi-agent)

Not scored in v1. Revisit once the single-agent results are in.

| Criterion | Closest prior work |
|---|---|
| Sub-agent worker model assignment | ProgRouter, MasRouter, CASTER |
| Revising the execution graph mid-run (spawn / replan) | MasRouter, ProgRouter, CASTER (all ◐) |
| Coordination and merge cost in the objective | none found |
