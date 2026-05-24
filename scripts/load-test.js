// k6 load test for URL shortener
// Run: k6 run scripts/load-test.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const failureRate = new Rate('failed_requests');

export const options = {
  stages: [
    { duration: '30s', target: 100 },
    { duration: '1m', target: 100 },
    { duration: '30s', target: 500 },
    { duration: '1m', target: 500 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p95<200', 'p99<500'],
    failed_requests: ['rate<0.01'],
  },
};

export default function () {
  const url = `https://example.com/test-${Math.random()}`;
  const createRes = http.post(`${BASE_URL}/api/v1/urls`,
    JSON.stringify({ original_url: url }),
    { headers: { 'Content-Type': 'application/json' } }
  );

  check(createRes, { 'create status 201': (r) => r.status === 201 });
  failureRate.add(createRes.status !== 201);

  if (createRes.status === 201) {
    const shortUrl = createRes.json('short_url');
    const shortId = shortUrl.split('/').pop();

    const redirectRes = http.get(`${BASE_URL}/${shortId}`, { maxRedirects: 0 });
    check(redirectRes, { 'redirect status 302': (r) => r.status === 302 });
    failureRate.add(redirectRes.status !== 302);
  }

  sleep(1);
}