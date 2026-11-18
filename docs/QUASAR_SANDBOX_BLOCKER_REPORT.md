# Quasar Sandbox Blocker Report

**Date:** 7 October 2026  
**Owanbe base:** local only. Production was not migrated and was not called.  
**Quasar process:** `http://127.0.0.1:4000/api/v1` (`quasar-api`, `NODE_ENV=production`)  
**Quasar database:** local `quasar_first_slice_staging` on `127.0.0.1:5435`  
**Owanbe database:** local `postgres://postgres@localhost:5436/owanbe`

## Status

| Gate | Result |
| --- | --- |
| `OWANBE_QUASAR_SANDBOX_RAIL` | `IMPLEMENTED_AND_LOCALLY_VALIDATED` |
| `QUASAR_SANDBOX_EXTERNAL_VALIDATION` | `BLOCKED` |

The Owanbe Quasar module is frozen. These three items are Quasar environment and API blockers. Full Quasar end-to-end completion stays open until `sk_test_*` is authorized on the real virtual-account and transfer routes, and `POST /webhooks/endpoints` succeeds through the documented API.

The local proof that already passed used `/sandbox/*` after the product routes returned 403, and it stored the webhook row directly after `POST /webhooks/endpoints` returned 400. That path validated the Owanbe ledger. It does not clear the external contract.

## Proof tenant used for the local pass

| Field | Value |
| --- | --- |
| Quasar tenant ID | `680ae04e-074e-4fbf-8e13-beaf7dd9fdb8` |
| Slug | `owanbe-live-f9b1bcbf` |
| Code | `OWA010` |
| Status | `active` |
| Vertical | `owanbe` |
| Tenant environment | API key `environment=test` |
| API key class | `sk_test_` (active, not revoked) |
| Client ID | `OWANBE` |
| Client auth | `X-Quasar-Client-Id` / `X-Quasar-Client-Secret` (`qpc_` class). Used only for tenant and API-key creation. |
| Money auth | `Authorization: Bearer` tenant API key, class `sk_test_` |

Issued key scopes, after the local test added sandbox scopes:

`payments:create`, `payments:read`, `wallets:read`, `transfers:create`, `transfers:read`, `virtual_accounts:read`, `virtual_accounts:write`, `webhooks:endpoints:manage`, `webhooks:read`, `integration:read`, `sandbox:read`, `sandbox:write`

The `OWANBE` partner default scopes do not include `sandbox:read` or `sandbox:write`. The product scopes `virtual_accounts:write`, `transfers:create`, and `webhooks:endpoints:manage` were already on the key when the 403 and 400 were returned. Those failures are not missing-scope denials.

Earlier local probes created additional `owanbe` tenants `OWA003`–`OWA009`. Every one of those keys is also `sk_test_` / `environment=test`. None is `sk_live_`.

For `vertical=owanbe` in this database: product `virtual_accounts` = 0, product `transfers` = 0, sandbox virtual accounts = 5, sandbox transfers = 6.

---

## 1. Test tenant money-route authorization

`PlatformEnvironmentGuard` treats a path that does not contain `/sandbox` as Quasar Financial Environment (production financial APIs). An `sk_test_*` key on that class is rejected before the handler runs.

Observed from the product client against the running process (`QuasarHttpError`, HTTP status copied from the response, message copied from `responseMessage`):

### `POST /school/students/{id}/virtual-account`

| Field | Value |
| --- | --- |
| Request path | `POST /api/v1/school/students/{payerId}/virtual-account` |
| Authentication | `Authorization: Bearer` tenant API key, class `sk_test_` |
| Extra headers | `Accept: application/json`, `Content-Type: application/json`, `Idempotency-Key` |
| Response status | **403** |
| Retryable | false |
| Response code | `03` (Quasar envelope mapping for HTTP 403 on non-webhook paths) |
| Response message | `Test API keys (sk_test_*) are restricted to Quasar Financial Sandbox (/sandbox/*). Use sk_live_* for production financial APIs.` |
| Required scope on the handler | `virtual_accounts:write` (present on the key) |
| Route class | QFE. `SchoolController` is not marked sandbox. |

Request body sent by the Owanbe client:

```json
{
  "currency": "NGN",
  "email": "payer-<id-prefix>@example.test",
  "firstName": "Ada",
  "lastName": "Balogun",
  "phone": "+2348012345678",
  "merchantWalletOwnerId": "<organizer-wallet-owner-uuid>",
  "metadata": {
    "ticketPaymentId": "<ticket-payment-uuid>",
    "payerId": "<attendee-uuid>",
    "tenantId": "<quasar-tenant-uuid>",
    "schoolId": "<organizer-wallet-owner-uuid>"
  }
}
```

One captured client error, with the key class redacted in the test log, was:

`Quasar /school/students/8d95d223-9840-4840-b35d-7761247e0a61/virtual-account failed: Test API keys ([redacted]*) are restricted to Quasar Financial Sandbox (/sandbox/*).`

HTTP status on that call was 403.

### `POST /transfers`

| Field | Value |
| --- | --- |
| Request path | `POST /api/v1/transfers` |
| Authentication | `Authorization: Bearer` tenant API key, class `sk_test_` |
| Extra headers | `Accept: application/json`, `Content-Type: application/json`, `Idempotency-Key` |
| Response status | **403** |
| Retryable | false |
| Response code | `03` |
| Response message | `Test API keys (sk_test_*) are restricted to Quasar Financial Sandbox (/sandbox/*). Use sk_live_* for production financial APIs.` |
| Required scope on the handler | `transfers:create` (present on the key) |
| Route class | QFE. `TransferController` is not marked sandbox. |

Observed client error:

`Quasar /transfers failed: Test API keys (sk_test_*) are restricted to Quasar Financial Sandbox (/sandbox/*). Use sk_live_* for production financial APIs.`

Product body the Owanbe withdrawal client sends (this is the contracted money route; the passing proof did not use it after the 403):

```json
{
  "amount": "<major decimal from minor units>",
  "currency": "NGN",
  "reference": "owanbe_payout_<payout-uuid>",
  "destination": {
    "account_number": "<10-digit account>",
    "bank_code": "<bank code>",
    "account_name": "<account name>"
  },
  "metadata": {
    "tenantId": "<quasar-tenant-uuid>",
    "schoolId": "<organizer-wallet-owner-uuid>"
  }
}
```

Envelope shape for both 403s, from `QuasarApiExceptionFilter` (these paths do not bypass the envelope):

```json
{
  "responseCode": "03",
  "responseMessage": "Test API keys (sk_test_*) are restricted to Quasar Financial Sandbox (/sandbox/*). Use sk_live_* for production financial APIs.",
  "data": { "request_id": "<correlation id when present>" }
}
```

### How `/sandbox/*` is authorized differently

`SandboxIntegrationController` is declared as Quasar Financial Sandbox (`PlatformRouteClass.QFS`) at `POST /api/v1/sandbox/...`. The same guard allows `environment=test` on QFS and blocks live keys there.

On this process, with the same `sk_test_` key after `sandbox:read` and `sandbox:write` were present:

| Call | Result |
| --- | --- |
| `POST /api/v1/sandbox/accounts/generate` | 201, bank `QUASAR TEST BANK` |
| `POST /api/v1/sandbox/accounts/:id/credit` | 201 |
| `POST /api/v1/sandbox/transfers` | 201, status `AWAITING_APPROVAL` |
| `POST /api/v1/sandbox/transfers/:id/approve` | 201, status `SUCCESS` |
| Duplicate `POST /api/v1/sandbox/transfers` | 409, `responseCode` `05` |

`/sandbox/*` is a different route class, a different scope set, and a different controller. It is not the contracted tenant money API. Owanbe still calls `POST /school/students/{id}/virtual-account` and `POST /transfers`.

---

## 2. Webhook endpoint API

The integration contract is `POST /webhooks/endpoints` with the tenant API key. The running image does not reach that handler.

`WebhookModule` is registered before `OutboundWebhookModule`. Both controllers use `@Controller('webhooks')`. `WebhookController` has `@Post(':provider')`, so `endpoints` is captured as a provider name and sent to inbound provider ingest.

### Request the Owanbe client sent

| Field | Value |
| --- | --- |
| Path | `POST /api/v1/webhooks/endpoints` |
| Authentication | `Authorization: Bearer` tenant API key, class `sk_test_` |
| Headers | `Accept: application/json`, `Content-Type: application/json`, `Idempotency-Key: live-webhook-<quasar-tenant-uuid>` |
| Body | `{ "url": "http://host.docker.internal:<ephemeral-port>/webhooks/quasar/<quasar-tenant-uuid>" }` |

### Exact response

| Field | Value |
| --- | --- |
| HTTP status | **400** |
| Retryable | false |
| Observed client error | `Quasar /webhooks/endpoints failed: Unsupported webhook provider: endpoints` |
| Validation failure | `BadRequestException`: `Unsupported webhook provider: endpoints` |
| Source | `WebhookService` inbound provider switch, provider param `endpoints` |

`/webhooks` bypasses the Quasar `responseCode` envelope. The body is the Nest exception payload:

```json
{
  "statusCode": 400,
  "message": "Unsupported webhook provider: endpoints",
  "error": "Bad Request"
}
```

The Owanbe client reads `message` on this path. There is no `responseCode`.

### What the documented handler requires, once the route is reachable

`InvifyWebhookEndpointsController.register` is `@Post('endpoints')` and requires scope `webhooks:endpoints:manage`. The proof key already had that scope. Tenant id comes from the bearer key (`@TenantId()`), not from the body.

| Check | Rule in source |
| --- | --- |
| Required body field | `url` |
| DTO | `@IsUrl({ require_protocol: true, protocols: ['https'] })`, `@MaxLength(2048)` |
| Service check | `assertOutboundWebhookUrl` |
| Success | 201 `{ url, signingSecret }` |

### HTTPS on this process

`NODE_ENV` on `quasar-api` is `production`.

- In production, `assertOutboundWebhookUrl` accepts only `https:`. It rejects `http:` with `Webhook URL must use https`.
- Local HTTP exceptions exist only when `NODE_ENV` is not production, and only for `localhost`, `127.0.0.1`, and `::1`.
- `host.docker.internal` is not an allowed product webhook host.
- The sandbox dispatcher uses a separate check, `assertSandboxWebhookUrl`, which does allow `host.docker.internal`.

The observed 400 happened before URL validation. After the route order is fixed, the proof URL `http://host.docker.internal:<port>/...` would still fail the documented product validator while this process stays in production mode.

Local calls also needed `x-forwarded-proto: https` to get past the platform HTTPS requirement on this `NODE_ENV=production` process. That header was added only in the local test HTTP wrapper for `127.0.0.1:4000` and `localhost:4000`. It is not part of the Owanbe product client.

### Why a row was inserted into `tenant_outbound_webhooks`

`POST /webhooks/endpoints` returned 400, so Quasar did not write an endpoint and did not return a signing secret. The sandbox dispatcher resolves a target from sandbox tenant config, then from the outbound cascade `tenant → vertical → service`. With no sandbox override URL, that cascade reads `tenant_outbound_webhooks`.

The local test inserted `tenant_id`, `url`, and `signing_secret` for the proof tenant so the dispatcher could sign `virtual_account.funded` and `transfer.success` and POST them to the listener. Seven `owanbe` rows exist. Each URL host is `host.docker.internal` with an ephemeral port. Each signing secret is present and is not recorded here.

That insert was a test workaround. It is not the Owanbe integration. The product client still calls `POST /webhooks/endpoints` and stores the signing secret only when that API returns one.

---

## 3. Sandbox credential hygiene

| Check | Result |
| --- | --- |
| Owanbe money calls use `sk_test_*` only | Yes. Key creation sends `environment: "test"`. Boot rejects `QUASAR_ENVIRONMENT` other than `test`, and rejects `QUASAR_LIVE_ENABLED=true`. |
| An `sk_live_*` key was used | No. The live proof recorded `apiKeyClass=sk_test` and aborted if the returned key was not `sk_test_`. |
| A live-money request was made | No. Owanbe `owanbe` tenants have 0 product virtual accounts and 0 product transfers. Funding and payout proof used `/sandbox/*` only. |
| Plaintext secrets in git | No. `qpc_`, `sk_test_`, and webhook signing secrets are not committed. The temporary client file was deleted after the run. |
| Owanbe logs contain secrets | No. The HTTP client logs path and status only. Audit rows, stored webhook payloads, API key hints, and payout metadata from the Postgres proof did not contain `sk_test_*`, `sk_live_*`, `qps_*`, `qpc_*`, or `webhookSigningSecret`. |

### `sk_live_*` already in the local Quasar database

This local database currently has active, unrevoked live keys:

| Vertical | Active `sk_live_` keys | Active `sk_test_` keys |
| --- | ---: | ---: |
| `invify_retail` | 22 | 14 |
| `invify_school` | 2 | 0 |
| `owanbe` | 0 | 8 |

Total active unrevoked `sk_live_` keys: **24**. None is attached to an `owanbe` tenant. None was used by Owanbe.

Quasar Ops should revoke these live keys from `quasar_first_slice_staging`. This database is the local sandbox behind `127.0.0.1:4000`, and the process is running with `NODE_ENV=production`, which is what makes `sk_test_*` fail closed on the product money routes. Leaving active `sk_live_*` rows in that database is a sandbox hygiene defect.

### `OWANBE` partner credential

| Field | Value |
| --- | --- |
| Client ID | `OWANBE` |
| Name | `Owanbe Platform (service general key)` |
| Active | yes |
| Revoked | no |
| Secret class | `qpc_` |
| Stored secret | hash present (60 characters). Plaintext is not stored and is not in this report. |
| Prefix length | 12 |
| Service ID | `06897983-dd0a-47e5-a7e8-aa1923d12a08` |
| Capabilities | `tenant:provision`, `tenant:read`, `api_key:create` |
| Allowed verticals | `owanbe` |
| Default tenant API key scopes | `payments:create`, `payments:read`, `wallets:read`, `transfers:create`, `transfers:read`, `virtual_accounts:read`, `virtual_accounts:write`, `webhooks:endpoints:manage`, `webhooks:read`, `integration:read` |

The plaintext `qpc_` secret was issued into the local Quasar database for this sandbox proof, written to a temp file, and removed from that file after the run. It is not in git. The hash remains in `platform_partner_clients` on `quasar_first_slice_staging`. Rotating or revoking that local partner is a Quasar Ops choice; Owanbe does not keep the plaintext.

---

## What remains blocked

`QUASAR_SANDBOX_EXTERNAL_VALIDATION` stays `BLOCKED` until both of these are true on the Quasar sandbox Owanbe is aimed at:

1. An `sk_test_*` tenant key is authorized for `POST /school/students/{id}/virtual-account` and `POST /transfers`.
2. `POST /webhooks/endpoints` registers the outbound URL through that API and returns the signing secret.

Owanbe will not switch its integration to `/sandbox/*` or to direct inserts into `tenant_outbound_webhooks`. Production remains untouched.
