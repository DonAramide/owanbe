# Phase 41 — Performance Report

**Generated:** 2026-06-26T17:49:22.855Z

{
  "raw": "{\n  \"phase\": \"41\",\n  \"task\": \"P2-performance\",\n  \"target\": \"http://localhost:8080\",\n  \"checkedAt\": \"2026-06-26T17:49:02.615Z\",\n  \"scenarios\": [\n    {\n      \"concurrency\": 50,\n      \"total\": 100,\n      \"durationMs\": 268,\n      \"errors\": 100,\n      \"p50\": 73,\n      \"p95\": 88,\n      \"p99\": 89\n    },\n    {\n      \"concurrency\": 50,\n      \"total\": 500,\n      \"durationMs\": 765,\n      \"errors\": 500,\n      \"p50\": 77,\n      \"p95\": 94,\n      \"p99\": 97\n    },\n    {\n      \"concurrency\": 50,\n      \"total\": 1000,\n      \"durationMs\": 1209,\n      \"errors\": 1000,\n      \"p50\": 60,\n      \"p95\": 78,\n      \"p99\": 87\n    }\n  ],\n  \"result\": \"PARTIAL\",\n  \"note\": \"API process memory/CPU and DB pool require host monitoring during soak\"\n}\n",
  "code": 1
}

> Re-run with API live: `HEALTH_BASE=https://api.staging.owanbe.com node scripts/phase41-performance.js`
