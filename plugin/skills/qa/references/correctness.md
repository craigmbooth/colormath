# Correctness probes

Security bugs get reported; correctness bugs get *believed*. A wrong number
delivered confidently is worse than an error, because nobody investigates it.
Bias toward the failures that don't announce themselves.

## Cross-surface consistency — start here

When two surfaces read the same underlying data, make them agree. This is the
richest seam in a mature codebase and it produces no error at all.

The shape: a UI page and an API both answer "what metrics does this company
track". The page renders twenty rows. The API returns an empty list. Neither
errors. The API is reading a legacy table that a newer template-driven system
no longer populates, and it has been quietly answering "nothing" for every
record since the migration.

How to find it: for each read your surface offers, find the *other* reader of
the same concept — the web page, the export, the report, the agent tool — and
compare answers for the same record. Divergence is either a bug or a
deliberate difference nobody wrote down; both are worth surfacing.

Watch especially for two implementations of one concept where a migration
stalled halfway. Grep for the service methods and see who calls which. An
empty result from a system mid-migration looks identical to "no data", which
is why it survives so long.

## Empty, zero, and absent

Distinguish "no data" from "broken query". An empty list is the most
overlooked bug signal there is, because it renders as a legitimate state.

Whenever a read returns nothing, confirm the emptiness is *real* — check the
underlying rows directly. If the store has data and the surface says none,
you've found something. Equally, check a record you know is populated so
you're not validating against an empty fixture.

Related: does the seed data actually exercise this feature? If a whole
subsystem has no seeded rows, that's why nobody noticed it was broken, and
it's worth reporting on its own — untested by construction.

## Write paths and round trips

Reads are easy to eyeball; writes are where state gets corrupted.

- **Round-trip everything you write**: submit a value, read it back through a
  *different* surface, confirm it survived with the right type, precision, and
  timezone.
- **State transitions**: does the write that should close an open request
  actually close it? Does it close only the right one?
- **Idempotency**: submit the same thing twice. Duplicate rows, double-applied
  effects, or a second call erroring where it should no-op.
- **Ordering**: does the newest write win when it should? Ties are frequently
  resolved by insertion order when the domain wants something else.
- **Partial failure**: if a write does two things (store a file, enqueue a
  job), make the second fail and check the first isn't left orphaned.

## Boundaries and units

- **Dates**: period starts after ends; single-day periods; a range spanning a
  year or DST; timezone-naive values crossing a boundary. Ranges accepted
  backwards produce silently empty results forever after.
- **Units and scale**: is a percentage stored as `0.15` or `15`? Currency in
  units or cents? A factor-of-100 error looks plausible on a dashboard, which
  is exactly why it ships.
- **Aggregates**: check a median/mean against hand-computed values on a small
  set, especially when nulls or a poisoned value are present.
- **Sorting and pagination**: a non-deterministic sort makes page 2 drop rows
  that page 1 already showed.

## Contracts and documentation

Where a surface publishes a description of itself — an OpenAPI schema, a tool
definition consumed by an LLM, a docstring another team codes against — the
description *is* the contract, and drift is a real defect.

Check that documented enum values match what the code can actually return. A
tool description listing three roles when a fourth now exists will have
consumers treating that fourth as impossible; if the new value means "this
person left the company", a model reading the stale description will happily
assign them work.

For LLM-facing tools specifically: the description is the only thing standing
between the model and misuse. Vague or stale descriptions cause silently wrong
behavior rather than errors.

## Concurrency

Where it's cheap to check: two simultaneous writes to the same record, a
job running while a user edits the same row. Lost updates and unique-violation
crashes both show up quickly. Don't build elaborate harnesses — note the risk
if the cost of proving it is high, and mark it as unproven.

## Regressions in the seams

Recently changed code is worth extra attention, but so is the code *adjacent*
to it. A new role, field, or state usually needs handling in more places than
the original change touched: serializers, filters, exports, permission checks,
and the surfaces that enumerate valid values. Grep for the places that
enumerate the old set and see which ones never learned about the new member.
