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
