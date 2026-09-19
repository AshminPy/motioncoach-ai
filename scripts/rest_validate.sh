#!/usr/bin/env bash
# REST validation: inserts synthetic body-weight/body-fat, a 2-exercise
# workout (3 sets each, distinctive reps/weights), and one nutrition entry,
# then reads every one of them back and prints the response so the caller
# (or a diff) can confirm an exact match.
#
# Usage:
#   BASE_URL=http://localhost:3004 API_KEY=<key> ./scripts/rest_validate.sh
#
# Two known upstream quirks are worked around here (documented in
# docs/evidence/03_rest_validation.md as UPSTREAM ISSUEs, not patched in the
# reference clone):
#   1. POST /api/exercises requires an explicit "source" field even though
#      the endpoint's own Swagger doc does not list it as accepted input —
#      the exercises.source DB column is NOT NULL and the manual-create path
#      never defaults it. Workaround: send "source":"manual" explicitly.
#   2. POST /api/exercise-entries requires each set to carry an explicit
#      1-based "set_number" — the REST route does not auto-number sets the
#      way the MCP sparky_manage_exercise tool does internally.

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3004}"
API_KEY="${API_KEY:?Set API_KEY (see scripts/create_test_user.sh)}"
DATE="${ENTRY_DATE:-2026-09-18}"
AUTH_HEADER="Authorization: Bearer ${API_KEY}"

jq_get() { python3 -c "import json,sys; d=json.load(sys.stdin); print(d$1)"; }

echo "== 1. Check-in: body weight 123.4kg, body fat 22.7% =="
curl -s -X POST "${BASE_URL}/api/measurements/check-in" \
  -H "Content-Type: application/json" -H "$AUTH_HEADER" \
  -d "{\"entry_date\":\"${DATE}\",\"weight\":123.4,\"body_fat_percentage\":22.7}"
echo ""

echo "== 2. Read back check-in =="
curl -s "${BASE_URL}/api/measurements/check-in/${DATE}" -H "$AUTH_HEADER"
echo ""

echo "== 3. Create exercise: MotionCoach Test Squat =="
SQUAT=$(curl -s -X POST "${BASE_URL}/api/exercises/" -H "$AUTH_HEADER" \
  -F 'exerciseData={"name":"MotionCoach Test Squat","category":"Strength","modality":"weight_reps","description":"Synthetic Phase 1 validation exercise.","source":"manual"}')
SQUAT_ID=$(echo "$SQUAT" | jq_get "['id']")
echo "$SQUAT"

echo "== 4. Create exercise: MotionCoach Test Bench Press =="
BENCH=$(curl -s -X POST "${BASE_URL}/api/exercises/" -H "$AUTH_HEADER" \
  -F 'exerciseData={"name":"MotionCoach Test Bench Press","category":"Strength","modality":"weight_reps","description":"Synthetic Phase 1 validation exercise.","source":"manual"}')
BENCH_ID=$(echo "$BENCH" | jq_get "['id']")
echo "$BENCH"

echo "== 5. Log squat workout (3 sets: 5x111.5, 5x116.5, 5x121.5) =="
curl -s -X POST "${BASE_URL}/api/exercise-entries/" -H "Content-Type: application/json" -H "$AUTH_HEADER" \
  -d "{\"exercise_id\":\"${SQUAT_ID}\",\"entry_date\":\"${DATE}\",\"notes\":\"MotionCoach Phase1 synthetic entry\",\"sets\":[{\"set_number\":1,\"reps\":5,\"weight\":111.5},{\"set_number\":2,\"reps\":5,\"weight\":116.5},{\"set_number\":3,\"reps\":5,\"weight\":121.5}]}"
echo ""

echo "== 6. Log bench press workout (3 sets: 8x61.25, 8x63.75, 8x66.25) =="
curl -s -X POST "${BASE_URL}/api/exercise-entries/" -H "Content-Type: application/json" -H "$AUTH_HEADER" \
  -d "{\"exercise_id\":\"${BENCH_ID}\",\"entry_date\":\"${DATE}\",\"notes\":\"MotionCoach Phase1 synthetic entry\",\"sets\":[{\"set_number\":1,\"reps\":8,\"weight\":61.25},{\"set_number\":2,\"reps\":8,\"weight\":63.75},{\"set_number\":3,\"reps\":8,\"weight\":66.25}]}"
echo ""

echo "== 7. Read back workouts for ${DATE} =="
curl -s "${BASE_URL}/api/exercise-entries/by-date?selectedDate=${DATE}" -H "$AUTH_HEADER"
echo ""

echo "== 8. Create food: MotionCoach Test Protein Shake =="
FOOD=$(curl -s -X POST "${BASE_URL}/api/foods/" -H "Content-Type: application/json" -H "$AUTH_HEADER" \
  -d '{"name":"MotionCoach Test Protein Shake","serving_size":1,"serving_unit":"shake","calories":417,"protein":42.7,"carbs":13.1,"fat":9.3,"is_custom":true}')
FOOD_ID=$(echo "$FOOD" | jq_get "['id']")
VARIANT_ID=$(echo "$FOOD" | jq_get "['default_variant']['id']")
echo "$FOOD"

echo "== 9. Get meal types (need meal_type_id for food entry) =="
MEAL_TYPES=$(curl -s "${BASE_URL}/api/meal-types/" -H "$AUTH_HEADER")
BREAKFAST_ID=$(echo "$MEAL_TYPES" | python3 -c "import json,sys; d=json.load(sys.stdin); print([m['id'] for m in d if m['name']=='breakfast'][0])")

echo "== 10. Log nutrition entry (1x MotionCoach Test Protein Shake, breakfast) =="
curl -s -X POST "${BASE_URL}/api/food-entries/" -H "Content-Type: application/json" -H "$AUTH_HEADER" \
  -d "{\"food_id\":\"${FOOD_ID}\",\"variant_id\":\"${VARIANT_ID}\",\"meal_type_id\":\"${BREAKFAST_ID}\",\"entry_date\":\"${DATE}\",\"quantity\":1,\"unit\":\"shake\"}"
echo ""

echo "== 11. Read back nutrition entries for ${DATE} =="
curl -s "${BASE_URL}/api/food-entries/?selectedDate=${DATE}" -H "$AUTH_HEADER"
echo ""

echo "SQUAT_ID=${SQUAT_ID}"
echo "BENCH_ID=${BENCH_ID}"
echo "FOOD_ID=${FOOD_ID}"
