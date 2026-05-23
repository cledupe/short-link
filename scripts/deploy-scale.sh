#!/bin/bash
# ───────────────────────────────────────────────────────────────────
# deploy-scale.sh — Deploy and scale backend to 3 instances
# Usage: ./scripts/deploy-scale.sh
# ───────────────────────────────────────────────────────────────────

set -euo pipefail

INSTANCE_COUNT=3
COMPOSE_FILE="docker-compose.yml"
BACKEND_SERVICE="backend"
HEALTH_URL="http://localhost:8080/api/health"
TIMEOUT_SEC=90
SLEEP_INTERVAL=3

echo "═══════════════════════════════════════════════════════"
echo "  Distributed URL Shortener — Deploy & Scale"
echo "═══════════════════════════════════════════════════════"

# ── Step 1: Stop existing containers ──
echo ""
echo "[1/5] Stopping existing containers..."
docker-compose -f "$COMPOSE_FILE" down --remove-orphans
echo "  Done."

# ── Step 2: Rebuild images ──
echo ""
echo "[2/5] Rebuilding images..."
docker-compose -f "$COMPOSE_FILE" build
echo "  Done."

# ── Step 3: Start with scaled backend instances ──
echo ""
echo "[3/5] Starting stack with $INSTANCE_COUNT backend instances..."
docker-compose -f "$COMPOSE_FILE" up -d --scale "$BACKEND_SERVICE=$INSTANCE_COUNT"
echo "  Done."

# ── Step 4: Wait for all instances to be healthy ──
echo ""
echo "[4/5] Waiting for all $INSTANCE_COUNT backend instances to become healthy..."
echo "  (timeout: ${TIMEOUT_SEC}s, polling every ${SLEEP_INTERVAL}s)"
echo ""

ELAPSED=0
INSTANCES_READY=0

while [ $ELAPSED -lt $TIMEOUT_SEC ]; do
  INSTANCES_READY=0
  for i in $(seq 1 $INSTANCE_COUNT); do
    RESPONSE=$(docker-compose -f "$COMPOSE_FILE" ps --format json "$BACKEND_SERVICE" 2>/dev/null | \
      jq -r 'select(.Health == "healthy") | .Name' 2>/dev/null | wc -l)
    INSTANCES_READY=$RESPONSE
  done

  # Fallback: count by inspecting directly
  INSTANCES_READY=$(docker ps --filter "name=backend" --format '{{.ID}} {{.Status}}' | \
    grep -c "(healthy)" || true)

  printf "    [%3ds] Healthy instances: %d/%d\r" "$ELAPSED" "$INSTANCES_READY" "$INSTANCE_COUNT"

  if [ "$INSTANCES_READY" -ge "$INSTANCE_COUNT" ]; then
    printf "\n  All $INSTANCE_COUNT instances healthy after ${ELAPSED}s.\n"
    break
  fi

  sleep $SLEEP_INTERVAL
  ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done

if [ "$INSTANCES_READY" -lt "$INSTANCE_COUNT" ]; then
  echo ""
  echo "  WARNING: Only $INSTANCES_READY/$INSTANCE_COUNT instances healthy within timeout."
  echo "  Check logs: docker-compose logs $BACKEND_SERVICE"
fi

# ── Step 5: Test load balancer distribution ──
echo ""
echo "[5/5] Testing load balancer distribution..."
echo "  Running 12 requests to verify request distribution across instances..."

FAIL_COUNT=0
for i in $(seq 1 12); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" 2>/dev/null || true)
  if [ "$HTTP_CODE" != "200" ]; then
    echo "    Request $i: HTTP $HTTP_CODE (FAIL)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    echo "    Request $i: HTTP $HTTP_CODE (ok)"
  fi
done

echo ""
echo "═══════════════════════════════════════════════════════"
if [ "$FAIL_COUNT" -eq 0 ] && [ "$INSTANCES_READY" -ge "$INSTANCE_COUNT" ]; then
  echo "  Result: DEPLOYMENT SUCCESSFUL"
  echo "  $INSTANCE_COUNT backend instances running behind nginx LB"
  echo "  Endpoint: http://localhost:8080"
  echo ""
  echo "  Quick commands:"
  echo "    Check logs:     docker-compose logs -f $BACKEND_SERVICE"
  echo "    Check health:   curl http://localhost:8080/health"
  echo "    Scale down:     docker-compose up -d --scale $BACKEND_SERVICE=1"
  exit 0
else
  echo "  Result: DEPLOYMENT ISSUES DETECTED"
  [ "$FAIL_COUNT" -gt 0 ] && echo "  Failed requests: $FAIL_COUNT/12"
  [ "$INSTANCES_READY" -lt "$INSTANCE_COUNT" ] && echo "  Unhealthy instances: $((INSTANCE_COUNT - INSTANCES_READY))"
  echo ""
  echo "  Troubleshooting:"
  echo "    docker-compose logs $BACKEND_SERVICE"
  echo "    docker-compose ps"
  echo "    docker ps --filter 'name=backend'"
  exit 1
fi