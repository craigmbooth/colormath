# colormath plugin

Claude Code skills for repos built on the colormath (ColorMath/ci) shared
infrastructure. Install via the marketplace at the repo root — see the
[main README](../README.md#optional-claude-code-plugin) — then invoke each
skill as `/colormath:<skill>`.

Skills here encode the colormath *contract* — gate check names, comment
markers, make endpoints. That's the test for whether a skill belongs in this
plugin: if it would work in any repo, it goes elsewhere; if it greps for
`gates / *` or `## Thermonuclear Review`, it lives here, so a release that
changes the contract ships the matching skill change in the same diff.

## `/colormath:ship` — PR pipeline end to end

Takes the current branch through the full PR pipeline and stops at a
recommendation:

1. **Open the PR** — pushes the branch, creates the PR (`gh pr create`) with a
   diff-summarizing body; takes an optional PR title as its argument.
2. **Watch the gates** — polls until every `gates / *` check is green; on a
   red gate it reads the failing job's logs, fixes the cause on the branch,
   pushes, and re-watches.
3. **Wait for review** — if the repo calls colormath's review workflow, waits
   for the `review / review` check and reads the `## Thermonuclear Review`
   comment (plus any formal/human reviews and inline comments — full bodies,
   never truncated). Skips this wait, and says so, in repos without the
   review workflow. Knows the review's failure modes (e.g. the
   workflow-validation guard when a PR edits the review caller itself) and
   reports them instead of treating silence as a clean review.
4. **Triage and recommend** — classifies findings SMALL (mechanical,
   localized, no design call) or LARGE (blockers, high-confidence
   correctness/security, structural suggestions). SMALL: applies the fixes,
   posts an **Addressed / Not changed** response comment, recommends merge.
   LARGE: summarizes and hands back to you.

Hard rules baked in: it never pushes to the default branch and never merges —
merging is always a human decision.

**Prerequisites:**

- An authenticated `gh` CLI with push access to the repo.
- The colormath gates caller (`.github/workflows/gates.yml`) — step 2 keys on
  the `gates / *` check names it produces.
- Optional: the colormath review caller (job named `review`, per the adoption
  docs) — step 3 keys on the `review / review` check and the
  `## Thermonuclear Review` comment marker.
- The skill pre-approves only the tools it needs (`gh pr *`, `gh api`,
  `git push`, and read/edit tools) via its frontmatter `allowed-tools`;
  consumer repos can mirror that list in `.claude/settings.json` permissions
  to avoid prompts (see intendent for a worked example).

## `/colormath:qa` — QA a feature, then ship the fixes

Takes a focus area (`/colormath:qa the invite flow`) and QAs it against the
**running** stack, on the principle that a finding is a claim about a running
system and only counts once you've reproduced it:

1. **Scope** — maps the area to the routes, services, jobs and templates that
   implement it, and notes the trust boundaries it crosses.
2. **Recon** — brings the stack up (checking first whether it's already
   running, so it doesn't reseed someone's working environment) and collects
   credentials at *several* privilege tiers, including cross-tenant and any
   no-access role. A single admin account can't surface an authorization bug.
3. **Probe** — works three catalogs in `references/`: security (authorization
   matrix, confused-deputy, stored content served back, input validation),
   correctness (cross-surface consistency, write round-trips, contract drift),
   accessibility (keyboard, semantics, announcements, contrast). Sweeps before
   fixing anything.
4. **Verify** — reproduces every finding and reports the mechanism actually
   observed, not the assumed one. Separates pre-existing failures from real
   ones before attributing anything.
5. **Report and choose** — ranked findings with blast radius and repro, plus
   what came back clean and what wasn't covered; you pick what to fix.
6. **Fix, restore, ship** — re-runs each original repro against the running
   system (a green unit test isn't proof the bug is gone), undoes its test
   data and config changes, then hands off to `/colormath:ship`.

Local state is fair game — it writes rows, uploads files, mints credentials —
but it stops and asks before anything leaves the machine, because a dev `.env`
often holds a live provider key.

**Prerequisites:**

- A locally runnable stack, with the run commands and ports documented in
  `AGENTS.md` / `CLAUDE.md` (the skill reads these first).
- Seeded demo data with known accounts, ideally at several privilege tiers.
- `make preflight` and the `gates / *` check names — step 4 uses them to tell
  a genuine finding from local tool-version drift, and defers to CI when the
  two disagree.
- `/colormath:ship` for the handoff in step 6.

## Adding a skill

One directory per skill: `skills/<name>/SKILL.md` with frontmatter
(`name`, `description`, optional `argument-hint` / `allowed-tools` / `model`).
The directory name is the command name (`/colormath:<name>`). Document the
skill in this README, keep it consumer-agnostic (no product names, no
hardcoded default branch), and note in the changelog which contract surfaces
it depends on — a rename of any of them must ship with the skill update in
the same release.
