#!/bin/bash
# ───────────────────────────────────────────────────────────────────
# verify-health.sh — Tests health endpoints through load balancer
# Usage: ./scripts/verify-health.sh
# ───────────────────────────────────────────────────────────────────

set -euo pipefail

ALL_PASS=true

echo "═══════════════════════════════════════════════"
echo "  Health Check Verification"
echo "═══════════════════════════════════════════════"

# Direct health check (LB returns 200 without proxying)
echo ""
echo "── /health (direct nginx) ──"
if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
  echo "  PASS: /health — nginx is responding"
else
  echo "  FAIL: /health"
  ALL_PASS=false
fi

# Proxied health check (nginx → backend)
echo ""
echo "── /api/health (proxied to backend) ──"
if curl -sf http://localhost:8080/api/health > /dev/null 2>&1; then
  echo "  PASS: /api/health — backend is reachable via LB"
else
  echo "  FAIL: /api/health"
  ALL_PASS=false
fi

# Summary
echo ""
echo "═══════════════════════════════════════════════"
if [ "$ALL_PASS" = true ]; then
  echo "  Result: ALL HEALTH CHECKS PASSED"
  exit 0
else
  echo "  Result: SOME HEALTH CHECKS FAILED"
  exit 1
fi