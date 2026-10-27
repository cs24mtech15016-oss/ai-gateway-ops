const header = document.querySelector("[data-header]");
const reveals = document.querySelectorAll(".reveal");
const mobileNav = document.querySelector("[data-mobile-nav]");

const setHeaderState = () => {
  header?.classList.toggle("is-scrolled", window.scrollY > 24);
};

setHeaderState();
let scrollPending = false;
window.addEventListener("scroll", () => {
  if (scrollPending) return;
  scrollPending = true;
  window.requestAnimationFrame(() => {
    setHeaderState();
    scrollPending = false;
  });
}, { passive: true });
window.addEventListener("resize", setHeaderState);

mobileNav?.addEventListener("click", (event) => {
  if (!event.target.closest("nav a")) return;
  mobileNav.open = false;
});
document.addEventListener("keydown", (event) => {
  if (event.key !== "Escape" || !mobileNav?.open) return;
  mobileNav.open = false;
  mobileNav.querySelector("summary")?.focus();
});

if ("IntersectionObserver" in window) {
  const revealObserver = new IntersectionObserver(
    (entries, observer) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    },
    { threshold: 0.08 }
  );
  // Enable progressive animation only after the observer is ready. Content stays
  // visible if this script fails to load; reduced-motion and print override it.
  document.documentElement.classList.add("js");
  reveals.forEach((element) => revealObserver.observe(element));
} else {
  reveals.forEach((element) => element.classList.add("is-visible"));
}

// Rubric: method sidebar, opened from the matrix column headers.
const methodData = document.getElementById("method-data");
const methodPanel = document.getElementById("method-panel");
if (methodData && methodPanel) {
  const { labels, methods } = JSON.parse(methodData.textContent);
  const order = Object.keys(methods);
  const scrim = document.querySelector("[data-method-scrim]");
  const part = (key) => methodPanel.querySelector(`[data-mp="${key}"]`);
  const MARK = { "✅": ["mk-yes", "●"], "◐": ["mk-part", "◐"], "·": ["mk-no", "·"], "–": ["mk-na", "–"], "?": ["mk-q", "?"], "☐": ["mk-plan", "☐"] };
  const el = (tag, cls, text) => { const n = document.createElement(tag); if (cls) n.className = cls; if (text != null) n.textContent = text; return n; };
  let current = null;
  let opener = null;

  const highlight = (code) => {
    document.querySelectorAll(".rubric-table .is-selected").forEach((n) => n.classList.remove("is-selected"));
    if (!code) return;
    const th = document.querySelector(`.method-btn[data-method="${code}"]`)?.closest("th");
    if (!th) return;
    th.classList.add("is-selected");
    const table = th.closest("table");
    const col = [...th.parentElement.children].indexOf(th) + (th.parentElement.classList.contains("rubric-colgroups") ? 0 : 1);
    table.querySelectorAll("tbody tr:not(.rubric-group)").forEach((tr) => tr.children[col]?.classList.add("is-selected"));
  };

  const render = (code) => {
    const m = methods[code];
    current = code;
    part("type").textContent = m.type;
    part("name").textContent = m.name;
    part("does").textContent = m.does;
    part("relation").textContent = m.relation;
    part("problem").textContent = m.problem || "";
    const links = part("links");
    links.replaceChildren();
    if (m.paper) { const a = el("a", "", m.paper_label || "Paper ↗"); a.href = m.paper; a.target = "_blank"; a.rel = "noreferrer"; links.append(a); }
    if (m.code) {
      const a = el("a", "", `Code ↗ (${m.code[1]})`); a.href = m.code[0]; a.target = "_blank"; a.rel = "noreferrer"; links.append(a);
      links.append(el("span", "method-tag is-code", `Checked against code: ${m.checked}`));
    } else {
      links.append(el("span", "method-tag", m.code_note || "No public code found — cells are paper-only"));
    }
    if (m.code && m.code_note) links.append(el("span", "method-tag", m.code_note));
    const notes = part("notes");
    notes.replaceChildren(...m.notes.map((t) => el("li", "", t)));
    const scores = part("scores");
    scores.replaceChildren();
    for (const [key, raw] of Object.entries(m.cells)) {
      const [sym, ...rest] = raw.split(" ");
      const [cls, glyph] = MARK[sym] || ["", sym];
      const row = el("div", "method-score");
      row.append(el("span", "rubric-code", key), el("span", "method-score-label", labels[key]));
      const mk = el("span", `mk ${cls}`, glyph);
      if (rest.length) mk.title = rest.join(" ").replace(/[()]/g, "");
      row.append(mk);
      scores.append(row);
    }
    highlight(code);
  };

  const open = (code, from) => {
    opener = from || opener;
    render(code);
    methodPanel.hidden = false;
    scrim.hidden = false;
    requestAnimationFrame(() => { methodPanel.classList.add("is-open"); scrim.classList.add("is-open"); });
    methodPanel.focus({ preventScroll: true });
  };
  const close = () => {
    methodPanel.classList.remove("is-open");
    scrim.classList.remove("is-open");
    highlight(null);
    current = null;
    setTimeout(() => { if (!current) { methodPanel.hidden = true; scrim.hidden = true; } }, 220);
    opener?.focus();
  };

  document.addEventListener("click", (event) => {
    const btn = event.target.closest(".method-btn");
    if (btn) { current === btn.dataset.method ? close() : open(btn.dataset.method, btn); return; }
    if (event.target.closest("[data-method-close]") || event.target === scrim) { close(); return; }
    if (current && !event.target.closest(".method-panel")) { close(); return; }
    const step = event.target.closest("[data-method-step]");
    if (step && current) {
      const i = (order.indexOf(current) + Number(step.dataset.methodStep) + order.length) % order.length;
      open(order[i]);
    }
  });
  document.addEventListener("keydown", (event) => {
    if (!current) return;
    if (event.key === "Escape") close();
    if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
      if (event.target.closest("input, textarea")) return;
      const i = (order.indexOf(current) + (event.key === "ArrowRight" ? 1 : -1) + order.length) % order.length;
      open(order[i]);
    }
  });
}
