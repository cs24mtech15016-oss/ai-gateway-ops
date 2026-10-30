"""Regenerate the rubric matrix and method-sidebar data in docs/rubric.html from RUBRIC.md.

Usage: python3 scripts/rubric/gen_rubric.py [repo-root]   (default: the repo containing this file)
Per-method sidebar text lives in methods.py next to this file. Keep both in sync with RUBRIC.md.
"""
import re, sys, json, html as H
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from methods import METHODS
root = sys.argv[1] if len(sys.argv) > 1 else str(Path(__file__).resolve().parents[2])
md = open(f"{root}/RUBRIC.md").read().splitlines()
hdr_i = next(i for i, l in enumerate(md) if l.startswith("| # | Criterion"))
codes = [c.strip() for c in md[hdr_i].split("|")[3:-1]]
NAMES = {"RL": "RouteLLM", "AvP": "Avengers-Pro", "FG": "FrugalGPT", "LLM": "LiteLLM", "SAAR": "vLLM SR",
         "ReD": "ReDAct", "MTR": "MTRouter", "SEQ": "SeqRoute",
         "ARES": "Ares", "TAB": "Turn budgets", "ACON": "ACON", "TRC": "TRACE", "PAIR": "PAIR",
         "HT": "Handoff Tax", "TWN": "TwinRouter-Bench", "CPR": "CPR (ours)"}
FAMOUS = {"RL", "AvP", "FG", "LLM"}
LABEL = {
    "A1": "Decides after the first prompt", "A2": "Uses mid-run evidence (tests, errors, progress)",
    "A3": "Explicit stay/switch checkpoints", "A4": "Compares fixed, per-call and adaptive timing on matched tasks",
    "A5": "Can switch back to the cheaper model", "B1": "Tool-loop / provider-state locks",
    "B2": "Prompt-cache loss priced into a switch", "B3": "Idle / task-drift reset points",
    "B4": "Handoff overhead charged", "C1": "Trained or judged on episode success",
    "C2": "Remaining session budget in the router state", "C3": "Latency / wall time in the objective",
    "D1": "Model", "D2": "Reasoning effort / thinking budget", "D3": "Context packet (full / compact / drop / restart)",
    "D4": "Model and context chosen jointly", "E1": "Real long-horizon agent benchmark",
    "E2": "Continuation value measured from the same mid-run state", "E3": "Run-to-run reliability (seeds, pass^k, CIs)",
    "E4": "Oracle / upper bound reported"}
GROUPS = {"A": "When the router decides", "B": "Continuity and switch cost", "C": "Objective",
          "D": "What gets chosen", "E": "Evaluation"}
NOVEL = {"D3": ("is-novel", "Learned"), "D4": ("is-novel", "New"), "E2": ("is-combo", "With A3")}
MK = {"✅": ("mk-yes", "Has it", "●"), "◐": ("mk-part", "Partial", "◐"), "·": ("mk-no", "Absent", "·"),
      "–": ("mk-na", "Not applicable", "–"), "?": ("mk-q", "Not yet verified", "?"),
      "☐": ("mk-plan", "Planned, not built", "☐")}

def cell(raw, code):
    raw = raw.strip()
    sym, _, note = raw.partition(" ")
    cls, title, glyph = MK[sym]
    td = ' class="is-famous"' if code in FAMOUS else ' class="is-ours"' if code == "CPR" else ""
    extra = f'<small class="mk-note">{note.strip("()")}</small>' if note else ""
    return f'<td{td}><span class="mk {cls}" title="{title}">{glyph}</span>{extra}'

ncols = len(codes) + 1

def btn(code):
    return (f'<button type="button" class="method-btn" data-method="{code}" aria-controls="method-panel" '
            f'aria-haspopup="dialog" title="Describe {H.escape(METHODS[code]["name"])}">{NAMES[code]}</button>')

def cells_of(code):
    i = codes.index(code)
    out = {}
    for l in md[hdr_i + 2:]:
        if not l.startswith("|"): break
        parts = [p.strip() for p in l.split("|")[1:-1]]
        key = parts[0].strip("*")
        if key in GROUPS: continue
        out[key] = parts[2 + i]
    return out
rows = []
for l in md[hdr_i + 2:]:
    if not l.startswith("|"):
        break
    parts = [p.strip() for p in l.split("|")[1:-1]]
    key = parts[0].strip("*")
    if key in GROUPS:
        rows.append(f'<tr class="rubric-group"><th scope="colgroup" colspan="{ncols}">{key} · {GROUPS[key]}</th></tr>')
        continue
    trcls, badge = NOVEL.get(key, ("", ""))
    tds = []
    for code, raw in zip(codes, parts[2:]):
        h = cell(raw, code)
        if code == "CPR" and badge:
            h += f'<span class="novel-badge{" is-combo" if trcls == "is-combo" else ""}">{badge}</span>'
        tds.append(h + "</td>")
    tr = f' class="{trcls}"' if trcls else ""
    rows.append(f'<tr{tr}><th scope="row"><span class="rubric-code">{key}</span>{LABEL[key]}</th>{"".join(tds)}</tr>')

fam = [c for c in codes if c in FAMOUS]
close = [c for c in codes if c not in FAMOUS and c != "CPR"]
head = (f'<thead><tr class="rubric-colgroups"><th scope="col" rowspan="2">Criterion</th>'
        f'<th scope="colgroup" colspan="{len(fam)}" class="is-famous">Famous request-level routers</th>'
        f'<th scope="colgroup" colspan="{len(close)}">Close single-agent methods</th>'
        f'<th scope="col" rowspan="2" class="is-ours">{btn("CPR")}</th></tr><tr>'
        + "".join(f'<th scope="col" class="is-famous">{btn(c)}</th>' for c in fam)
        + "".join(f'<th scope="col">{btn(c)}</th>' for c in close) + "</tr></thead>")
caption = ('<caption>Famous request-level routers for reference, then the single-agent methods closest to CheckpointRouter. '
           '● has it · ◐ partial or weaker form · · absent · – not applicable · ? not yet verified · ☐ planned for CPR, not yet built. '
           'Re-checked 2026-10-26 against each paper’s method and experiment sections, then against released code for RouteLLM, FrugalGPT, Avengers-Pro, LiteLLM, vLLM SR, MTRouter, ACON, TRACE and TwinRouterBench; the other methods have no public code, so their cells are paper-only. '
           'Per-cell evidence is in <a href="https://github.com/cs24mtech15016-oss/ai-gateway-ops/blob/main/RUBRIC.md" target="_blank" rel="noreferrer">RUBRIC.md</a>; '
           'terms are defined in <a href="https://github.com/cs24mtech15016-oss/ai-gateway-ops/blob/main/DEFINITIONS.md" target="_blank" rel="noreferrer">DEFINITIONS.md</a>. <b>Click a method name for its details.</b></caption>')
table = ('<div class="table-wrap rubric-wrap"><table class="rubric-table">\n            ' + caption + '\n            ' + head
         + '\n            <tbody>\n' + "\n".join("              " + r for r in rows) + '\n            </tbody>\n          </table></div>')
data = {c: {**METHODS[c], "short": NAMES[c], "cells": cells_of(c)} for c in codes}
table += ('\n          <script type="application/json" id="method-data">'
          + json.dumps({"labels": LABEL, "methods": data}, ensure_ascii=False).replace("</", "<\\/")
          + '</script>')

path = f"{root}/docs/rubric.html"
html = open(path).read()
new, n = re.subn(r'<div class="table-wrap rubric-wrap">.*?</table></div>(\s*<script type="application/json" id="method-data">.*?</script>)?', lambda _: table, html, flags=re.S)
assert n == 1, n
open(path, "w").write(new)
print("rows", len(rows), "cols", ncols)
