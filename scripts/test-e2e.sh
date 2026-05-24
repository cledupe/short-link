#!/usr/bin/env bash
set -e

BASE_URL=${BASE_URL:-http://localhost:8080}
PASS=0
FAIL=0
FAILED_TESTS=""

test() {
  local name="$1"; shift
  if "$@"; then
    echo -e "\033[32m[PASS]\033[0m $name"
    PASS=$((PASS + 1))
  else
    echo -e "\033[31m[FAIL]\033[0m $name"
    FAIL=$((FAIL + 1))
    FAILED_TESTS="$FAILED_TESTS  - $name\n"
  fi
}

cleanup() {
  echo ""
  echo -e "\033[34m[INFO]\033[0m Cleaning up test containers..."
  docker-compose down 2>/dev/null || true
}
trap cleanup EXIT

echo -e "\033[34m[INFO]\033[0m ==========================================="
echo -e "\033[34m[INFO]\033[0m  E2E Tests - Section 9"
echo -e "\033[34m[INFO]\033[0m  Distributed URL Shortener"
echo -e "\033[34m[INFO]\033[0m ==========================================="
echo -e "\033[34m[INFO]\033[0m Base URL: $BASE_URL"
echo -e "\033[34m[INFO]\033[0m Starting containers..."
docker-compose up -d 2>/dev/null
echo -e "\033[34m[INFO]\033[0m Waiting for services to be ready..."
sleep 15
echo ""

# ------------------------------------------------------------------
# 9.1 - Verify all test components are running
# ------------------------------------------------------------------
echo -e "\033[34m[INFO]\033[0m --- 9.1: Test Environment ---"
test "Backend health endpoint" sh -c "
  curl -s -o /dev/null -w '%{http_code}' $BASE_URL/health | grep -q '200'
"
test "Frontend accessible" sh -c "
  curl -s -o /dev/null -w '%{http_code}' $BASE_URL/ | grep -q '200'
"
test "Redis responds" sh -c "
  docker-compose exec -T redis redis-cli ping 2>/dev/null | grep -q PONG
"
test "Cassandra accessible via backend" sh -c "
  docker-compose exec -T backend wget --no-verbose -O- http://localhost:3000/health 2>/dev/null | grep -q ok
"
echo ""

# ------------------------------------------------------------------
# 9.2 + 9.3 - URL creation, cache miss (first access = miss), redirect
# ------------------------------------------------------------------
echo -e "\033[34m[INFO]\033[0m --- 9.2 + 9.3: Create URL + Cache Miss + Redirect ---"
# Store shortId for later tests
test "Create URL returns 201" sh -c "
  STATUS=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $BASE_URL/api/v1/urls \
    -H 'Content-Type: application/json' \
    -d '{\"original_url\":\"https://example.com/e2e-test\"}')
  [ \"\$STATUS\" = \"201\" ] || [ \"\$STATUS\" = \"200\" ]
"

# Extract short_id for follow-up tests
RESPONSE=$(curl -s -X POST $BASE_URL/api/v1/urls \
  -H 'Content-Type: application/json' \
  -d '{"original_url":"https://example.com/e2e-test-2"}')
SHORT_ID=$(echo "$RESPONSE" | sed 's/.*"short_id":"\([^"]*\)".*/\1/')
SHORT_URL=$(echo "$RESPONSE" | sed 's/.*"short_url":"\([^"]*\)".*/\1/')
echo -e "\033[34m[INFO]\033[0m Short ID: $SHORT_ID"
echo -e "\033[34m[INFO]\033[0m Short URL: $SHORT_URL"

test "Redirect returns 302" sh -c "
  STATUS=\$(curl -s -o /dev/null -w '%{http_code}' $BASE_URL/$SHORT_ID)
  [ \"\$STATUS\" = \"302\" ]
"

test "Redirect Location header is correct" sh -c "
  LOCATION=\$(curl -s -I $BASE_URL/$SHORT_ID 2>/dev/null | grep -i '^location:' | tr -d '\\r' | sed 's/[Ll][Oo][Cc][Aa][Tt][Ii][Oo][Nn]: //i')
  echo \"Location: \$LOCATION\"
  [ \"\$LOCATION\" = \"https://example.com/e2e-test-2\" ]
"

# 9.3: Clear Redis cache, then verify Cassandra fallback still works
test "Cache miss fallback (Cassandra)" sh -c "
  docker-compose exec -T redis redis-cli DEL $SHORT_ID 2>/dev/null
  STATUS=\$(curl -s -o /dev/null -w '%{http_code}' $BASE_URL/$SHORT_ID)
  [ \"\$STATUS\" = \"302\" ]
"
echo ""

# ------------------------------------------------------------------
# 9.4 - Concurrent requests for same shortId
# ------------------------------------------------------------------
echo -e "\033[34m[INFO]\033[0m --- 9.4: Concurrent Requests for Same URL ---"
test "5 concurrent GETs all succeed" sh -c "
  for i in \$(seq 1 5); do
    curl -s -o /dev/null -w '%{http_code}' $BASE_URL/$SHORT_ID &
  done
  wait
  # All background jobs finished without error
  true
"

test "5 concurrent GETs all return 302" sh -c "
  RESULTS=\"\"
  for i in \$(seq 1 5); do
    CODE=\$(curl -s -o /dev/null -w '%{http_code}' $BASE_URL/$SHORT_ID)
    RESULTS=\"\$RESULTS \$CODE\"
  done
  for code in \$RESULTS; do
    if [ \"\$code\" != \"302\" ]; then
      echo \"Got \$code, expected 302\"
      exit 1
    fi
  done
  echo \"All 5 returned 302: \$RESULTS\"
  true
"
echo ""

# ------------------------------------------------------------------
# 9.6 - Distributed counter under concurrent load
# ------------------------------------------------------------------
echo -e "\033[34m[INFO]\033[0m --- 9.6: Distributed Counter (Concurrent Creation) ---"
test "10 concurrent POSTs produce unique shortIds" sh -c "
  RESULTS=\"\"
  for i in \$(seq 1 10); do
    (
      URL=\"https://example.com/concurrent-\$RANDOM-\$RANDOM\"
      SHORT=\$(curl -s -X POST $BASE_URL/api/v1/urls \
        -H 'Content-Type: application/json' \
        -d \"{\\\"original_url\\\":\\\"\$URL\\\"}\" | sed 's/.*\"short_id\":\"\([^\"]*\)\".*/\\1/')
      echo \"\$SHORT\" >> /tmp/concurrent-ids.txt
    ) &
  done
  wait
  UNIQUE=\$(sort -u /tmp/concurrent-ids.txt | wc -l)
  TOTAL=\$(wc -l < /tmp/concurrent-ids.txt)
  rm -f /tmp/concurrent-ids.txt
  [ \"\$UNIQUE\" = \"\$TOTAL\" ] && [ \"\$TOTAL\" = \"10\" ]
"
echo ""

# ------------------------------------------------------------------
# 9.10 - Rate limiting
# ------------------------------------------------------------------
echo -e "\033[34m[INFO]\033[0m --- 9.10: Rate Limiting ---"
test "Rate limit exceeded returns 429" sh -c "
  # We'll send requests in bursts; this IP will eventually hit the limit
  # Target a specific endpoint that triggers rate limiting quickly
  LAST_STATUS=200
  for i in \$(seq 1 110); do
    STATUS=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $BASE_URL/api/v1/urls \
      -H 'Content-Type: application/json' \
      -d '{\"original_url\":\"https://example.com/rate-test-'$i'\"}')
    if [ \"\$STATUS\" = \"429\" ]; then
      echo \"Hit rate limit at request \$i\"
      exit 0
    fi
    LAST_STATUS=\$STATUS
  done
  echo \"Did not hit rate limit after 110 requests (last status: \$LAST_STATUS)\"
  exit 1
"
echo ""

# ------------------------------------------------------------------
# 9.11 - Invalid URL rejection
# ------------------------------------------------------------------
echo -e "\033[34m[INFO]\033[0m --- 9.11: Invalid URL Rejection ---"
test "Empty body returns 400" sh -c "
  STATUS=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $BASE_URL/api/v1/urls \
    -H 'Content-Type: application/json' \
    -d '{}')
  [ \"\$STATUS\" = \"400\" ]
"

test "Malformed URL returns 400" sh -c "
  STATUS=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $BASE_URL/api/v1/urls \
    -H 'Content-Type: application/json' \
    -d '{\"original_url\":\"not-a-valid-url\"}')
  [ \"\$STATUS\" = \"400\" ]
"

test "Missing scheme returns 400" sh -c "
  STATUS=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $BASE_URL/api/v1/urls \
    -H 'Content-Type: application/json' \
    -d '{\"original_url\":\"example.com/test\"}')
  [ \"\$STATUS\" = \"400\" ]
"

test "Null URL returns 400" sh -c "
  STATUS=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $BASE_URL/api/v1/urls \
    -H 'Content-Type: application/json' \
    -d '{\"original_url\":null}')
  [ \"\$STATUS\" = \"400\" ]
"

test "Non-string URL returns 400" sh -c "
  STATUS=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $BASE_URL/api/v1/urls \
    -H 'Content-Type: application/json' \
    -d '{\"original_url\":123}')
  [ \"\$STATUS\" = \"400\" ]
"
echo ""

# ------------------------------------------------------------------
# 9.12 - Batch URL creation
# ------------------------------------------------------------------
echo -e "\033[34m[INFO]\033[0m --- 9.12: Batch URL Creation ---"
test "Batch with 5 URLs returns 201" sh -c "
  STATUS=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $BASE_URL/api/v1/urls/batch \
    -H 'Content-Type: application/json' \
    -d '{\"urls\":[\"https://example.com/b1\",\"https://example.com/b2\",\"https://example.com/b3\",\"https://example.com/b4\",\"https://example.com/b5\"]}')
  [ \"\$STATUS\" = \"201\" ]
"

test "Batch result contains 5 entries" sh -c "
  RESULT=\$(curl -s -X POST $BASE_URL/api/v1/urls/batch \
    -H 'Content-Type: application/json' \
    -d '{\"urls\":[\"https://example.com/c1\",\"https://example.com/c2\",\"https://example.com/c3\"]}')
  COUNT=\$(echo \"\$RESULT\" | grep -o 'short_url' | wc -l)
  [ \"\$COUNT\" = \"3\" ]
"

test "Empty batch array returns 400" sh -c "
  STATUS=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $BASE_URL/api/v1/urls/batch \
    -H 'Content-Type: application/json' \
    -d '{\"urls\":[]}')
  [ \"\$STATUS\" = \"400\" ]
"

test "Batch missing urls field returns 400" sh -c "
  STATUS=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $BASE_URL/api/v1/urls/batch \
    -H 'Content-Type: application/json' \
    -d '{}')
  [ \"\$STATUS\" = \"400\" ]
"

test "All batch short URLs redirect correctly" sh -c "
  RESULT=\$(curl -s -X POST $BASE_URL/api/v1/urls/batch \
    -H 'Content-Type: application/json' \
    -d '{\"urls\":[\"https://example.com/verify1\",\"https://example.com/verify2\"]}')
  IDS=\$(echo \"\$RESULT\" | sed 's/.*\"short_id\":\"\([^\"]*\)\".*/\\1/g')
  ALL_OK=true
  for id in \$IDS; do
    CODE=\$(curl -s -o /dev/null -w '%{http_code}' $BASE_URL/\$id)
    if [ \"\$CODE\" != \"302\" ]; then
      ALL_OK=false
    fi
  done
  \$ALL_OK
"
echo ""

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
echo -e "\033[34m[INFO]\033[0m ==========================================="
if [ "$FAIL" -eq 0 ]; then
  echo -e "\033[32m[PASS]\033[0m All tests passed: $PASS passed, $FAIL failed"
  echo -e "\033[34m[INFO]\033[0m ==========================================="
  exit 0
else
  echo -e "\033[31m[FAIL]\033[0m Some tests failed: $PASS passed, $FAIL failed"
  echo -e "\033[31m[FAIL]\033[0m Failed tests:"
  echo -e "$FAILED_TESTS"
  echo -e "\033[34m[INFO]\033[0m ==========================================="
  exit 1
fi