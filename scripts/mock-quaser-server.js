#!/usr/bin/env node
/**
 * Minimal Quaser router mock for Phase 9 gate — accepts payment initiate and fires signed webhooks.
 * Usage: node scripts/mock-quaser-server.js
 */
const http = require('http');
const crypto = require('crypto');

const PORT = parseInt(process.env.MOCK_QUASER_PORT || '9090', 10);
const WEBHOOK_SECRET = process.env.QUASER_WEBHOOK_SECRET || 'phase9-test-webhook-secret';

function sign(body) {
  return crypto.createHmac('sha256', WEBHOOK_SECRET).update(body).digest('hex');
}

async function fireWebhook(webhookUrl, payload) {
  const body = JSON.stringify(payload);
  const sig = sign(Buffer.from(body));
  try {
    await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-quaser-signature': sig,
      },
      body,
    });
  } catch (e) {
    console.error('Webhook delivery failed:', e.message);
  }
}

const server = http.createServer(async (req, res) => {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const raw = Buffer.concat(chunks);
  let json = {};
  try {
    json = raw.length ? JSON.parse(raw.toString()) : {};
  } catch {
    /* ignore */
  }

  if (req.method === 'POST' && req.url === '/v1/payments') {
    const paymentId = json.payment_id;
    const ref = `QSR-MOCK-${String(paymentId).slice(0, 8)}`;
    const webhookUrl = json.webhook_url;
    const amountMinor = json.amount_minor;
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ quaser_reference: ref, reference: ref, status: 'initiated' }));
    if (webhookUrl && paymentId) {
      setTimeout(() => {
        void fireWebhook(webhookUrl, {
          event_type: 'payment.captured',
          payment_id: paymentId,
          amount_minor: String(amountMinor),
          currency: json.currency || 'NGN',
          quaser_reference: ref,
        });
      }, 300);
    }
    return;
  }

  if (req.method === 'POST' && req.url?.startsWith('/v1/payments/') && req.url.endsWith('/verify')) {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, verified: true, status: 'captured' }));
    return;
  }

  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', service: 'mock-quaser' }));
    return;
  }

  res.writeHead(404);
  res.end('not found');
});

server.listen(PORT, () => {
  console.log(JSON.stringify({ ok: true, mockQuaserPort: PORT }, null, 2));
});
