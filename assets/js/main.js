// remesch.com — no dependencies, no build step. Loaded with `defer`.
// The pre-paint theme resolution lives inline in _includes/head.html; this only
// handles the toggle itself.
(function () {
  "use strict";

  var root = document.documentElement;
  var toggle = document.querySelector("[data-theme-toggle]");
  if (!toggle) return;

  var media = window.matchMedia("(prefers-color-scheme: dark)");

  function currentTheme() {
    return root.getAttribute("data-theme") || (media.matches ? "dark" : "light");
  }

  function syncLabel() {
    var next = currentTheme() === "dark" ? "light" : "dark";
    toggle.setAttribute("aria-label", "Switch to " + next + " theme");
  }

  toggle.addEventListener("click", function () {
    var next = currentTheme() === "dark" ? "light" : "dark";
    root.setAttribute("data-theme", next);
    try {
      localStorage.setItem("theme", next);
    } catch (e) {
      // Private browsing; the choice just won't persist across pages.
    }
    syncLabel();
  });

  // Follow the OS until the visitor makes an explicit choice.
  media.addEventListener("change", function () {
    if (!root.hasAttribute("data-theme")) syncLabel();
  });

  syncLabel();
})();
