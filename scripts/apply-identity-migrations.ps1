# Apply v1.0.1 identity migrations on Windows (no local psql required).
# Requires: Docker Desktop + owanbe-postgres container (docker compose up -d postgres)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

Write-Host "==> Ensuring Postgres is running"
docker compose -f "$Root/docker-compose.yml" up -d postgres | Out-Null
Start-Sleep -Seconds 3

function Apply-SqlFile($relativePath) {
  $full = Join-Path $Root $relativePath
  if (-not (Test-Path $full)) {
    throw "SQL file not found: $full"
  }
  Write-Host "==> Applying $relativePath"
  Get-Content $full -Raw | docker exec -i owanbe-postgres psql -U postgres -d owanbe -v ON_ERROR_STOP=1
  if ($LASTEXITCODE -ne 0) {
    throw "Failed applying $relativePath (exit $LASTEXITCODE)"
  }
}

Apply-SqlFile "infra/db/028_identity_v101.sql"
Apply-SqlFile "infra/db/029_identity_dev_seed.sql"

Write-Host ""
Write-Host "Done. Next steps:"
Write-Host "  1. Supabase SQL Editor: scripts/supabase/seed-dev-auth-users.sql"
Write-Host "  2. Restart API:  cd services\api; npm run start:dev"
Write-Host "  3. Run mobile:   cd mobile; flutter run -d chrome"
