# Phase 41 — Performance Report

**Generated:** 2026-06-26T11:42:08.590Z

{
  "raw": "{\n  \"phase\": \"41\",\n  \"task\": \"P2-performance\",\n  \"target\": \"http://localhost:8080\",\n  \"checkedAt\": \"2026-06-26T11:41:48.370Z\",\n  \"scenarios\": [\n    {\n      \"concurrency\": 50,\n      \"total\": 100,\n      \"durationMs\": 229,\n      \"errors\": 100,\n      \"p50\": 59,\n      \"p95\": 73,\n      \"p99\": 74\n    },\n    {\n      \"concurrency\": 50,\n      \"total\": 500,\n      \"durationMs\": 732,\n      \"errors\": 500,\n      \"p50\": 74,\n      \"p95\": 84,\n      \"p99\": 90\n    },\n    {\n      \"concurrency\": 50,\n      \"total\": 1000,\n      \"durationMs\": 1304,\n      \"errors\": 1000,\n      \"p50\": 63,\n      \"p95\": 80,\n      \"p99\": 86\n    }\n  ],\n  \"result\": \"PARTIAL\",\n  \"note\": \"API process memory/CPU and DB pool require host monitoring during soak\"\n}\n",
  "code": 1
}

> Re-run with API live: `HEALTH_BASE=https://api.staging.owanbe.com node scripts/phase41-performance.js`
