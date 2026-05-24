#!/bin/bash
set -e

REDIS_URL="${REDIS_URL:-redis://localhost:6379}"

echo "=== Distributed Counter Test ==="
echo "Redis URL: $REDIS_URL"

echo ""
echo "--- Testing Base62 Encoding ---"
node -e "
const { encode, decode } = require('../backend/src/utils/base62');
const tests = [
  [0, '0'],
  [1, '1'],
  [9, '9'],
  [10, 'a'],
  [35, 'z'],
  [36, 'A'],
  [61, 'Z'],
  [62, '10'],
  [1000000, '4c92'],
  [999999999, '15FTGf'],
];
let pass = true;
for (const [input, expected] of tests) {
  const result = encode(input);
  const decoded = decode(result);
  const ok = result === expected && decoded === input;
  if (!ok) {
    console.log('FAIL: encode(' + input + ') = ' + result + ' (expected ' + expected + ')');
    pass = false;
  }
  if (decoded !== input) {
    console.log('FAIL: decode(' + result + ') = ' + decoded + ' (expected ' + input + ')');
    pass = false;
  }
}
if (pass) {
  console.log('All base62 tests PASSED');
} else {
  console.log('Some base62 tests FAILED');
  process.exit(1);
}
"

echo ""
echo "--- Testing Redis Counter ---"
node -e "
const { getClient, closeClient } = require('../backend/src/services/redis');
const { getNextId, getCurrentValue, getCounterKey, COUNTER_KEY } = require('../backend/src/services/counter');

async function main() {
  const redis = getClient();
  try {
    await redis.del(COUNTER_KEY);
    console.log('Counter key: ' + getCounterKey());

    const val1 = await getNextId();
    console.log('INCR 1 => ' + val1);
    if (val1 !== 1) {
      console.log('FAIL: expected 1, got ' + val1);
      process.exit(1);
    }

    const val2 = await getNextId();
    console.log('INCR 2 => ' + val2);
    if (val2 !== 2) {
      console.log('FAIL: expected 2, got ' + val2);
      process.exit(1);
    }

    const current = await getCurrentValue();
    console.log('Current value: ' + current);

    const encoded = require('../backend/src/utils/base62').encode(val2);
    console.log('Base62 of ' + val2 + ' => ' + encoded);

    console.log('');
    console.log('All counter tests PASSED');
  } finally {
    await redis.del(COUNTER_KEY);
    closeClient();
  }
}

main().catch(err => {
  console.error('Counter test FAILED:', err.message);
  process.exit(1);
});
"

echo ""
echo "=== All tests completed ==="