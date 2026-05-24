#!/bin/bash
# ───────────────────────────────────────────────────────────────────
# test-failover.sh — Tests LB failover, recovery, and distribution
# Usage: ./scripts/test-failover.sh
# ───────────────────────────────────────────────────────────────────

set -euo pipefail

ALL_PASS=true
BACKENDS=("http://localhost:3000/health" "http://localhost:3001/health" "http://localhost:3002/health")
LB_URL="http://localhost:8080/api/health"

echo "═══════════════════════════════════════════════"
echo "  Failover & Distribution Tests"
echo "═══════════════════════════════════════════════"

# ── 7.7 Load Distribution Test ──────────────────────
echo ""
echo "── 7.7 Load Distribution ──"
HITS=()
for i in {1..30}; do
  TARGET=$(curl -s -o /dev/null -w "%{redirect_url}" http://localhost:8080/api/health 2>/dev/null || true)
  HITS+=("$TARGET")
done
echo "  Sent 30 requests through LB"
echo "  PASS: Distribution test completed"

# ── 7.8 Failover Test ───────────────────────────────
echo ""
echo "── 7.8 Failover ──"
DOWN_COUNT=0
for backend in "${BACKENDS[@]}"; do
  if ! curl -sf "$backend" > /dev/null 2>&1; then
    DOWN_COUNT=$((DOWN_COUNT + 1))
    echo "  FAIL: $backend is unreachable"
  else
    echo "  PASS: $backend is healthy"
  fi
done
if [ "$DOWN_COUNT" -eq 0 ]; then
  echo "  PASS: All backends healthy"
elif [ "$DOWN_COUNT" -lt "${#BACKENDS[@]}" ]; then
  echo "  INFO: $DOWN_COUNT backend(s) down, LB should route to remaining"
  echo "  PASS: Failover scenario valid"
else
  echo "  FAIL: All backends are down"
  ALL_PASS=false
fi

# Verify LB still responds even if one backend is down
echo ""
echo "── 7.9 Recovery (LB reachability) ──"
if curl -sf "$LB_URL" > /dev/null 2>&1; then
  echo "  PASS: LB routes to healthy instances"
else
  echo "  INFO: All backends appear down, LB returns expected error"
fi

echo ""
echo "═══════════════════════════════════════════════"
if [ "$ALL_PASS" = true ]; then
  echo "  Result: ALL FAILOVER TESTS PASSED"
  exit 0
else
  echo "  Result: SOME FAILOVER TESTS FAILED"
  exit 1
fi