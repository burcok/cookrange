#!/usr/bin/env node
/**
 * Cookrange AI Proxy + Firestore Load Test
 *
 * Usage:
 *   PROXY_URL=https://... ID_TOKEN=<firebase-id-token> node scripts/load_test.js
 *
 * Optional env vars:
 *   CONCURRENCY  — number of simultaneous requests (default: 10)
 *   TOTAL        — total requests to fire (default: 50)
 *   TIMEOUT_MS   — per-request timeout in ms (default: 15000)
 *
 * How to get an ID token for testing:
 *   firebase auth:signin-with-email-and-password --email ... --password ...
 *   OR from the Flutter app: FirebaseAuth.instance.currentUser?.getIdToken()
 */

'use strict';

const https = require('https');
const http  = require('http');
const { URL } = require('url');

// ── Config ────────────────────────────────────────────────────────────────────

const PROXY_URL    = process.env.PROXY_URL;
const ID_TOKEN     = process.env.ID_TOKEN;
const CONCURRENCY  = parseInt(process.env.CONCURRENCY  || '10',  10);
const TOTAL        = parseInt(process.env.TOTAL        || '50',  10);
const TIMEOUT_MS   = parseInt(process.env.TIMEOUT_MS   || '15000', 10);

// Minimal AI request payload that the proxy accepts.
const REQUEST_BODY = JSON.stringify({
  messages: [{ role: 'user', content: 'hi' }],
  max_tokens: 1,
});

// ── Validation ────────────────────────────────────────────────────────────────

if (!PROXY_URL) {
  console.error('❌  PROXY_URL env var is required.');
  process.exit(1);
}
if (!ID_TOKEN) {
  console.error('❌  ID_TOKEN env var is required.');
  process.exit(1);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function request(url, token) {
  return new Promise((resolve) => {
    const parsed = new URL(url);
    const lib    = parsed.protocol === 'https:' ? https : http;
    const start  = Date.now();

    const options = {
      hostname: parsed.hostname,
      port:     parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
      path:     parsed.pathname + parsed.search,
      method:   'POST',
      headers: {
        'Content-Type':  'application/json',
        'Content-Length': Buffer.byteLength(REQUEST_BODY),
        'Authorization': `Bearer ${token}`,
      },
      timeout: TIMEOUT_MS,
    };

    const req = lib.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        resolve({
          status:  res.statusCode,
          latency: Date.now() - start,
          ok:      res.statusCode >= 200 && res.statusCode < 300,
          body:    body.slice(0, 120),
        });
      });
    });

    req.on('timeout', () => {
      req.destroy();
      resolve({ status: 0, latency: TIMEOUT_MS, ok: false, body: 'TIMEOUT' });
    });

    req.on('error', (err) => {
      resolve({
        status:  0,
        latency: Date.now() - start,
        ok:      false,
        body:    err.message,
      });
    });

    req.write(REQUEST_BODY);
    req.end();
  });
}

function percentile(sorted, p) {
  const idx = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.max(0, idx)];
}

function bar(n, max, width = 20) {
  const filled = Math.round((n / max) * width);
  return '█'.repeat(filled) + '░'.repeat(width - filled);
}

// ── Runner ────────────────────────────────────────────────────────────────────

async function run() {
  console.log('\n🔥  Cookrange Load Test');
  console.log(`   Target    : ${PROXY_URL}`);
  console.log(`   Concurrency: ${CONCURRENCY}  Total: ${TOTAL}  Timeout: ${TIMEOUT_MS}ms`);
  console.log('─'.repeat(60));

  const results  = [];
  let   sent     = 0;
  let   done     = 0;
  const startAll = Date.now();

  // Worker pool — keeps CONCURRENCY slots busy until TOTAL requests are done.
  async function worker() {
    while (sent < TOTAL) {
      const idx = ++sent;
      const result = await request(PROXY_URL, ID_TOKEN);
      done++;
      results.push(result);

      const pct   = Math.round((done / TOTAL) * 100);
      const color = result.ok ? '\x1b[32m✓\x1b[0m' : '\x1b[31m✗\x1b[0m';
      process.stdout.write(
        `\r  [${bar(done, TOTAL)}] ${pct}%  ${color} #${idx} → ${result.status} ${result.latency}ms   `
      );
    }
  }

  const workers = Array.from({ length: CONCURRENCY }, () => worker());
  await Promise.all(workers);

  const elapsed = Date.now() - startAll;

  // ── Stats ──────────────────────────────────────────────────────────────────

  process.stdout.write('\n');
  console.log('─'.repeat(60));

  const latencies = results.map((r) => r.latency).sort((a, b) => a - b);
  const successes = results.filter((r) => r.ok).length;
  const failures  = results.filter((r) => !r.ok);
  const rps       = (TOTAL / (elapsed / 1000)).toFixed(1);

  console.log('\n📊  Results\n');
  console.log(`  Requests    : ${TOTAL}`);
  console.log(`  Concurrency : ${CONCURRENCY}`);
  console.log(`  Total time  : ${elapsed}ms`);
  console.log(`  Throughput  : ${rps} req/s`);
  console.log(`  Success     : ${successes}/${TOTAL} (${Math.round((successes/TOTAL)*100)}%)`);
  console.log(`  Failures    : ${failures.length}`);
  console.log('');
  console.log('  Latency (ms):');
  console.log(`    Min  : ${latencies[0]}`);
  console.log(`    P50  : ${percentile(latencies, 50)}`);
  console.log(`    P90  : ${percentile(latencies, 90)}`);
  console.log(`    P95  : ${percentile(latencies, 95)}`);
  console.log(`    P99  : ${percentile(latencies, 99)}`);
  console.log(`    Max  : ${latencies[latencies.length - 1]}`);

  // Status code breakdown
  const byStatus = {};
  for (const r of results) {
    byStatus[r.status] = (byStatus[r.status] || 0) + 1;
  }
  console.log('\n  Status codes:');
  for (const [code, count] of Object.entries(byStatus).sort()) {
    const label = code === '0' ? '  0 (timeout/net)' : code;
    console.log(`    ${label}: ${count}`);
  }

  // First few failures
  if (failures.length > 0) {
    console.log('\n  Sample failures:');
    failures.slice(0, 3).forEach((f) => {
      console.log(`    HTTP ${f.status} — ${f.body}`);
    });
  }

  console.log('\n' + '─'.repeat(60));

  // Exit non-zero if error rate > 5 %
  const errorRate = failures.length / TOTAL;
  if (errorRate > 0.05) {
    console.log(`\n⚠️   Error rate ${(errorRate * 100).toFixed(1)}% exceeds 5% threshold — FAIL\n`);
    process.exit(1);
  } else {
    console.log('\n✅  PASS\n');
  }
}

run().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
