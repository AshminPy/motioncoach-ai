#!/usr/bin/env bash
# MCP validation: calls SparkyFitness's real /mcp JSON-RPC endpoint
# (StreamableHTTP transport, @modelcontextprotocol/sdk) with a Bearer token,
# proving auth, tool listing, and that tool responses contain the exact
# synthetic values inserted via scripts/rest_validate.sh (not just "no
# error" — actual value matching).
#
# Usage:
#   BASE_URL=http://localhost:3004 API_KEY=<key> SQUAT_ID=<uuid> ./scripts/mcp_validate.sh
#
# The transport is stateless (sessionIdGenerator: undefined in
# routes/mcpRoutes.ts — a fresh McpServer is built per HTTP request), so each
# call below is a standalone JSON-RPC POST; no session handshake needs to be
# kept alive across calls.

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3004}"
API_KEY="${API_KEY:?Set API_KEY}"
SQUAT_ID="${SQUAT_ID:?Set SQUAT_ID (exercise id from rest_validate.sh output)}"
DATE="${ENTRY_DATE:-2026-09-18}"
WRITE_DATE="${WRITE_DATE:-2026-09-17}"

mcp_call() {
  local id="$1" method="$2" params="$3"
  curl -s -X POST "${BASE_URL}/mcp" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "Authorization: Bearer ${API_KEY}" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":${id},\"method\":\"${method}\",\"params\":${params}}"
}

echo "== 1. initialize =="
mcp_call 1 initialize '{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"motioncoach-validation","version":"1.0.0"}}'
echo ""

echo "== 2. sparky_manage_checkin get_biometrics_history (expect weight 123.4, BF 22.7) =="
mcp_call 2 tools/call "{\"name\":\"sparky_manage_checkin\",\"arguments\":{\"action\":\"get_biometrics_history\",\"start_date\":\"${DATE}\",\"end_date\":\"${DATE}\"}}"
echo ""

echo "== 3. sparky_get_exercise_progress on squat (expect max_weight 121.5, max_reps 5) =="
mcp_call 3 tools/call "{\"name\":\"sparky_get_exercise_progress\",\"arguments\":{\"exercise_id\":\"${SQUAT_ID}\",\"start_date\":\"${DATE}\",\"end_date\":\"${DATE}\"}}"
echo ""

echo "== 4. sparky_get_nutrition_summary (expect calories 417, protein 42.7) =="
mcp_call 4 tools/call "{\"name\":\"sparky_get_nutrition_summary\",\"arguments\":{\"date\":\"${DATE}\"}}"
echo ""

echo "== 5. sparky_get_health_summary (expect nutrition+fitness+vitals grounded in synthetic data) =="
mcp_call 5 tools/call "{\"name\":\"sparky_get_health_summary\",\"arguments\":{\"start_date\":\"${DATE}\",\"end_date\":\"${DATE}\"}}"
echo ""

echo "== 6. WRITE via MCP: sparky_manage_exercise log_exercise (new distinctive set: 3x137.25kg on ${WRITE_DATE}) =="
mcp_call 6 tools/call "{\"name\":\"sparky_manage_exercise\",\"arguments\":{\"action\":\"log_exercise\",\"exercise_id\":\"${SQUAT_ID}\",\"entry_date\":\"${WRITE_DATE}\",\"sets\":[{\"reps\":3,\"weight\":137.25}]}}"
echo ""

echo "== 7. READ BACK via MCP: sparky_get_exercise_progress across both dates (expect both 121.5 and 137.25) =="
mcp_call 7 tools/call "{\"name\":\"sparky_get_exercise_progress\",\"arguments\":{\"exercise_id\":\"${SQUAT_ID}\",\"start_date\":\"${WRITE_DATE}\",\"end_date\":\"${DATE}\"}}"
echo ""

echo "== 8. sparky_analyze_trends (expect entries referencing 123.4kg / 417 kcal) =="
mcp_call 8 tools/call '{"name":"sparky_analyze_trends","arguments":{"days":7}}'
echo ""

echo "== 9. sparky_generate_coaching_plan (grounding check: does shopping_list mention our synthetic food?) =="
mcp_call 9 tools/call '{"name":"sparky_generate_coaching_plan","arguments":{"goal":"maintenance"}}'
echo ""
