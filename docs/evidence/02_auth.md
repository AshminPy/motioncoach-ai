# Phase 1 Evidence: Authentication

All findings below are FACT — observed directly from real HTTP responses
against the deployed stack, or from reading the actual route code in
`../reference/SparkyFitness/SparkyFitnessServer/`. No values here are guessed.

## Auth type

Better Auth (email/password) for interactive sign-up/sign-in, plus Better
Auth's `api-key` plugin for machine/API tokens. Both are accepted the same
way by REST and MCP: `Authorization: Bearer <token>`.
`SparkyFitnessServer/utils/bearerAuthBridge.ts` inspects the token: 64+
characters with no `.` is treated as an API key (mapped to an `x-api-key`
header internally); anything else is treated as a session token and signed
into a `sparky.session_token` cookie server-side before being handed to
Better Auth's session resolver.

## Creation method (exact endpoints used)

1. `POST /api/auth/sign-up/email` — Better Auth's built-in email/password
   sign-up route (confirmed live at this exact path; not guessed). Body:
   `{"email","password","name"}`. Response body includes both a `user`
   object and a `token` field — the token is a live session token usable
   immediately as a Bearer token, no separate sign-in call needed.
2. `POST /api/identity/user/generate-api-key` — a custom SparkyFitness route
   (`routes/auth/apiKeyRoutes.ts`), authenticated with the session token from
   step 1. Body: `{"name","expiresIn"}` (seconds; defaults to 31536000 / 1
   year if omitted). Response: `{"apiKey":{"id","key","name","createdAt"}}`
   — `key` is shown only once, at creation.

## User identity

Fresh instance, first sign-up. The sign-up response body showed
`"role":"admin"` on the created user, without `SPARKY_FITNESS_ADMIN_EMAIL`
being set in `.env`. This is FACT (seen in the raw response); the exact
mechanism that assigned `admin` was not traced further (INFERENCE: likely a
single-user-instance default via Better Auth's `admin` plugin or a startup
hook) — flagged here rather than asserted as a specific mechanism.

## Permissions / scoping

`POST /api/identity/user/generate-api-key` (`routes/auth/apiKeyRoutes.ts`,
line ~35-64) accepts only `name` and `expiresIn` in its request body — there
is no `permissions` or `scopes` field exposed by this route, even though
Better Auth's underlying `api-key` plugin schema supports one. This means
the minted key inherits whatever role/permissions the authenticated account
already has; there was no narrower, actually-available option in the real
API to request a lower-privilege key. On this single-user instance the
account is `admin`, so the key is effectively full-access. This was
confirmed by reading the route handler directly, not assumed.

## Expiration

Set explicitly at creation via `expiresIn` (seconds). Our validation scripts
pass `2592000` (30 days) for the throwaway test key.

## Revocation

`DELETE /api/identity/user/api-key/:apiKeyId` (same file, line ~98-129) —
confirmed to exist in the route table; not exercised in this validation
(the test key was left to expire naturally / was a throwaway account), but
the mechanism is real and documented here for completeness.

## Sanitized example (values redacted — this was a synthetic throwaway account)

```
POST /api/auth/sign-up/email
{"email":"motioncoach.test+<suffix>@example.invalid","password":"<redacted>","name":"MotionCoach Test User"}

200 OK
{"token":"<session-token-redacted>","user":{"role":"admin","id":"<uuid>", ...}}

POST /api/identity/user/generate-api-key
Authorization: Bearer <session-token-redacted>
{"name":"motioncoach-phase1-validation","expiresIn":2592000}

201 Created
{"apiKey":{"id":"<uuid>","key":"<api-key-redacted, 64 chars>","name":"motioncoach-phase1-validation"}}
```
