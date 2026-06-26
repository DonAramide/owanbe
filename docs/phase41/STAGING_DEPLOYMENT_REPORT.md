# Phase 41 — Staging Deployment Report

**Generated:** 2026-06-26T11:42:08.590Z  
**Result:** FAIL / BLOCKED

## Domains

| Domain | Status |
|--------|--------|
| api.staging.owanbe.com | Not deployed |
| app.staging.owanbe.com | Pending Flutter web deploy |
| vendors.staging.owanbe.com | Pending |
| admin.staging.owanbe.com | Pending |

## Configuration checklist

- [ ] HTTPS / TLS
- [ ] HSTS
- [ ] CORS (`CORS_ORIGINS`)
- [ ] Compression (CDN/nginx)
- [ ] Security headers
- [ ] `GET /health`

## Script output

```json
{
  "raw": "{\n  \"phase\": \"41\",\n  \"task\": \"P0.1-staging-infrastructure\",\n  \"checkedAt\": \"2026-06-26T11:41:37.316Z\",\n  \"domains\": {\n    \"api\": {\n      \"url\": \"https://api.staging.owanbe.com\",\n      \"pass\": false,\n      \"error\": \"fetch failed\"\n    },\n    \"app\": {\n      \"url\": \"https://app.staging.owanbe.com\",\n      \"pass\": false,\n      \"error\": \"fetch failed\"\n    },\n    \"vendors\": {\n      \"url\": \"https://vendors.staging.owanbe.com\",\n      \"pass\": false,\n      \"error\": \"fetch failed\"\n    },\n    \"admin\": {\n      \"url\": \"https://admin.staging.owanbe.com\",\n      \"pass\": false,\n      \"error\": \"fetch failed\"\n    }\n  },\n  \"tls\": {\n    \"url\": \"https://api.staging.owanbe.com\",\n    \"pass\": false,\n    \"error\": \"fetch failed\"\n  },\n  \"cors\": {\n    \"pass\": false,\n    \"error\": \"fetch failed\"\n  },\n  \"securityHeaders\": {\n    \"pass\": false,\n    \"error\": \"fetch failed\"\n  },\n  \"health\": {\n    \"pass\": false,\n    \"error\": \"fetch failed\"\n  },\n  \"result\": \"FAIL\"\n}\n",
  "code": 1
}
```
