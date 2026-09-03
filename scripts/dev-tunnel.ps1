# Owanbe development Cloudflare Tunnel (owanbe-dev).
# Does NOT modify bar-backend / api.iips.com (uses ~/.cloudflared/owanbe-dev.yml).
$ErrorActionPreference = "Stop"
$config = Join-Path $env:USERPROFILE ".cloudflared\owanbe-dev.yml"
if (-not (Test-Path $config)) {
  Write-Error "Missing $config. Copy infra/dev/cloudflared-owanbe-dev.yml.example and set credentials-file."
}
cloudflared tunnel --config $config run owanbe-dev @args
