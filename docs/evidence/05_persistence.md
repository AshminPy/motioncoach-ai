# Phase 1 Evidence: Persistence Across Restart

## Command

```bash
docker compose -p motioncoach -f infra/sparkyfitness/docker-compose.yml restart
```

(Restart, not down+up with volume removal — proves the bind-mounted
`infra/sparkyfitness/postgresql` volume genuinely persists data, not just
that the container process kept running.)

## Result

All 3 containers came back healthy within ~30 seconds:
```
sparkyfitness-frontend   Up 29 seconds (healthy)
sparkyfitness-server     Up 25 seconds (healthy)
sparkyfitness-db         Up 28 seconds (healthy)
```

`curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:3004/api/health`
→ `HTTP 200`

## Data confirmed still present after restart

```
GET /api/measurements/check-in/2026-09-18
{"weight":123.4,"body_fat_percentage":22.7, ...}     <- unchanged

GET /api/exercise-entries/by-date?selectedDate=2026-09-18
[... reps:5/weight:111.5, reps:5/weight:116.5, reps:5/weight:121.5,
     reps:8/weight:61.25, reps:8/weight:63.75, reps:8/weight:66.25 ...]   <- unchanged
```

The same API key (minted before the restart) also still worked afterward,
confirming Better Auth's API-key table survived in Postgres as expected.
