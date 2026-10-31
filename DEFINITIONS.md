# CheckpointRouter definitions (v1, single agent)

Operational definitions for the terms used in [`RUBRIC.md`](RUBRIC.md) and the proposal site.
Notation follows `docs/research.html` (§06). Where a term matches prior work, the source is named
so that results can be compared directly.

## 1. Episode structure

| Term | Definition |
|---|---|
| **Episode** | One task run from the initial task to termination (submit, step cap, spend cap or deadline). One agent loop, one active model at any time. |
| **Step / call** | One model call `i = 0, 1, …`. Tool executions happen between calls. |
| **Prefix** | Everything executed before the decision point `t`: calls, tool outputs, workspace edits, spend and elapsed time. Prefix resources are sunk and stay in the episode totals. |
| **Suffix / continuation** | Everything executed after `t` under a stated continuation protocol `μ` (Phase 1a) or a frozen future policy `π` (later phases). |
| **Terminal success `Y`** | 1 if the final workspace passes the task's hidden executable checks (for example the official SWE-bench evaluator), otherwise 0. An LLM judge is never the only criterion. |
| **Escalation / downshift** | A switch to a model with higher / lower measured capability and cost in this setting (HT's LC→HC and HC→LC). |
| **Switch** | A change of model `m` or packet `κ` between consecutive calls. Holding the current allocation is not a switch. |

## 2. Where decisions can happen

| Term | Definition |
|---|---|
| **Quiescent boundary** | The point after all tool results of call `i` have returned and before call `i+1` is sent. No tool is running, and the workspace and history are consistent. These are the only points where snapshots and switches are allowed. |
| **Hard lock** | A boundary where a switch is infeasible regardless of value: (a) a **tool-loop lock**, where the last assistant turn has an unanswered `tool_use` or tool call; (b) a **provider-state lock**, where the conversation depends on state held by the provider (`previous_response_id`, encrypted reasoning items, thinking-block signatures). Locked boundaries are removed from `F`. |
| **Checkpoint** | A quiescent, unlocked boundary at which the policy evaluates `gate(H_t, r_t) ∈ {hold, revise}`. Every checkpoint is a boundary; not every boundary is a checkpoint. |
| **Checkpoint trigger** | The rule that turns a boundary into a checkpoint. v1 menu: a test or build command result; the same error repeating ≥ 3 times in a window of 6 calls; the first edit after a read-only exploration phase; a plan artefact being written (todo list, plan tool); a step-count tick every `k` calls. Triggers use only visible evidence. |
| **Reset point** | A checkpoint where continuity penalties are dropped because the cache is cold anyway: idle time > cache TTL, or a new human ask unrelated to the previous one. These come from SAAR; they matter for interactive sessions, not for batch benchmarks. |

## 3. State and action

| Symbol | Definition |
|---|---|
| `H_t` | The visible history and workspace evidence at checkpoint `t`: task text, messages, tool calls and outputs, current diff, visible test results. |
| `r_t` | The remaining resources vector: spend, wall-clock deadline, turn cap and tool cap. |
| `x_t = φ(H_t, r_t)` | The router's features: progress and failure diagnostics, context occupancy (tokens in `H_t` divided by the model's window), cache warmth (cached prefix tokens for the current model, seconds since the last call), lock status, active model and packet, steps since the last switch, and `r_t`. Hidden tests and future outcomes are never features. |
| `a_t = (m_t, κ_t, b_t)` | The allocation: model `m` from the pool, handoff packet `κ`, and generation/reasoning budget `b`. v1 fixes `b`. |
| `F(H_t, r_t)` | The feasible menu: the models allowed in the phase, packets that fit the receiving model's window, actions whose worst-case cost fits `r_t`, and no locks. It always contains `hold`. |

### Handoff packets `κ`

Every packet except RESTART preserves the current workspace (files on disk). They differ in what
trajectory text the receiver sees. The names map one-to-one onto HT's interfaces (arXiv 2608.24358,
§3.1) so that results are comparable.

| Packet | Receiver sees | HT name | Charged overhead |
|---|---|---|---|
| **FULL** | System prompt, task, the full prefix trajectory verbatim, and the workspace | Raw | A cold cache write of the whole prefix on the receiver |
| **COMPACT(author)** | System prompt, task, a token-capped structured summary (goal, current diff, visible failures, constraints, attempted fixes, evidence references), and the workspace | Compact-pre (author = outgoing model) / Compact-suf (author = receiver) | The summarisation call and a cold write of the short packet |
| **DROP** | System prompt, task, a static "continue from the current workspace" note, and the workspace | Traj-drop | A cold write of the short prompt only |
| **RESTART** | System prompt and task on the *original* sandbox; edits are discarded | Abort + HC fresh | The prefix is sunk; the receiver gets the residual budget, not a fresh one |

HT found that the best packet depends on the switch direction: DROP gave the best escalation quality
and COMPACT the cheapest escalation, while FULL was best for downshift. The CPR v1 hypothesis is that
the best packet also depends on the checkpoint state, which is why it is a decision and not a
setting.

## 4. Cost, latency and handoff overhead

**Per-call cost** (four buckets, matching HT §A.1 and TwinRouterBench §5.1):

```
c_i = p_in(m)·fresh_in_i + p_cr(m)·cache_read_i + p_cw(m)·cache_write_i + p_out(m)·out_i
```

Output includes reasoning tokens. Prices come from a pinned price card (for example the LiteLLM
model-pricing registry at a fixed version). Billable malformed responses count.

**Episode cost:** `C = Σ_i c_i + C_router + C_packet`. `C_router` covers feature extraction, gate and
value inference. `C_packet` covers summarisation calls. Each item is counted exactly once.

**Handoff overhead of a switch** is the extra cost and time that the switch causes compared with
holding: the packet construction call, plus the receiver's cache write of its new prefix, plus the
cache reads the old model would have had. It is not added separately to `C`, because it is
already inside the measured `c_i`. It is reported separately so that the "handoff tax" is visible.

**Latency `L`:** end-to-end wall time of the episode, including tool waits, packet construction
and router inference. Report p50 and p95.

## 5. Policies and timing (rubric A4)

All timing policies share the same `φ`, value predictor, pool, packet menu, scaffold, training
data and caps. Only *when* the decision can fire differs.

| Timing policy | Decision points | Prior work |
|---|---|---|
| **Request-level** | `t = 0` only | RouteLLM, AvP |
| **Fixed-prefix(K)** | One decision after `K` calls. `K` is chosen on dev, as a percentile of the starting model's step distribution per difficulty bucket (HT §3.2) | HT |
| **Per-call** | Every unlocked boundary, with `hold` allowed | MTRouter, TwinRouterBench |
| **Adaptive checkpoint** | Boundaries where a trigger fires and `gate = revise` | CPR |

- **One-way vs reversible:** a one-way policy makes at most one switch, to the stronger model. A
  reversible policy may switch again, including back to a cheaper model (rubric A5).
  CPR Phase 1 is one-way; Phase 3 is reversible.
- **Composed policy:** independently tuned timing, model and packet selectors run together. This
  is the baseline the joint policy must beat (rubric D4).

## 6. Measuring value (rubric E2)

| Term | Definition |
|---|---|
| **Snapshot** | A restorable checkpoint state: base commit and workspace diff, container and dependency state, working directory and relevant shell state, full message history, RNG/config metadata, and `r_t`. Taken only at quiescent boundaries. |
| **Replay-equivalence check** | Restore the snapshot and re-run the same action with a fixed seed where the backend supports it. The tool outputs and the diff must match the original. A snapshot that fails this check is excluded, not patched. |
| **Branch** | One continuation from a restored snapshot under action `a` and protocol `μ_a`. Several stochastic trials per branch. |
| **Continuation value** | `Q_a(H_t, r_t; μ_a) = E[Y_a − λ·C_a^rem − η·L_a^rem]`, where the remaining cost and time include `a`'s handoff overhead. |
| **Gate rule** | `gate = revise` iff `max_{a ∈ F∖{hold}} Δ̂_a > τ`, with `τ ≥ 0` tuned on dev; then `a_t = argmax Δ̂_a`. |
| **Weights λ, η** | Ratios of Lagrange multipliers for the constrained objective (§7): `λ = 1/ν`, `η = ρ/ν`. Swept on dev; the operating point is the cheapest sweep point that meets both constraints. |
| **Switch advantage** | `Δ_a = Q_a − Q_hold`. Phase 1a uses Cheap-to-end as `hold`. Later phases use hold-then-follow-`π`. |
| **Paired continuation** | Branches of different actions from the *same* snapshot, compared within that snapshot. This is what makes the measurement E2 and not a comparison of independent episodes. |
| **Sampled-branch hindsight selector** | `a*_t = argmax_{a ∈ sampled A_t} Q̂_a`, estimated on one repetition set and reported on an independent one. It is a diagnostic, not a global oracle (rubric E4 `◐`). |

## 7. Evaluation quantities

- **Primary operating point:** minimise `E_π[C]` subject to `E_π[Y] ≥ p_ref − ε` and
  `E_π[L] ≤ B_L`. `π_ref`, `ε` (absolute, for example 0.02) and `B_L` are fixed before test.
- **Gap recovered:** `(Y_π − Y_cheap) / (Y_strong − Y_cheap)` on a matched task subset (HT's
  normalised metric). Report it together with `C_π / C_strong`.
- **Matched switched subset:** for a fixed-prefix comparison, keep only the tasks that reached the
  switch point under every compared arm (HT §3.3). Otherwise, easy tasks that finish early bias
  the comparison.
- **Reliability:** pass^k over `k ≥ 2` independent runs, plus task- or repository-clustered
  paired bootstrap CIs.
- **Switch behaviour:** switches per episode, lock-blocked switches, thrash (switching back within
  `n` calls), cache tokens lost per switch, and the packet chosen.

## 8. Rubric criteria: what earns `✅` and `◐`

| # | `✅` requires | `◐` is |
|---|---|---|
| A1 | A routing decision after the first model call | — |
| A2 | Decisions use execution evidence (tests, errors, tool results, progress) | History only, or model-internal signals (uncertainty) only |
| A3 | Named decision points where staying is an explicit option | A per-step threshold, or one-sided escalation tests |
| A4 | ≥ 3 timing policies (request or fixed-prefix, per-call, adaptive) compared at matched cost, pool and state | Only fixed points, or only prefix-length sweeps |
| A5 | Can switch back to a cheaper model mid-episode | Control returns to the cheaper model only after a single deferred step |
| B1 | Tool-loop and provider-state locks enforced | One of the two |
| B2 | Lost cache priced into the switch decision | Cache priced in the cost accounting but not in the decision |
| B3 | Idle and task-drift reset points | One of the two |
| B4 | Handoff overhead charged inside the objective that drives the decision | Wasted prefix or calls paid, but re-reading and cache loss not modelled |
| C1 | Terminal task success is the objective or the training label | A proxy (judge score, action match, local burden) with success used only for selection |
| C2 | Remaining budget is an explicit state feature | Budget pressure enters only indirectly |
| C3 | Latency is in the objective or a constraint | Latency term in a heuristic score |
| D1 | The policy chooses the model | Model varied by design but not chosen by a policy |
| D2 | The policy chooses effort or a thinking budget | Effort fixed per route by an operator |
| D3 | The policy chooses the packet per decision | Packet varied by design, or fixed by the model choice |
| D4 | One policy chooses model and packet jointly | Joint effects measured, no policy |
| E1 | A real multi-step agent benchmark with tools and environment state | Agentic but not long-horizon, or not software engineering |
| E2 | Paired continuations from the same restored agent state | Prefix replay with mixed models, or simulated branches |
| E3 | Repeated runs (seeds, pass^k) or paired CIs over runs | CIs over tasks only, or a single repeat count |
| E4 | A true oracle or upper bound over the action space | Endpoint, in-sample or simulation-only bound |
