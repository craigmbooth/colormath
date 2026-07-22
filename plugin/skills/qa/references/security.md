# Security probes

Ordered by how often they pay out. You're testing the user's own platform on
their instruction — probe it hard, but stay on it: no third-party systems, no
production, no other people's data.

## Contents

- [Authorization matrix](#authorization-matrix) — the highest-yield probe
- [Confused deputy / IDOR](#confused-deputy--idor)
- [Authentication edges](#authentication-edges)
- [Stored content served back](#stored-content-served-back)
- [Input validation](#input-validation)
- [Error and log disclosure](#error-and-log-disclosure)
- [Rate limiting](#rate-limiting)

## Authorization matrix

Take every operation on the surface and every identity from recon, and check
the answer for each pair. It's tedious and it finds more real bugs than
anything else here, because authorization is enforced per-handler and one
missed decorator is invisible until someone tries it.

Script it rather than doing it by hand — a small loop printing
`allowed/denied` against `expected` per cell makes a gap obvious and gives you
the repro for free.

The cells that matter most:

- **Cross-tenant**: an admin of tenant A against tenant B's resources. Being
  powerful *somewhere* must not mean powerful *everywhere*.
- **Tier boundaries**: a viewer attempting every write; a mid-tier attempting
  admin-only operations.
- **The no-access role**: a disabled or departed membership must resolve to no
  access on every single operation, not just the ones someone remembered.
- **Scope mismatch**: an identity with access to a company but not the
  organization above it (or vice versa) — nesting is where reasoning slips.

Check the *negative* direction too: legitimate access that's wrongly denied is
a real bug, and a matrix that denies everything can look like a pass.

## Confused deputy / IDOR

Pass one identifier you're entitled to alongside another you aren't, and see
which one the handler actually trusts. `{"company_id": <mine>, "record_id":
<theirs>}` is the canonical shape: if the code authorizes on `company_id` and
then loads `record_id` without checking it belongs, you can act on anything.

Try it on every endpoint taking two or more IDs, and on any "correct/edit this
existing thing" operation, where the pattern is most common.

## Authentication edges

Cheap to run, occasionally catastrophic:

- No credential at all; malformed header; right credential, wrong scheme.
- A **revoked** credential — revocation that isn't checked on the read path is
  a classic.
- A credential belonging to a deleted or deactivated user.
- Expiry, if the scheme has it.

Confirm failures are uniform. An error that distinguishes "no such user" from
"wrong password" is an account-enumeration oracle.

## Stored content served back

Anywhere a user supplies bytes and the app later hands them to a browser,
check what actually goes over the wire — not what the upload validator
intended.

- **Who chooses the content type?** If it's stored from the caller's input and
  echoed back as the response `Content-Type`, an attacker picks how the
  browser interprets the file.
- **`Content-Disposition`**: `inline` renders in-page on your origin;
  `attachment` downloads. Inline plus an attacker-chosen type is the
  dangerous combination.
- **Enumerate every ingestion path**, not just the obvious upload form. An API
  upload, a cloud-drive sync, and an inbound email attachment can all land in
  the same store under different validation. The weakest one sets the security
  of the whole store — and an inbound-email path may need no account at all,
  which changes the severity completely.
- **Read the CSP, don't assume it.** Load the page in a browser and look at
  what's blocked and what runs. A nonce-based policy stops inline `<script>`,
  so the naive payload fails — while an allowlisted CDN in `script-src` lets
  `<script src="https://allowed-cdn/...">` execute on your origin anyway.
  Report the chain you actually observed.
- **Filenames** reach an HTTP header. Quotes and CRLF in a filename that lands
  unescaped in `Content-Disposition` is header injection; check what survives.
- SVG is script-capable. Treating it as "just an image" is a common miss.

## Input validation

Aim at the boundary between the parser and the store, where a value is legal
to one and impossible to the other:

- **Non-finite numbers**: `NaN`, `Infinity`. Many decimal parsers accept these
  happily and the DB stores `NaN` without complaint — after which every
  aggregate over that column is poisoned, and JSON serialization emits a bare
  `NaN`, which is not valid JSON and breaks strict clients.
- **Magnitude**: values past the column's precision, exponent notation
  (`1e400`).
- **Strings**: past the column width; control characters and NUL, which
  Postgres rejects outright in text.
- **Identifiers**: malformed UUIDs, empty strings, well-formed IDs that don't
  exist, IDs belonging to another tenant.
- **Ranges**: a field documented as 0–1 accepting `5` or `-1`. Out-of-range
  filters fail silently — too high matches nothing, too low matches
  everything, and both look like a legitimate answer.
- **Collections**: zero, negative, and enormous limits; deep nesting.

## Error and log disclosure

Anything that reaches a caller should be intentional. Raw driver exceptions
(`asyncpg.exceptions.*`, `sqlalchemy.*`) leak schema details, and a stack
trace leaks paths and versions. Note where an internal exception escapes as-is
rather than being converted to a clean validation error — it's both an
information leak and a bad experience.

Check the logs while you're at it: credentials, tokens, or personal data
written in plaintext is a finding even though nothing visibly breaks.

## Rate limiting

If the surface is rate limited, confirm it triggers, and confirm it's scoped
per-identity rather than globally — a shared limit lets one caller starve
everyone behind the same NAT. If it isn't limited at all, note the abuse cost
on expensive endpoints (anything doing LLM calls, mail, or large exports).
