# Recon: running stack, real credentials

Goal: a platform you can drive, and enough identities to compare what
different callers are allowed to do. Budget a few minutes — recon that drags
eats the time you need for probing.

## Getting it up

**Check whether it's already running before starting anything.** A developer's
stack is usually up, often with hours of state in it. `docker compose ps`,
`docker ps`, or a curl at the app port answers this in one call. Restarting or
reseeding somebody's working environment is a rude way to open a QA session.

Run commands live in `AGENTS.md` / `CLAUDE.md` — typically a `make up` plus a
seed target, with the port map documented alongside. Take the ports from there
rather than guessing; colormath apps deliberately avoid default ports so
several products can run at once.

Useful things to note while you're there:

- **Is the code volume-mounted?** If the compose file bind-mounts source into
  the container, a restart picks up your edits and you can verify fixes in
  seconds. If not, you're rebuilding an image each time — plan around it.
- **Which services exist beyond the app** — a worker, a mail catcher, a DB
  admin UI. The mail catcher matters: it's where you send outbound mail during
  QA instead of a real provider.
- **Sibling services that are already broken.** Note them now so you don't
  later mistake somebody else's crashloop for your finding.

If seed data is missing, seed it. If the stack is up but a dependent service
is unhealthy, say so rather than working around it silently — it may be the
first finding.

## Finding seeded accounts

Demo/seed fixtures are the fastest source. Look for a `demo/`, `seeds/`, or
`fixtures/` directory holding JSON/YAML with users in it; these commonly carry
**plaintext passwords**, because their whole purpose is a reproducible demo
login. A repo that documents its demo users (`DEMO_USERS.md` and friends) is
telling you exactly what you need.

Otherwise query the database directly. Inspect the schema before writing
`SELECT`s — column names differ (`title` vs `name`, `global_role` vs
`is_superuser`) and a failed guess costs a round trip:

```
\d users
select column_name from information_schema.columns where table_name = 'X';
```

What you're after is not one login but **the role matrix**: which accounts sit
at which tier, and in which tenant. Join the membership tables and read it off.
Note any role that is supposed to grant *no* access — a departed-user or
disabled state — because "this role should be able to do nothing" is a
high-value thing to test and is often newer, thinner code.

## Getting credentials at every tier

You need, at minimum: an admin, a mid-tier (editor/member), a read-only
viewer, someone from a **different tenant**, and any no-access role. Without
the cross-tenant identity you cannot test isolation at all, and isolation is
where the expensive bugs are.

**Minting credentials directly against the dev DB is legitimate and much
faster than driving signup or invite flows** — as long as you match how the
app issues them. Find the service that creates the credential and copy its
scheme: the token format, the hash (often `sha256` of the plaintext), which
columns it fills, and how revocation is represented. Then insert rows with
known plaintexts. Mint a deliberately revoked one too — "does a revoked
credential still work" is a one-line test that occasionally pays out.

Name the rows you create with an obvious prefix (`qa-…`) so cleanup in step 7
is a single predictable delete.

For browser/session work you'll need to go through the real login form. Expect
a **CSRF token** on it: fetch the login page, scrape the hidden token, post it
back with a cookie jar. If login returns 403 with no explanation, that's
almost always what's missing rather than bad credentials.

Where the repo exposes a machine interface (an API, an MCP server), drive it
over the wire with its real transport instead of calling functions in-process.
In-process calls skip the auth middleware, the serialization layer, and the
rate limiter — which is to say they skip most of what you're trying to test.

## Sanity check before probing

Confirm each identity works and resolves to the tier you think it does — one
cheap authenticated read per credential. Discovering halfway through the
authorization matrix that your "viewer" was actually an admin invalidates
everything you've done since.

Record the baseline you'll restore later: row counts for tables you expect to
write, and the current value of any config you plan to change.
