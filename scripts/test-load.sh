#!/usr/bin/env bash
set -e

BASE_URL=${BASE_URL:-http://localhost:8080}
CONCURRENCY=${CONCURRENCY:-10}
TOTAL_REQUESTS=${TOTAL_REQUESTS:-100}
CURRENT=0
PASSED=0
FAILED=0
START_TIME=$(date +%s%N)
RESPONSE_TIMES=""
VERIFY_URL=${VERIFY_URL:-""}

echo -e "\033[34m[INFO]\033[0m ==========================================="
echo -e "\033[34m[INFO]\033[0m  Load Test"
echo -e "\033[34m[INFO]\033[0m  Distributed URL Shortener"
echo -e "\033[34m[INFO]\033[0m ==========================================="
echo ""
echo -e "\033[34m[INFO]\033[0m Target:         $BASE_URL"
echo -e "\033[34m[INFO]\033[0m Concurrency:    $CONCURRENCY"
echo -e "\033[34m[INFO]\033[0m Total Requests: $TOTAL_REQUESTS"
echo ""

if [ -z "$VERIFY_URL" ]; then
  echo -e "\033[34m[INFO]\033[0m Creating a short URL for redirect load tests..."
  RESPONSE=$(curl -s -X POST $BASE_URL/api/v1/urls \
    -H "Content-Type: application/json" \
    -d '{"original_url":"https://example.com/load-test"}')
  VERIFY_URL=$(echo "$RESPONSE" | sed 's/.*"short_id":"\([^"]*\)".*/\1/')
  echo -e "\033[34m[INFO]\033[0m Short ID: $VERIFY_URL"
fi

echo ""
echo -e "\033[34m[INFO]\033[0m --- Phase 1: POST (URL Creation) ---"

post_test() {
  local id=$1
  local url="https://example.com/load-$(date +%s)-$RANDOM"
  local t0=$(date +%s%N)
  local status=$(curl -s -o /dev/null -w "%{http_code}" -X POST $BASE_URL/api/v1/urls \
    -H "Content-Type: application/json" \
    -d "{\"original_url\":\"$url\"}")
  local t1=$(date +%s%N)
  local elapsed=$(( (t1 - t0) / 1000000 ))
  echo "$status $elapsed" >> /tmp/load-post-results.txt
}

for i in $(seq 1 $TOTAL_REQUESTS); do
  post_test $i &
  if [ $((i % CONCURRENCY)) -eq 0 ]; then
    wait
  fi
done
wait

echo -e "\033[34m[INFO]\033[0m --- Phase 2: GET (Redirect) ---"

get_test() {
  local t0=$(date +%s%N)
  local status=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/$VERIFY_URL)
  local t1=$(date +%s%N)
  local elapsed=$(( (t1 - t0) / 1000000 ))
  echo "$status $elapsed" >> /tmp/load-get-results.txt
}

for i in $(seq 1 $TOTAL_REQUESTS); do
  get_test $i &
  if [ $((i % CONCURRENCY)) -eq 0 ]; then
    wait
  fi
done
wait

echo -e "\033[34m[INFO]\033[0m --- Results ---"

echo ""
echo "POST Results:"
POST_TOTAL=$(wc -l < /tmp/load-post-results.txt 2>/dev/null || echo 0)
POST_2XX=$(grep -c '^2' /tmp/load-post-results.txt 2>/dev/null || echo 0)
POST_4XX=$(grep -c '^4' /tmp/load-post-results.txt 2>/dev/null || echo 0)
POST_5XX=$(grep -c '^5' /tmp/load-post-results.txt 2>/dev/null || echo 0)
POST_TIMES=$(awk '{print $2}' /tmp/load-post-results.txt 2>/dev/null || echo "")
if [ -n "$POST_TIMES" ]; then
  POST_AVG=$(echo "$POST_TIMES" | awk '{sum+=$1; count++} END {if(count>0) print int(sum/count); else print 0}')
  POST_P95=$(echo "$POST_TIMES" | sort -n | awk '{arr[NR]=$1} END {idx=int(NR*0.95); if(idx<1) idx=1; print arr[idx]}')
  POST_MAX=$(echo "$POST_TIMES" | sort -n | tail -1)
else
  POST_AVG=0; POST_P95=0; POST_MAX=0
fi

echo "  Total:    $POST_TOTAL"
echo "  2xx:      $POST_2XX"
echo "  4xx:      $POST_4XX"
echo "  5xx:      $POST_5XX"
echo "  Avg ms:   $POST_AVG"
echo "  P95 ms:   $POST_P95"
echo "  Max ms:   $POST_MAX"
echo ""

echo "GET Results:"
GET_TOTAL=$(wc -l < /tmp/load-get-results.txt 2>/dev/null || echo 0)
GET_2XX=$(grep -c '^2' /tmp/load-get-results.txt 2>/dev/null || echo 0)
GET_3XX=$(grep -c '^3' /tmp/load-get-results.txt 2>/dev/null || echo 0)
GET_4XX=$(grep -c '^4' /tmp/load-get-results.txt 2>/dev/null || echo 0)
GET_5XX=$(grep -c '^5' /tmp/load-get-results.txt 2>/dev/null || echo 0)
GET_TIMES=$(awk '{print $2}' /tmp/load-get-results.txt 2>/dev/null || echo "")
if [ -n "$GET_TIMES" ]; then
  GET_AVG=$(echo "$GET_TIMES" | awk '{sum+=$1; count++} END {if(count>0) print int(sum/count); else print 0}')
  GET_P95=$(echo "$GET_TIMES" | sort -n | awk '{arr[NR]=$1} END {idx=int(NR*0.95); if(idx<1) idx=1; print arr[idx]}')
  GET_MAX=$(echo "$GET_TIMES" | sort -n | tail -1)
else
  GET_AVG=0; GET_P95=0; GET_MAX=0
fi

echo "  Total:    $GET_TOTAL"
echo "  2xx:      $GET_2XX"
echo "  3xx:      $GET_3XX"
echo "  4xx:      $GET_4XX"
echo "  5xx:      $GET_5XX"
echo "  Avg ms:   $GET_AVG"
echo "  P95 ms:   $GET_P95"
echo "  Max ms:   $GET_MAX"
echo ""

END_TIME=$(date +%s%N)
TOTAL_SECONDS=$(( (END_TIME - START_TIME) / 1000000000 ))
TOTAL_REQ=$((POST_TOTAL + GET_TOTAL))
THROUGHPUT=$(( TOTAL_REQ / TOTAL_SECONDS )) 2>/dev/null || THROUGHPUT=0

echo "Summary:"
echo "  Duration:       ${TOTAL_SECONDS}s"
echo "  Total Requests: $TOTAL_REQ"
echo "  Throughput:     ${THROUGHPUT} req/s"
echo ""

rm -f /tmp/load-post-results.txt /tmp/load-get-results.txt

# Check pass/fail: no 5xx errors
if [ "$POST_5XX" -eq 0 ] && [ "$GET_5XX" -eq 0 ]; then
  echo -e "\033[32m[PASS]\033[0m Load test completed without server errors"
  exit 0
else
  echo -e "\033[31m[FAIL]\033[0m Load test detected $POST_5XX POST + $GET_5XX GET server errors"
  exit 1
fi