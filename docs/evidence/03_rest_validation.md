# Phase 1 Evidence: REST Write + Read Validation

Produced by `scripts/rest_validate.sh`, run against a fresh synthetic test
user (see `scripts/create_test_user.sh`). Full raw output of the actual run
used for this evidence is reproducible with:

```bash
BASE_URL=http://localhost:3004 ./scripts/create_test_user.sh
# copy the printed API_KEY, then:
BASE_URL=http://localhost:3004 API_KEY=<key> ./scripts/rest_validate.sh
```

## Body weight + body fat (synthetic, distinctive)

Written: `weight=123.4`, `body_fat_percentage=22.7`, `entry_date=2026-09-18`.

Read back (`GET /api/measurements/check-in/2026-09-18`):
```json
{"weight":123.4,"body_fat_percentage":22.7,"entry_date":"2026-09-18", ...}
```
Exact match.

## Workout: 2 exercises, 3 sets each, distinctive reps/weights

Created exercises `MotionCoach Test Squat` and `MotionCoach Test Bench
Press`, then logged:

| Exercise | Set 1 | Set 2 | Set 3 |
|---|---|---|---|
| MotionCoach Test Squat | 5 reps @ 111.5kg | 5 reps @ 116.5kg | 5 reps @ 121.5kg |
| MotionCoach Test Bench Press | 8 reps @ 61.25kg | 8 reps @ 63.75kg | 8 reps @ 66.25kg |

Read back (`GET /api/exercise-entries/by-date?selectedDate=2026-09-18`):
all 6 sets returned with identical `set_number`/`reps`/`weight` values —
exact match, verified programmatically (grepped the response for
`reps`/`weight`/`set_number` and diffed against the write payload).

## Nutrition entry (synthetic, distinctive)

Created food `MotionCoach Test Protein Shake`
(calories 417, protein 42.7g, carbs 13.1g, fat 9.3g), logged 1x serving
against the `breakfast` meal type on `2026-09-18`.

Read back (`GET /api/food-entries/?selectedDate=2026-09-18`): identical
`food_name`, `calories`, `protein`, `carbs`, `fat`, `quantity` — exact match.

## UPSTREAM ISSUEs found and worked around

These were found while running the real, documented REST contract as any
other client would — not invented, not patched in the reference clone.

### 1. `POST /api/exercises` requires an undocumented `source` field

**Observed:** first attempt (payload matching the endpoint's own Swagger doc
— `name`, `category`, `modality`, `description`) failed:
```
{"error":"null value in column \"source\" of relation \"exercises\" violates not-null constraint"}
```
**Root cause:** `models/exercise.ts` `createExercise()` inserts
`exerciseData.source` verbatim with no default and no `COALESCE`; the
`exercises.source` column is `NOT NULL`
(`shared/src/schemas/database/Exercises.zod.ts`: `source: z.string()` on the
initializer). The route's own Swagger doc for `POST /exercises`
(`routes/exerciseRoutes.ts`) does not list `source` as an accepted field, so
a client following the documented contract hits this every time.
**Local workaround (validation only, reference clone untouched):** send
`"source":"manual"` explicitly in the `exerciseData` JSON — an undocumented
but accepted value, since the column has no `CHECK` constraint restricting
its contents.

### 2. `POST /api/exercise-entries` requires an undocumented `set_number` per set

**Observed:** logging a workout with sets shaped exactly like the Swagger
doc (`{reps, weight, duration}`) failed:
```
{"error":"null value in column \"set_number\" of relation \"exercise_entry_sets\" violates not-null constraint"}
```
**Root cause:** the REST route passes the client's `sets` array straight
through to `models/exerciseEntry.ts`'s insert, which requires
`set.set_number` per row (`NOT NULL` column). The MCP tool path
(`ai/tools/exerciseTools.ts`, comment at line ~105: "1-based set_number plus
...") auto-derives `set_number: i + 1` from array order before calling the
same underlying service — the REST route does not do this normalization,
so REST and MCP have different effective contracts for the same field.
**Local workaround:** the validation script sends an explicit 1-based
`set_number` on every set object.

Both are genuine gaps between the documented Swagger contract and the actual
required DB schema on the manual-creation paths — reported here as findings,
not filed upstream (out of scope for this personal Phase 1 validation).
