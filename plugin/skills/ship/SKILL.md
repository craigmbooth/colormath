---
name: ship
description: Open a PR, wait for gates + review + test plan, execute the test plan against the running stack, fix every finding (blockers included), then decide once — auto-merge when clean, or hold for a human. Never re-triggers the review.
argument-hint: [optional PR title]
allowed-tools: Bash Read Edit Write Grep Glob Skill AskUserQuestion
model: claude-sonnet-4-6
---

Ship the current branch through the PR pipeline end to end. This repo uses
the colormath (ColorMath/ci) gates and, optionally, its review workflow — which
runs two agents in parallel: the thermonuclear **review** and a **test plan**
that you then execute against the running stack. You **fix** what the review
and the QA turn up — blockers included, without asking — and end at a **merge
decision** that either auto-merges the PR (when it's genuinely clean) or holds
and asks for a human. Use the `gh` CLI for every GitHub operation. Give me a
one-line status at each step.

The shape is linear and runs **once**: review → respond + QA → decide. There is
no second review round; see step 5.

Broad `Bash` is in `allowed-tools` on purpose: step 4 drives the local stack
(`make up`, DB queries, `curl`, throwaway driver scripts) to actually run the
test plan, which no narrow `gh`/`git` allowlist can cover.

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
`ColorMath/ci/.github/workflows/review.yml`. If there is none, skip step 4 (no
test plan is generated either) and go straight to step 5 with whatever formal
reviews exist; say explicitly that no automated review is configured. Note for
step 7: with no automated review + QA to stand on, the merge decision **holds** —
it does not auto-merge a PR it couldn't verify.

That workflow also runs a **third** parallel agent — the test-plan agent
(check `review / test-plan`, comment marked `## Test Plan`). It is neither a
review nor a gate; step 4 waits for it and executes it. Don't confuse its
check or comment with the review's here.

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

## 4. Execute the test plan
The test-plan agent runs in parallel with the review and posts its own PR
comment — a concrete QA checklist specific to this diff. Your job here is to
**run it against the running stack and report what actually happened**, the
same principle the `qa` skill is built on: a checklist item is a claim about a
running system and only counts once you've watched the system confirm or break
it. A green gate suite does not exercise the rendered UI or most request/
response behavior — that gap is exactly what this plan covers.

If no colormath review workflow is configured (step 3), there is no test plan;
skip this step and say so.

**Wait for it, then read all of it.**
- Wait until the `review / test-plan` check completes (it may already be done —
  it runs alongside the review). Poll `statusCheckRollup` every 30s, the same
  way step 3 does (read the check by `.name=="review / test-plan"`; do **not**
  awk `gh pr checks` columns — `$1`/`$2` get clobbered by skill-argument
  substitution).
- If the check concluded `FAILURE` and **no** `## Test Plan` comment exists, the
  agent errored before posting — say so and do not treat the absence of a plan
  as "nothing to test."
- Read the **full** comment body — never truncate (no `--jq '.body[0:N]'`, no
  `head`). Pull the latest test-plan comment by its hidden marker:
  ```bash
  PR=<number>
  gh pr view "$PR" --json comments \
    --jq '[.comments[] | select(.body | contains("<!-- colormath-test-plan -->"))] | last | .body'
  ```
- Parse the machine-readable verdict from the hidden marker line
  `<!-- testplan qa_depth=<low|medium|high> requires_ui_qa=<bool> requires_api_qa=<bool> -->`.
  It tells you the scope: skip a checklist section the plan marked N/A, and let
  `qa_depth` set your effort (a `low` copy tweak is a couple of checks; a `high`
  auth/migration change earns the full matrix).

**Set up like the `qa` skill does.** Read that skill's `references/recon.md`
before touching anything: bring the stack up **only if it isn't already
running** (don't reseed someone's working environment), get credentials at the
privilege tiers the plan's steps name, and **record a baseline** (row counts
for tables you'll write, current values of any config you'll change) so step 6
can restore it. Treat local state as yours to mutate; a throwaway driver script
that authenticates as each identity turns a long checklist into one loop.

**Work each item, and prove it.** For every checkbox in the plan:
- **API / backend items** — drive them yourself over the real transport
  (`curl`/driver script against the running app), not by calling functions
  in-process. Record the exact request, the response, and whether it matched
  the expected result the plan states.
- **UI items** — drive them through a browser **if one is reachable** (the
  browser automation tools); capture what you observed. **If no browser is
  reachable**, do not guess: leave those items marked ⚠️ unverified and say
  plainly they need a human to click through. Never report a UI item as passed
  on inspection of the code alone.
- Borrow the relevant probe discipline from the `qa` skill's `references/`
  catalogs (`security.md` / `correctness.md` / `accessibility.md`) when an item
  calls for it (an authorization row, a write round-trip, a keyboard path).

**Separate real failures from noise.** Before you call an item failed, decide
whether it's a genuine regression in this diff, a pre-existing issue on the
base branch, or a local environment artifact (local tool/service versions drift
from CI — CI is the authority when they disagree). Only genuine regressions in
this PR's change are findings.

**Ask before anything leaves the machine** — outbound email through a
configured provider, third-party API calls, writes to a shared/remote
environment. A dev `.env` often holds a *live* key, so "it's only the dev
stack" is not a reason to assume a send won't actually deliver. Offer to
redirect locally instead.

**Post the results back to the PR.** Add one comment led by exactly this marker
so it's findable and idempotent (edit the existing one on a re-run rather than
stacking duplicates):

    ## Test Plan · Results

Under it, reproduce the plan's checklist with each item marked `✅` pass, `❌`
fail, or `⚠️` unverified (with the reason — e.g. "no browser available"), each
carrying the concrete evidence you observed (the request + response, the
screen state, the row you read). Then a short **Findings** list of every `❌`,
worst first, with its blast radius and the exact repro; and a one-line note of
what you did **not** cover. If everything passed, say so explicitly. Never
truncate a finding.

Carry the `❌` findings into step 5 to be fixed, exactly like review findings.

## 5. Fix every finding — blockers included
This is not a recommendation step: **fix, don't ask.** Work every finding from
the review and every `❌` from your test-plan results — **Blockers included** —
on this branch, matching the surrounding code's idiom and adding a regression
test at the layer the finding lived at. A correctness or security Blocker is
exactly the kind of thing to fix now, not defer.

There are two kinds of finding you genuinely cannot auto-fix — do **not** fake a
fix or paper over one:
- One needing a **design decision** or judgment call — two valid approaches, a
  product tradeoff, an intended-behavior question.
- A **structural / "code judo"** restructuring spanning multiple modules, or
  anything a reviewer raised as `CHANGES_REQUESTED` on substantive design
  grounds.
Leave those unfixed and record them clearly. They are what step 7 weighs when
it decides whether to hold the merge — an honest "deferred to a human" is fine;
a silent skip is not.

Then close the loop:
- **Re-verify against the running system.** Re-run each QA repro you fixed; a
  green unit test is not proof the bug is gone (step 4's rule). Keep fixing and
  re-running until every `❌` you can resolve is `✅`, or you hit one of the
  can't-auto-fix findings above.
- Let the gates re-run green on the new commit.
- Post the **Addressed / Not changed** response comment (see Rules), and update
  the `## Test Plan · Results` comment to reflect the re-verified state.

**Do NOT re-trigger the review.** There is exactly **one** thermonuclear review
per ship run, and you have already read it. Commenting `@claude` to ask for a
fresh look is the one thing guaranteed to make this skill loop forever: a new
review spawns a new test-plan agent, whose new plan asks for a fresh round of
QA, whose fixes look "substantive" enough to justify another re-review. That
loop has no exit condition and burns a full QA cycle each time round.

You do not need a reviewer to bless your fixes — **you** re-verified them
against the running system, and the gates re-ran green on the new commit. That
is the evidence step 7 judges. Go straight there.

(A *human* who reviews after your fixes is different: read and address anything
they add, exactly as in step 5. This rule is only about not summoning another
automated review.)

## 6. Restore the environment
Step 4 treated local state as yours — undo it before the merge decision. Delete
the rows and files you created, revoke any credentials you minted, restore any
config or feature flag you changed, and confirm the baseline from step 4
matches. QA debris poisons the next run, and a flipped provider or flag left
flipped is its own outage. Restoring does not erase the QA *result* you already
recorded — step 7 still knows whether QA passed. Show me the restored state in
your final report. (Skip if step 4 was skipped or you mutated nothing.)

## 7. Merge decision — auto-merge, or hold and explain
The go/no-go, and the one place this skill merges. Reach it directly from step
5/6 — **never** via another review round. Decide from what you already have: the
single thermonuclear review, your responses to it, your QA results, and the
gates on the current commit.

Evaluate three gates against the **current** state of the branch:

1. **The review had no Blockers.** Judged from the thermonuclear review as
   posted. If it raised even one **Blocker**, hold for a human — *even if you
   fixed it*. You still fix it in step 5; a Blocker simply means a person signs
   off on the merge rather than this skill. Suggestions and nits never block.
2. **Every review finding is resolved or consciously dismissed.** Each one is
   either fixed, or dismissed with a written reason in the **Addressed / Not
   changed** comment. Nothing silently skipped, nothing left needing a design
   decision or a structural rework (step 5's can't-auto-fix pair), and no formal
   human review sitting at `CHANGES_REQUESTED`. Gates are green on the latest
   commit.
3. **QA ran, and every gap is explained.** The test plan executed — the stack
   came up and you drove the items — with **no `❌` left standing**. A `⚠️` does
   **not** block *if* you can say plainly why it was skipped and why skipping is
   sound. Legitimate, explainable gaps look like:
   - "Didn't run `make clean` — it would drop the working dev database. Ran the
     equivalent code path directly instead."
   - "Unicode/IDN addresses untested — the plan itself listed that as residual
     risk, not a required item."

   What is **not** explainable, and does block: QA that never ran at all, a
   required UI item you couldn't drive because no browser was reachable, a stack
   that wouldn't come up, or a `⚠️` with no stated reason. "I didn't get to it"
   is not an explanation. No review workflow at all → no test plan → this gate
   fails.

**All three true → auto-merge.** Post a PR comment saying you are merging and
why, naming the evidence: gates green, N findings addressed (0 Blockers), QA
run with N items `✅` and each `⚠️` and its reason listed. Then merge with
`gh pr merge <number>` using the repo's established convention — inspect recent
merges (`gh pr list --state merged`, or `git log`) and pass the matching flag
(`--squash` / `--merge` / `--rebase`); default to `--squash` if it's unclear.
Report the merge to me.

**Any false → hold and ask for a human.** Do **not** merge. Post a PR comment
that states plainly what held it off — each Blocker the review raised, each
finding deferred, and any QA item that failed or couldn't be performed (say
which and why) — plus what you'd do next and what you want the human to look at.
Then STOP and report the same to me: "Held off auto-merge — here's why: …".
When in doubt, hold: a wrong hold costs a human one click; a wrong merge is on
the default branch.

## Rules
- **Never push to the default branch** (`git push origin main`). Merging a PR
  via `gh pr merge` in step 7 is the sanctioned way to land it — that is not the
  same thing.
- **Fix automatically; don't ask before fixing.** Blockers included (step 5) —
  fixing a Blocker is automatic, *merging* after one is not. Auto-merge happens
  **only** from step 7, **only** with all three gates satisfied, and **always**
  with a PR comment posted first. If any gate fails, hold and explain — never
  merge on a silent or failed review, or on QA that couldn't run.
- **One review per run.** Read the thermonuclear review once (step 3), respond
  to it and do the QA (steps 4–5), then decide (step 7). Never comment `@claude`
  to request a re-review — it spawns a fresh test plan and a fresh QA round, and
  the cycle does not terminate.
- **Whenever you push a commit that responds to a review or a test-plan
  finding, post a PR comment** (`gh pr comment <number>`) detailing what you did
  and did not do: group it as **Addressed** (each finding + the change that
  resolved it) and **Not changed** (each finding you deferred + why). Reply on
  the relevant inline threads too, but the summary comment is required even when
  every finding was addressed.
- The `## Test Plan · Results` comment (step 4) is separate from that response
  comment and always required whenever a test plan ran — post the results even
  when nothing failed. On a re-run, edit the existing results comment instead of
  posting a second one.
- Your job ends at either a merge (with its comment) or a hold (with its
  explanation).
