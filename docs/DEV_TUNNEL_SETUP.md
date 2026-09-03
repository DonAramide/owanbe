# Owanbe development tunnel (Cloudflare)

Development-only HTTPS access for Customer and Admin Flutter web apps plus API path routing.

**Does not modify** `bar-backend`, `api.iips.com`, or any production infrastructure.

## Local development vs tunnel (keep these separate)

Normal Customer `flutter run` does **not** require Cloudflare, DNS, or `dev.owanbe.com`.

| Mode | When | Customer UI | Customer API (`OWANBE_API_BASE`) |
|------|------|-------------|----------------------------------|
| **Local (default)** | Everyday `flutter run -d chrome --web-port=3000` | `http://localhost:3000` | `http://127.0.0.1:8080/v1` in `mobile/assets/env/owanbe_config` |
| **Tunnel (opt-in)** | Phone/email + public HTTPS, after Cloudflare DNS is ready | `https://dev.owanbe.com` | `https://dev.owanbe.com/v1` — copy from `mobile/assets/env/owanbe_config.tunnel.example` |

Admin local default is the same API: `http://127.0.0.1:8080/v1` in `mobile/assets/env/owanbe_config.admin`. Tunnel Admin uses `owanbe_config.admin.tunnel.example` (`https://admin-dev.owanbe.com/v1`).

Do **not** leave tunnel API URLs in the default env assets. That breaks localhost Customer/Admin when the tunnel is down.

## Architecture

| Host | Local target | App |
|------|--------------|-----|
| `https://dev.owanbe.com` | `localhost:3000` | Customer (`lib/main.dart`) |
| `https://dev.owanbe.com/v1/*` | `127.0.0.1:8080` | Nest API |
| `https://admin-dev.owanbe.com` | `localhost:59158` | Admin (`lib/main_admin.dart`) |
| `https://admin-dev.owanbe.com/v1/*` | `127.0.0.1:8080` | Nest API |

Invitation emails (Customer): `PUBLIC_APP_BASE_URL=https://dev.owanbe.com`

## Prerequisites

1. Cloudflare account with **DNS edit** permission on the `owanbe.com` zone.
2. `cloudflared` installed (already on this machine).
3. Tunnel `owanbe-dev` created (credentials in `%USERPROFILE%\.cloudflared\` — never commit).

## One-time setup

### 1. Tunnel (done if `cloudflared tunnel list` shows `owanbe-dev`)

```powershell
cloudflared tunnel create owanbe-dev
```

Copy `infra/dev/cloudflared-owanbe-dev.yml.example` to `%USERPROFILE%\.cloudflared\owanbe-dev.yml` and set `credentials-file` to the generated JSON path.

### 2. DNS — **required before public URLs work**

CLI (needs zone permission):

```powershell
cloudflared tunnel route dns owanbe-dev dev.owanbe.com
cloudflared tunnel route dns owanbe-dev admin-dev.owanbe.com
```

**Or** manual CNAME in Cloudflare DNS (both hostnames):

```
dev.owanbe.com       CNAME  <TUNNEL_ID>.cfargotunnel.com
admin-dev.owanbe.com CNAME  <TUNNEL_ID>.cfargotunnel.com
```

Tunnel ID: run `cloudflared tunnel list` and use the `owanbe-dev` UUID.

If CLI returns `Authentication error (10000)`, the local Cloudflare cert is tied to another zone (e.g. `iips.com`). Log in with an account that owns `owanbe.com`, or add CNAME records manually in the dashboard.

### 3. API env (local `services/api/.env`)

```
PUBLIC_APP_BASE_URL=https://dev.owanbe.com
```

Restart API after changing.

### 4. Flutter env — opt in (do not leave this as the default)

Default `owanbe_config` / `owanbe_config.admin` stay on the local API (`http://127.0.0.1:8080/v1`) so `flutter run` works without the tunnel.

When the tunnel + DNS are actually running, copy the API base from the tunnel examples into the runtime assets, then hot restart Flutter:

- Customer: `mobile/assets/env/owanbe_config.tunnel.example` → set `OWANBE_API_BASE=https://dev.owanbe.com/v1` in `owanbe_config`
- Admin: `mobile/assets/env/owanbe_config.admin.tunnel.example` → set `OWANBE_API_BASE=https://admin-dev.owanbe.com/v1` in `owanbe_config.admin`

When you are done with tunnel testing, restore:

```
OWANBE_API_BASE=http://127.0.0.1:8080/v1
```

## Daily workflow

```powershell
# Terminal 1 — API
cd services/api
npm run start:dev

# Terminal 2 — Customer Flutter
powershell -File scripts/dev-flutter-web.ps1

# Terminal 3 — Admin Flutter
powershell -File scripts/dev-flutter-admin.ps1

# Terminal 4 — Tunnel
powershell -File scripts/dev-tunnel.ps1
```

## Verification

- `http://localhost:3000` — Customer UI
- `http://localhost:59158` — Admin UI
- `http://127.0.0.1:8080/health` — API (local only)
- `https://dev.owanbe.com` — Customer via tunnel (after DNS)
- `https://admin-dev.owanbe.com` — Admin via tunnel (after DNS)
- `https://dev.owanbe.com/v1/health` — API via tunnel path (after DNS + API running)

Re-send invitations after `PUBLIC_APP_BASE_URL` is set; old emails keep old URLs.

## CORS

With `NODE_ENV=development`, the API allows all origins (`origin: true`). No change needed for tunnel hostnames.

## Security

Development only. Tunnel exposes Flutter dev servers and `/v1` API. Do not expose Postgres or other Docker ports.
