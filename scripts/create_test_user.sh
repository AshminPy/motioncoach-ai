#!/usr/bin/env bash
# Creates a synthetic MotionCoach test user via Better Auth's email/password
# signup endpoint, then mints a scoped API key for that user.
#
# This is the least-privileged credential actually exposed by SparkyFitness's
# API for this purpose: the identity routes
# (routes/auth/apiKeyRoutes.ts, POST /api/identity/user/generate-api-key)
# only accept `name` and `expiresIn` — there is no permissions/scopes field on
# this endpoint, so the minted key inherits whatever role the account has.
# On a fresh single-user instance the first signed-up user is auto-promoted
# to admin (observed, not assumed — see docs/evidence/02_auth.md), so this key
# is effectively full-access. There was no narrower option available via the
# real API to choose from.
#
# Usage:
#   BASE_URL=http://localhost:3004 ./scripts/create_test_user.sh
#
# Prints two lines to stdout: SESSION_TOKEN=... and API_KEY=...
# Does not print the password (fixed, synthetic, not a real credential).

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3004}"
SUFFIX="${1:-$(date +%s)}"
EMAIL="motioncoach.test+${SUFFIX}@example.invalid"
PASSWORD="${TEST_USER_PASSWORD:-$(openssl rand -base64 18)}"
NAME="MotionCoach Test User"

echo "Creating synthetic test user: ${EMAIL}" >&2

SIGNUP_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/auth/sign-up/email" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\",\"name\":\"${NAME}\"}")

SESSION_TOKEN=$(echo "$SIGNUP_RESPONSE" | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')
USER_ID=$(echo "$SIGNUP_RESPONSE" | python3 -c 'import json,sys; print(json.load(sys.stdin)["user"]["id"])')

if [ -z "$SESSION_TOKEN" ]; then
  echo "ERROR: signup did not return a session token. Raw response:" >&2
  echo "$SIGNUP_RESPONSE" >&2
  exit 1
fi

echo "Signed up user_id=${USER_ID}" >&2

APIKEY_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/identity/user/generate-api-key" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${SESSION_TOKEN}" \
  -d '{"name":"motioncoach-phase1-validation","expiresIn":2592000}')

API_KEY=$(echo "$APIKEY_RESPONSE" | python3 -c 'import json,sys; print(json.load(sys.stdin)["apiKey"]["key"])')

if [ -z "$API_KEY" ]; then
  echo "ERROR: API key generation failed. Raw response:" >&2
  echo "$APIKEY_RESPONSE" >&2
  exit 1
fi

echo "EMAIL=${EMAIL}"
echo "USER_ID=${USER_ID}"
echo "SESSION_TOKEN=${SESSION_TOKEN}"
echo "API_KEY=${API_KEY}"
