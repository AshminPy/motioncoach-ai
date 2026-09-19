# Phase 1 Evidence: MCP Validation

Produced by `scripts/mcp_validate.sh` against the real `/mcp` endpoint
(JSON-RPC 2.0 over HTTP POST, StreamableHTTP transport per
`@modelcontextprotocol/sdk`, mounted at bare `/mcp` — not `/api/mcp` — in
`SparkyFitnessServer.ts`, and reachable through the frontend nginx proxy at
`http://localhost:3004/mcp`). Auth is the same Bearer token used for REST.

## 1. Initialize handshake

```
POST /mcp  {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"motioncoach-validation","version":"1.0.0"}}}

200 OK
{"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{"listChanged":true}},"serverInfo":{"name":"sparkyfitness-mcp-server","version":"1.7.1"}}}
```
Confirms the real MCP server identity and protocol version. The transport is
stateless (`sessionIdGenerator: undefined` in `routes/mcpRoutes.ts` — a fresh
`McpServer` is built per HTTP request), so no session ID needs to be carried
between calls.

## 2. Read synthetic biometrics via MCP (`sparky_manage_checkin`)

Arguments: `{"action":"get_biometrics_history","start_date":"2026-09-18","end_date":"2026-09-18"}`

Result text: `"**2026-09-18**: Weight: 123.4kg | BF: 22.7%"`

Matches the REST-written values exactly (123.4kg, 22.7%) — proves REST-write
→ MCP-read equivalence, not just "no error returned."

## 3. Read synthetic exercise progress via MCP (`sparky_get_exercise_progress`)

Arguments: `{"exercise_id":"<squat-id>","start_date":"2026-09-18","end_date":"2026-09-18"}`

Result: `{"data":[{"entry_date":"2026-09-18","max_weight":121.5,"max_reps":5,"total_volume":1747.5}], ...}`

`121.5` and `5` match the heaviest REST-written squat set exactly.
`total_volume: 1747.5` = sum(reps×weight) across all 3 sets
(5×111.5 + 5×116.5 + 5×121.5 = 557.5+582.5+607.5 = 1747.5) — independently
verifiable arithmetic, confirming the tool aggregates the real inserted sets
rather than returning a stub.

## 4. Read synthetic nutrition via MCP (`sparky_get_nutrition_summary`)

Result: `{"entry_date":"2026-09-18","calories":417,"protein":42.7,"carbs":13.1,"fat":9.3, ...}`

Exact match to the REST-written food entry.

## 5. Read synthetic health summary via MCP (`sparky_get_health_summary`)

Result includes `total_calories:417`, `avg_protein:42.7`, `workout_count:2`,
`latest_weight: {weight:123.4, date:"2026-09-18"}` — all fields trace back to
the exact synthetic REST writes. `workout_count:2` correctly counts both the
squat and bench press entries.

## 6-7. Write → MCP → read round trip (write via MCP itself, not REST)

Write: `sparky_manage_exercise` action `log_exercise`, arguments
`{"exercise_id":"<squat-id>","entry_date":"2026-09-17","sets":[{"reps":3,"weight":137.25}]}`

Result: `"✅ Exercise logged for 2026-09-17."`

Read back via MCP (`sparky_get_exercise_progress`, date range spanning both
days):
```json
{"data":[
  {"entry_date":"2026-09-17","max_weight":137.25,"max_reps":3,"total_volume":411.75},
  {"entry_date":"2026-09-18","max_weight":121.5,"max_reps":5,"total_volume":1747.5}
]}
```
`137.25` / `3` match exactly what was written via MCP one call earlier — a
full MCP-write → DB → MCP-read round trip, independent of the earlier
REST-only entries also being visible.

Cross-checked via REST too (`GET /api/exercise-entries/by-date?selectedDate=2026-09-17`):
returned `reps:3, weight:137.25` — confirms the MCP-side write landed in the
same Postgres row REST reads from, not a separate/cached path.

## 8. Trend analysis grounding (`sparky_analyze_trends`, 7-day window)

Result explicitly lists `{"date":"2026-09-18","weight":123.4}` and
`{"date":"2026-09-18","calories":417}` inside its `entries` arrays — the
distinctive synthetic numbers are directly present in the tool's reasoning
input, not paraphrased or invented.

## 9. Coaching plan grounding (`sparky_generate_coaching_plan`, goal=maintenance)

Result:
```json
{
  "goal": "maintenance",
  "current_estimated_tdee": 2200,
  "recommended_targets": {"daily_calories":2200,"protein_grams":165,"carbs_grams":220,"fat_grams":73},
  "shopping_list_suggestions": ["MotionCoach Test Protein Shake"],
  "coaching_insight": "You are on the right track for your maintenance goal."
}
```

**This is the strongest grounding evidence in Phase 1**: `shopping_list_suggestions`
names our exact synthetic food, `MotionCoach Test Protein Shake` — a name
that cannot exist in any training data or generic default list. The tool is
demonstrably reasoning over the real rows this session inserted, not
hallucinating plausible-sounding food names.

Note: the tool's `goal` argument required the exact enum value
`"maintenance"` (not `"maintain"`) — an MCP validation error (`-32602`) was
returned on the first attempt with the wrong value, which is correct,
expected schema enforcement, not a bug.
