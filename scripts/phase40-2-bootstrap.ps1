# Phase 40.2 — Local staging simulation bootstrap (Windows)
# Requires: Docker Desktop running, Node 20+, npm deps in services/api
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

Write-Host "==> Starting Postgres"
docker compose -f "$Root/docker-compose.yml" up -d postgres
Start-Sleep -Seconds 5

Write-Host "==> Applying migrations 034-038"
$env:DATABASE_URL = "postgres://postgres:postgres@localhost:5432/owanbe"
node "$Root/scripts/phase40-2-apply-migrations.js"
node "$Root/scripts/phase40-2-reset-tier-inventory.js"

Write-Host "==> Starting alert receiver + mock Quaser"
$alertPort = 9191
$env:MOCK_QUASER_PORT = "9090"
$env:QUASER_WEBHOOK_SECRET = "phase9-test-webhook-secret"
Start-Process -NoNewWindow node -ArgumentList "$Root/scripts/mock-quaser-server.js"
Start-Sleep -Seconds 2

Write-Host "==> Starting API (production integrations mode)"
$env:SUPABASE_JWT_SECRET = "dev-jwt-secret-16chars"
$env:INTEGRATIONS_MODE = "production"
$env:QUASER_ROUTER_BASE_URL = "http://localhost:9090"
$env:PUBLIC_API_BASE_URL = "http://localhost:8080"
$env:QUASER_WEBHOOK_SECRET = "phase9-test-webhook-secret"
$env:ALERT_WEBHOOK_URL = "http://127.0.0.1:$alertPort/alert"
$env:CORS_ORIGINS = "http://localhost:3000,https://app.staging.owanbe.com"
$env:PORT = "8080"
Start-Process -NoNewWindow npm -ArgumentList "run","start" -WorkingDirectory "$Root/services/api"
Start-Sleep -Seconds 15

Write-Host "==> Running readiness execution"
$env:API_BASE = "http://localhost:8080/v1"
$env:HEALTH_BASE = "http://localhost:8080"
node "$Root/scripts/phase40-2-staging-readiness.js"
exit $LASTEXITCODE
