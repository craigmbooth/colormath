// ----------------------------------------------------------------------------
// eslint.config.colormath.mjs — shared eslint base for colormath apps.
//
// Vendored from ColorMath/ci at COLORMATH_REF (see Makefile.colormath). Do
// not edit this file in your repo — `make colormath-update REF=vX.Y.Z`
// refreshes it together with Makefile.colormath.
//
// Your eslint.config.js stays a thin caller:
//
//   import { colormathConfig } from "./eslint.config.colormath.mjs";
//
//   export default [
//     ...colormathConfig({
//       cdnGlobals: { marked: "readonly" },   // page-level <script> libraries
//     }),
//     // escape hatch: append any flat-config block; later entries win
//   ];
//
// Customization, in increasing order of divergence:
//   1. factory options (below) — file globs, CDN globals, rule tweaks
//   2. appended config blocks — eslint's cascade lets the consumer override
//      anything without touching this file
//   3. ejecting — stop vendoring; sanctioned permanent divergence
//
// Peer expectations (consumer devDependencies): eslint >=9, @eslint/js,
// globals.
// ----------------------------------------------------------------------------

import js from "@eslint/js";
import globals from "globals";

export function colormathConfig({
  // Hand-written JS to lint. Add your test-file tree if it lives outside
  // static/js (e.g. ["static/js/**/*.js", "tests/**/*.test.js"]).
  files = ["static/js/**/*.js"],
  // Files that run under vitest/node rather than the browser.
  testFiles = ["static/js/**/*.test.js", "tests/**/*.test.js"],
  // Libraries loaded via <script> tags, e.g. { marked: "readonly" }.
  cdnGlobals = {},
  // Per-app rule overrides; spread last, so they win over the base rules.
  rules = {},
} = {}) {
  return [
    js.configs.recommended,
    {
      files,
      languageOptions: {
        ecmaVersion: 2024,
        sourceType: "module",
        globals: {
          ...globals.browser,
          Alpine: "readonly", // the archetype's frontend framework, CDN-loaded
          ...cdnGlobals,
        },
      },
      rules: {
        // Unused catch bindings and _-prefixed names are deliberate.
        "no-unused-vars": [
          "error",
          {
            argsIgnorePattern: "^_",
            varsIgnorePattern: "^_",
            caughtErrors: "none",
          },
        ],
        // Empty catch = intentional best-effort cleanup.
        "no-empty": ["error", { allowEmptyCatch: true }],
        ...rules,
      },
    },
    {
      files: testFiles,
      languageOptions: {
        globals: { ...globals.node, ...globals.vitest },
      },
    },
  ];
}
