#!/usr/bin/env bash
set -e

# Simple load test using curl + background processes
# No k6 required
#
# Usage:
#   ./scripts/load-test-simple.sh                 # defaults (10 concurrent, 100 total)
#   CONCURRENCY=50 TOTAL=500 ./load-test-simple.sh # 50 concurrent, 500 total

BASE_URL=${BASE_URL:-http://localhost:8080}
CONCURRENCY=${CONCURRENCY:-10}
TOTAL=${TOTAL:-100}
START_TIME=$(date +%s%N)
TMP_DIR=$(mktemp -d)

echo -e "\033[34m[INFO]\033[0m ==========================================="
echo -e "\033[34m[INFO]\033[0m  Performance Load Test"
echo -e "\033[34m[INFO]\033[0m  Distributed URL Shortener"
echo -e "\033[34m[INFO]\033[0m ==========================================="
echo ""
echo -e "\033[34m[INFO]\033[0m Target:         $BASE_URL"
echo -e "\033[34m[INFO]\033[0m Concurrency:    $CONCURRENCY"
echo -e "\033[34m[INFO]\033[0m Total Requests: $TOTAL"
echo ""

# Create a short URL for redirect tests first
echo -e "\033[34m[INFO]\033[0m Creating seed URL for redirect tests..."
SEED_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/urls" \
  -H "Content-Type: application/json" \
  -d '{"original_url":"https://example.com/load-test-seed"}')
SEED_ID=$(echo "$SEED_RESPONSE" | sed 's/.*"short_id":"\([^"]*\)".*/\1/')
echo -e "\033[34m[INFO]\033[0m Seed short ID: $SEED_ID"
echo ""

# -------------------------------------------------------
# Phase 1: POST (URL Creation)
# -------------------------------------------------------
echo -e "\033[34m[INFO]\033[0m --- Phase 1: URL Creation (POST) ---"

post_test() {
  local id=$1
  local test_url="https://example.com/load-$(date +%s%N)-$RANDOM"
  local t0=$(date +%s%N)
  local status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/v1/urls" \
    -H "Content-Type: application/json" \
    -d "{\"original_url\":\"$test_url\"}")
  local t1=$(date +%s%N)
  local elapsed=$(( (t1 - t0) / 1000000 ))
  echo "$status $elapsed" >> "$TMP_DIR/post-results.txt"
}

for i in $(seq 1 "$TOTAL"); do
  post_test "$i" &
  if [ $((i % CONCURRENCY)) -eq 0 ]; then
    wait
  fi
done
wait

# -------------------------------------------------------
# Phase 2: GET (Redirect)
# -------------------------------------------------------
echo -e "\033[34m[INFO]\033[0m --- Phase 2: URL Redirect (GET) ---"

get_test() {
  local t0=$(date +%s%N)
  local status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/$SEED_ID")
  local t1=$(date +%s%N)
  local elapsed=$(( (t1 - t0) / 1000000 ))
  echo "$status $elapsed" >> "$TMP_DIR/get-results.txt"
}

for i in $(seq 1 "$TOTAL"); do
  get_test "$i" &
  if [ $((i % CONCURRENCY)) -eq 0 ]; then
    wait
  fi
done
wait

# -------------------------------------------------------
# Results
# -------------------------------------------------------
echo ""
echo -e "\033[34m[INFO]\033[0m --- Results ---"
echo ""

compute_stats() {
  local label=$1
  local file=$2

  local total=$(wc -l < "$file" 2>/dev/null || echo 0)
  local http_2xx=$(grep -c '^2' "$file" 2>/dev/null || echo 0)
  local http_3xx=$(grep -c '^3' "$file" 2>/dev/null || echo 0)
  local http_4xx=$(grep -c '^4' "$file" 2>/dev/null || echo 0)
  local http_5xx=$(grep -c '^5' "$file" 2>/dev/null || echo 0)
  local times=$(awk '{print $2}' "$file" 2>/dev/null || echo "")

  if [ -n "$times" ]; then
    local avg=$(echo "$times" | awk '{sum+=$1; count++} END {if(count>0) print int(sum/count); else print 0}')
    local sorted=$(echo "$times" | sort -n)
    local p50=$(echo "$sorted" | awk '{arr[NR]=$1} END {idx=int(NR*0.50); if(idx<1) idx=1; print arr[idx]}')
    local p95=$(echo "$sorted" | awk '{arr[NR]=$1} END {idx=int(NR*0.95); if(idx<1) idx=1; print arr[idx]}')
    local p99=$(echo "$sorted" | awk '{arr[NR]=$1} END {idx=int(NR*0.99); if(idx<1) idx=1; print arr[idx]}')
    local max=$(echo "$sorted" | tail -1)
  else
    avg=0; p50=0; p95=0; p99=0; max=0
  fi

  echo "$label"
  echo "  Total:     $total"
  echo "  2xx:       $http_2xx"
  echo "  3xx:       $http_3xx"
  echo "  4xx:       $http_4xx"
  echo "  5xx:       $http_5xx"
  echo "  Avg (ms):  $avg"
  echo "  P50 (ms):  $p50"
  echo "  P95 (ms):  $p95"
  echo "  P99 (ms):  $p99"
  echo "  Max (ms):  $max"
  echo ""
}

compute_stats "POST (URL Creation)" "$TMP_DIR/post-results.txt"
compute_stats "GET (Redirect)" "$TMP_DIR/get-results.txt"

# Summary
END_TIME=$(date +%s%N)
TOTAL_SECONDS=$(( (END_TIME - START_TIME) / 1000000000 ))
POST_TOTAL=$(wc -l < "$TMP_DIR/post-results.txt" 2>/dev/null || echo 0)
GET_TOTAL=$(wc -l < "$TMP_DIR/get-results.txt" 2>/dev/null || echo 0)
GRAND_TOTAL=$((POST_TOTAL + GET_TOTAL))
THROUGHPUT=0
if [ "$TOTAL_SECONDS" -gt 0 ]; then
  THROUGHPUT=$(( GRAND_TOTAL / TOTAL_SECONDS ))
fi

POST_5XX=$(grep -c '^5' "$TMP_DIR/post-results.txt" 2>/dev/null || echo 0)
GET_5XX=$(grep -c '^5' "$TMP_DIR/get-results.txt" 2>/dev/null || echo 0)

echo -e "\033[34m[INFO]\033[0m Summary:"
echo "  Duration:       ${TOTAL_SECONDS}s"
echo "  Total Requests: $GRAND_TOTAL"
echo "  Throughput:     ${THROUGHPUT} req/s"
echo ""

rm -rf "$TMP_DIR"

if [ "$POST_5XX" -eq 0 ] && [ "$GET_5XX" -eq 0 ]; then
  echo -e "\033[32m[PASS]\033[0m Load test completed without server errors"
  exit 0
else
  echo -e "\033[31m[FAIL]\033[0m Load test detected $POST_5XX POST + $GET_5XX GET server errors"
  exit 1
fi