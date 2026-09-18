# MotionCoach AI

A personal, private, non-commercial AI fitness coach.

This is a solo project, not a company project, and not intended for public
distribution. It is built for one person's own use.

## What this is

MotionCoach AI does not reimplement a fitness tracker from scratch. Instead it
uses the open-source, self-hosted app
[SparkyFitness](https://github.com/CodeWithCJ/SparkyFitness) as the data
platform (food/exercise/measurement logging, Postgres storage, Better Auth,
and a built-in Model Context Protocol server exposing ~50 `sparky_*` tools),
and builds custom capability on top of it:

- **Now (Phase 1):** deploy SparkyFitness locally, prove auth + REST + MCP
  work end to end, and prove SparkyFitness's existing coaching/reasoning
  tools can ground answers in real stored data.
- **Later (Phase 2+, not started):** a SwiftUI companion app, an AI
  orchestration layer on top of the MCP tools, Apple Health import, and
  camera/Vision-based rep-counting and form coaching.

## Repository layout

```
motioncoach-ai/
├── docs/
│   └── evidence/        # Phase 1 test evidence (sanitized, synthetic data only)
├── infra/
│   └── sparkyfitness/   # docker-compose.yml (fetched from upstream release) + .env
├── scripts/              # REST + MCP validation scripts
├── tests/                 # automated test files
└── README.md
```

## Relationship to the upstream project

A read-only reference clone of the upstream SparkyFitness repo lives at
`../reference/SparkyFitness` (sibling directory, outside this repo). This
repo never copies that source tree and never modifies it — it only talks to
SparkyFitness's REST API and MCP server over HTTP, exactly as any other
client would. SparkyFitness's license is non-commercial source-available;
that only matters if we redistributed its source, which we do not.

## Running SparkyFitness locally

```bash
cd infra/sparkyfitness
cp .env.example .env   # then fill in real generated secrets, never commit .env
docker compose -p motioncoach -f docker-compose.yml up -d
```

The stack runs under the `motioncoach` Compose project name and uses
project-local bind-mount paths (`infra/sparkyfitness/postgresql`,
`infra/sparkyfitness/uploads`, `infra/sparkyfitness/backup`) so it never
collides with any other Docker stack on this machine.

## Validation scripts

See `scripts/` for the REST and MCP validation scripts used to prove the
chain (deploy → auth → REST write/read → MCP write/read → coaching tools
grounded in real data) works. See `docs/evidence/` for the sanitized
request/response evidence captured during Phase 1.

## Status

**Phase 1: deploy + validate.** See `docs/evidence/PHASE1_REPORT.md` for the
full result. No SwiftUI app, AI orchestration server, or camera/Vision work
has started — that is Phase 2 and later.
