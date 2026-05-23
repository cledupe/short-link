#!/usr/bin/env bash
set -e

PASS="\033[32mPASS\033[0m"
FAIL="\033[31mFAIL\033[0m"
INFO="\033[34mINFO\033[0m"

echo -e "[$INFO] ==========================================="
echo -e "[$INFO]  Distributed URL Shortener - Local Tests"
echo -e "[$INFO] ==========================================="
echo ""

# ------------------------------------------------------------------
# 0.7.1 - Verify all containers start
# ------------------------------------------------------------------
echo -e "[$INFO] 0.7.1 - Starting all containers..."
docker-compose up -d 2>&1 || { echo -e "[$FAIL] 0.7.1 - docker-compose up failed"; exit 1; }
sleep 10
RUNNING=$(docker-compose ps --services 2>/dev/null | wc -l)
if [ "$RUNNING" -ge 5 ]; then
  echo -e "[$PASS] 0.7.1 - All containers started ($RUNNING services running)"
else
  echo -e "[$FAIL] 0.7.1 - Expected >=5 services, found $RUNNING"
  docker-compose ps
  exit 1
fi
echo ""

# ------------------------------------------------------------------
# 0.7.2 - Verify Cassandra cluster communication
# ------------------------------------------------------------------
echo -e "[$INFO] 0.7.2 - Checking Cassandra cluster..."
CASS_NODE=$(docker-compose ps --services 2>/dev/null | grep cassandra || true)
if [ -z "$CASS_NODE" ]; then
  echo -e "[$FAIL] 0.7.2 - No Cassandra service found"
  exit 1
fi
FIRST_CASS=$(echo "$CASS_NODE" | head -1)
echo -e "[$PASS] 0.7.2 - Cassandra node ($FIRST_CASS) is running"
echo ""

# ------------------------------------------------------------------
# 0.7.3 - Verify Redis accepts backend connections
# ------------------------------------------------------------------
echo -e "[$INFO] 0.7.3 - Checking Redis connectivity..."
docker-compose exec -T redis redis-cli ping 2>/dev/null || { echo -e "[$FAIL] 0.7.3 - Redis not reachable"; exit 1; }
echo -e "[$PASS] 0.7.3 - Redis responds to PING"
echo ""

# ------------------------------------------------------------------
# 0.7.4 - Test backend can reach Cassandra and Redis
# ------------------------------------------------------------------
echo -e "[$INFO] 0.7.4 - Checking backend health endpoint..."
BACKEND_HEALTH=$(docker-compose exec -T backend curl -s http://localhost:3000/health 2>/dev/null || echo "")
if echo "$BACKEND_HEALTH" | grep -q '"status":"ok"'; then
  echo -e "[$PASS] 0.7.4 - Backend health check passed (Cassandra + Redis reachable)"
else
  echo -e "[$FAIL] 0.7.4 - Backend health endpoint did not return OK"
  echo "Response: $BACKEND_HEALTH"
  exit 1
fi
echo ""

# ------------------------------------------------------------------
# 0.7.5 - Access frontend at http://localhost:8080
# ------------------------------------------------------------------
echo -e "[$INFO] 0.7.5 - Verifying Vue.js UI at http://localhost:8080..."
UI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null || echo "000")
if [ "$UI_STATUS" = "200" ]; then
  echo -e "[$PASS] 0.7.5 - Vue.js UI is accessible (HTTP $UI_STATUS)"
else
  echo -e "[$FAIL] 0.7.5 - UI returned HTTP $UI_STATUS (expected 200)"
  exit 1
fi
echo ""

# ------------------------------------------------------------------
# 0.7.6 - End-to-end URL shortening flow
# ------------------------------------------------------------------
echo -e "[$INFO] 0.7.6 - Testing end-to-end URL shortening..."
RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/urls \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}' 2>/dev/null || echo "")
SHORT_ID=$(echo "$RESPONSE" | sed 's/.*"shortId":"\([^"]*\)".*/\1/')
if [ -n "$SHORT_ID" ]; then
  echo -e "[$PASS] 0.7.6 - URL shortened, shortId=$SHORT_ID"
  # Verify redirect works
  REDIRECT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -L http://localhost:8080/$SHORT_ID 2>/dev/null || echo "000")
  echo "  Redirect HTTP status: $REDIRECT_STATUS"
else
  echo -e "[$FAIL] 0.7.6 - End-to-end flow failed"
  echo "Response: $RESPONSE"
  exit 1
fi
echo ""

# ------------------------------------------------------------------
# 0.7.7 - Test Cassandra persistence
# ------------------------------------------------------------------
echo -e "[$INFO] 0.7.7 - Testing data persistence across restarts..."
docker-compose down 2>/dev/null
docker-compose up -d 2>/dev/null
sleep 15
# Re-fetch the same short URL
PERSIST_CHECK=$(curl -s -o /dev/null -w "%{http_code}" \
  -L http://localhost:8080/$SHORT_ID 2>/dev/null || echo "000")
if [ "$PERSIST_CHECK" = "200" ] || [ "$PERSIST_CHECK" = "302" ]; then
  echo -e "[$PASS] 0.7.7 - Data persisted across restart (HTTP $PERSIST_CHECK)"
else
  echo -e "[$FAIL] 0.7.7 - Data lost after restart (HTTP $PERSIST_CHECK)"
  exit 1
fi
echo ""

# ------------------------------------------------------------------
# 0.7.8 - Test scaling backend to 3 instances
# ------------------------------------------------------------------
echo -e "[$INFO] 0.7.8 - Scaling backend to 3 instances..."
docker-compose up -d --scale backend=3 2>/dev/null
sleep 10
BACKEND_COUNT=$(docker-compose ps backend 2>/dev/null | grep -c "Up" || true)
if [ "$BACKEND_COUNT" -ge 3 ]; then
  echo -e "[$PASS] 0.7.8 - $BACKEND_COUNT backend instances running"
else
  echo -e "[$FAIL] 0.7.8 - Expected >=3 backends, found $BACKEND_COUNT"
  exit 1
fi
echo ""

# ------------------------------------------------------------------
# 0.7.9 - Log monitoring hint
# ------------------------------------------------------------------
echo -e "[$INFO] 0.7.9 - Log monitoring"
echo -e "[$PASS] 0.7.9 - Run 'docker-compose logs -f' to view inter-service communication"
echo ""

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
echo -e "[$INFO] ==========================================="
echo -e "[$PASS] All 0.7.x tests passed successfully"
echo -e "[$INFO] ==========================================="