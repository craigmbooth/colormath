---
name: ship
description: Open a PR, wait for gates + review, triage feedback, recommend next step
argument-hint: [optional PR title]
allowed-tools: Bash(gh pr create:*) Bash(gh pr view:*) Bash(gh pr checks:*) Bash(gh pr diff:*) Bash(gh pr comment:*) Bash(gh api:*) Bash(git push:*) Bash(git status:*) Bash(git log:*) Read Edit Grep Glob
model: claude-sonnet-4-6
---

Ship the current branch through the PR pipeline end to end. This repo uses
the colormath (ColorMath/ci) gates and, optionally, its review workflow. Use
the `gh` CLI for every GitHub operation. Give me a one-line status at each
step.

## 1. Open the PR
- Push the branch if needed (`git push -u origin HEAD`).
- Create the PR with `gh pr create`. Use "$ARGUMENTS" as the title if provided,
  otherwise derive one from the branch's commits. Write a body that summarizes
  the diff and calls out anything a reviewer should look at.
- Capture the PR number for the steps below.

## 2. Poll the gates until green
- Run `gh pr checks <number> --watch --fail-fast --interval 30`.
  This blocks until checks finish: exit 0 = all green, non-zero = something
  failed. (Don't add `--required` — these repos typically have no branch
  protection, so gh reports "no required checks" and exits 1 immediately.)
- The gates are the checks whose names start with `gates / `. The watch also
  covers the review-suite checks (`review / ...`) when the repo runs them —
  if the early failure is one of those, it is NOT a gate failure; note it and
  handle it in step 3.
- If a gate fails: pull the failing job's logs, fix the cause on this branch,
  commit, push, and re-run the watch. Repeat until green.
- Do NOT proceed to review while any gate is red.

## 3. Poll until a review lands
First check whether this repo runs the colormath review workflow: look for a
workflow under `.github/workflows/` whose job `uses:`
`ColorMath/ci/.github/workflows/review.yml`. If there is none, skip to step 4
with whatever formal reviews exist, and say explicitly that no automated
review is configured.

Two reviewers may weigh in, and they land in **different places** — know which
is which or you'll wait forever on the wrong one:
- **Thermonuclear review** (the colormath review workflow): runs as a
  non-required check named `review / review` (the reusable workflow prefixes
  the caller's job name, `review` by colormath convention) and posts its
  findings as a PR **comment** (the bot's tracking comment), led by the marker
  line `## Thermonuclear Review`. It is **NOT** a formal review — it never
  appears in `--json reviews`, only in `--json comments`. This is the common
  case.
- **Adversarial / human review**: posts as a formal review, which *does*
  appear in `--json reviews`.

Wait until the thermonuclear `review / review` check finishes **or** a formal
review is submitted — whichever comes first — polling every 30s. Read the
check state from `statusCheckRollup` (do **not** parse `gh pr checks` columns
with awk `$1`/`$2` — this file is a skill, and `$1`/`$2` get clobbered by
skill-argument substitution):
```bash
PR=<number>
until \
  [ -n "$(gh pr view "$PR" --json statusCheckRollup --jq '.statusCheckRollup[] | select(.name=="review / review" and .status=="COMPLETED")' 2>/dev/null)" ] || \
  [ "$(gh pr view "$PR" --json reviews --jq '[.reviews[] | select(.state=="CHANGES_REQUESTED" or .state=="COMMENTED" or .state=="APPROVED")] | length')" -gt 0 ]; do
  sleep 30
done
```
- **Check the review actually ran.** If the `review / review` check concluded
  `FAILURE`
  (`gh pr view <number> --json statusCheckRollup --jq '.statusCheckRollup[] | select(.name=="review / review") | .conclusion'`)
  and **no** `## Thermonuclear Review` comment exists, the review job *errored
  before posting* — do not treat the absence of findings as a clean review.
  The most common cause: a PR that edits the review caller workflow itself
  trips the GitHub-App workflow-validation guard ("workflow file must … have
  identical content to the version on the default branch"), so the review can
  only run once the change is on the default branch. Report this to me instead
  of recommending merge on a silent review.
- Then read everything from **both** sources: `gh pr view <number> --json
  reviews,comments` (the thermonuclear findings are in `comments` under the
  `## Thermonuclear Review` marker; adversarial/human findings are in
  `reviews`) plus the inline comments via
  `gh api repos/{owner}/{repo}/pulls/<number>/comments`.
- Read each review/comment's **full body** — never truncate or slice it (no
  `--jq '.body[0:N]'`, no `head -c`/`head -n`, no `| head`). A finding you
  don't read is a finding you'll miss; relay every one to me, including the
  ones buried below the summary header.

## 4. Triage, then recommend
Classify the overall review as SMALL or LARGE using the severity tags the
reviewers emit (Blocker / Suggestion / Nit, and [high-confidence] /
[speculative]).

SMALL — ALL of these hold:
- No Blocker, and no [high-confidence] correctness or security finding.
- Fixes are mechanical and localized (guards, renames, small refactors, added
  tests) touching few files.
- No design or architectural decision is required.
Action: make the fixes on this branch, commit, push, let the gates re-run
green, then post a response comment (see Rules) and STOP and report:
"Gates green, review addressed, changes are small — recommend merge."
Do not merge.

LARGE — ANY of these hold:
- A Blocker, or any [high-confidence] security/correctness finding.
- A structural / "code judo" restructuring suggestion, anything spanning
  multiple modules, or anything needing a design call.
- Review state is CHANGES_REQUESTED on substantive grounds.
Action: do NOT push speculative fixes. Summarize the key findings, what
addressing them would involve, and your recommended approach, then STOP and
report: "This needs human review before merge — here's why: ..."

## Rules
- Never push to the default branch. Never merge — a merge is always my
  decision.
- **Whenever you push a commit that responds to a review, post a PR comment**
  (`gh pr comment <number>`) detailing what you did and did not do: group it as
  **Addressed** (each finding + the change that resolved it) and **Not changed**
  (each finding you skipped + why). Reply on the relevant inline threads too,
  but the summary comment is required even when every finding was addressed.
- Your job ends at a recommendation.
