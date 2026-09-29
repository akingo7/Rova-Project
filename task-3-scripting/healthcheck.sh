#!/bin/bash
set -eo pipefail

CONFIG="${1:-endpoints.yaml}"
[ -f "$CONFIG" ] || CONFIG="$(dirname "$0")/endpoints.yaml"

if [ ! -f "$CONFIG" ]; then
  echo "Error: config file '$CONFIG' not found."
  exit 1
fi

# Read global defaults
MAX_RETRIES=$(yq '.settings.max_retries // 3' "$CONFIG")
BACKOFF=$(yq '.settings.backoff_seconds // 2' "$CONFIG")
TIMEOUT=$(yq '.settings.timeout_seconds // 5' "$CONFIG")
TOTAL=$(yq '.endpoints | length' "$CONFIG")

echo "Checking $TOTAL endpoints from $CONFIG..."
echo ""

FAILED=0
RESULTS=()

for ((i = 0; i < TOTAL; i++)); do
  NAME=$(yq ".endpoints[$i].name" "$CONFIG")
  URL=$(yq ".endpoints[$i].url" "$CONFIG")
  EXPECTED=$(yq ".endpoints[$i].expected_status // 200" "$CONFIG")
  RETRIES=$(yq ".endpoints[$i].max_retries // $MAX_RETRIES" "$CONFIG")
  TO=$(yq ".endpoints[$i].timeout_seconds // $TIMEOUT" "$CONFIG")

  SUCCESS=0
  STATUS="000"
  LATENCY="0"

  for ((attempt = 1; attempt <= RETRIES; attempt++)); do
    OUTPUT=$(curl -s -L -o /dev/null -w "%{http_code} %{time_total}" --max-time "$TO" "$URL" 2>/dev/null || echo "000 0")
    read -r STATUS TIME <<< "$OUTPUT"
    LATENCY=$(awk -v t="$TIME" 'BEGIN { printf "%.0f", t * 1000 }')

    if [ "$STATUS" -eq "$EXPECTED" ] 2>/dev/null; then
      echo "  [PASS] $NAME -> HTTP $STATUS (${LATENCY}ms)"
      SUCCESS=1
      break
    else
      echo "  [RETRY $attempt/$RETRIES] $NAME -> HTTP $STATUS (expected $EXPECTED, ${LATENCY}ms)"
      [ "$attempt" -lt "$RETRIES" ] && sleep "$BACKOFF"
    fi
  done

  if [ "$SUCCESS" -eq 1 ]; then
    STATE="healthy"
  else
    echo "  [FAIL] $NAME is down after $RETRIES attempts."
    STATE="unhealthy"
    ((FAILED++)) || true
  fi

  RESULTS+=("{\"name\":\"$NAME\",\"url\":\"$URL\",\"status\":\"$STATUS\",\"latency_ms\":$LATENCY,\"result\":\"$STATE\"}")
  echo ""
done

echo "----------------------------------------"
echo "Summary: $((TOTAL - FAILED))/$TOTAL passed ($FAILED failed)"
echo "----------------------------------------"

JSON_DATA=$(printf "%s\n" "${RESULTS[@]}" | jq -s .)
jq -n \
  --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson total "$TOTAL" \
  --argjson failed "$FAILED" \
  --argjson results "$JSON_DATA" \
  '{timestamp: $time, total: $total, failed: $failed, results: $results}'

[ "$FAILED" -eq 0 ] || exit 1
