# Phase 1 Evidence: Deployment

## Command

```bash
docker compose -p motioncoach -f infra/sparkyfitness/docker-compose.yml up -d
```

Result: exit 0. Images pulled: `postgres:18.3-alpine`,
`codewithcj/sparkyfitness_server:latest`, `codewithcj/sparkyfitness:latest`.

## Container status (after ~30s)

```
NAME                                   STATUS
motioncoach-sparkyfitness-frontend-1   Up 32 seconds (healthy)   0.0.0.0:3004->80/tcp
motioncoach-sparkyfitness-server-1     Up 32 seconds (healthy)   3010/tcp (internal only)
sparkyfitness-db                       Up 38 seconds (healthy)   5432/tcp (internal only)
```

## Server boot log (key lines)

```
[INFO] Applying migration: 20260912193000_better_auth_1_7_schema.sql
[INFO] Successfully applied migration: 20260912193000_better_auth_1_7_schema.sql
[INFO] Ensuring permissions for role: "sparkyapp"
[INFO] Applying all RLS policies from rls_policies.sql...
[INFO] Successfully applied all RLS policies.
[AUTH] Better Auth handler successfully mounted.
[INFO] SparkyFitnessServer listening on port 3010
```

All DB migrations applied cleanly and RLS policies were re-applied on this
fresh database — no errors.

## Real HTTP evidence (container "Up" status alone is not proof — this is)

```
$ curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:3004/
HTTP 200

$ curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:3004/api/health
HTTP 200

$ curl -s http://localhost:3004/api/health
{"status":"UP"}

$ curl -s http://localhost:3004/api/auth/settings
{"trusted_origin":"http://localhost:3004","email":{"enabled":true},"oidc":{"enabled":false,"providers":[],"auto_redirect":false},"signup_disabled":false,"demo_mode":false}
```

This proves: the frontend nginx container serves the SPA, it correctly
proxies `/api/*` to the internal server container (server port 3010 is not
published to the host — only reachable through the frontend proxy, as
designed), and Better Auth email/password signup is enabled and reachable.

## Ports

- Host port `3004` was confirmed free before deploy (`lsof -i :3004` returned
  nothing).
- Server (3010) and Postgres (5432) are intentionally NOT published to the
  host — only the frontend's 3004 is, matching the upstream compose design
  (frontend nginx proxies `/api` internally over the Docker network).
