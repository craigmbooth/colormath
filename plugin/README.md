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

## Adding a skill

One directory per skill: `skills/<name>/SKILL.md` with frontmatter
(`name`, `description`, optional `argument-hint` / `allowed-tools` / `model`).
The directory name is the command name (`/colormath:<name>`). Document the
skill in this README, keep it consumer-agnostic (no product names, no
hardcoded default branch), and note in the changelog which contract surfaces
it depends on — a rename of any of them must ship with the skill update in
the same release.
