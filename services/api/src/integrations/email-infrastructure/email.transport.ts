import { Logger } from '@nestjs/common';
import * as nodemailer from 'nodemailer';
import type { Transporter } from 'nodemailer';
import type {
  EmailEncryptionMode,
  EmailProviderRow,
  EmailProviderType,
  SendEmailCommand,
  SendEmailResult,
} from './email.types';
import { API_KEY_PROVIDERS, SMTP_STYLE_PROVIDERS } from './email.types';

export interface ResolvedCredentials {
  password?: string;
  apiKey?: string;
}

export async function deliverViaProvider(
  provider: EmailProviderRow,
  creds: ResolvedCredentials,
  command: SendEmailCommand,
): Promise<SendEmailResult> {
  const logger = new Logger('EmailTransport');

  if (SMTP_STYLE_PROVIDERS.includes(provider.provider_type) || provider.provider_type === 'custom_smtp') {
    return sendSmtp(provider, creds, command, logger);
  }

  if (API_KEY_PROVIDERS.includes(provider.provider_type)) {
    return sendApiProvider(provider, creds, command, logger);
  }

  return { ok: false, reason: `Unsupported provider type: ${provider.provider_type}` };
}

export async function verifyProviderConnection(
  provider: EmailProviderRow,
  creds: ResolvedCredentials,
): Promise<{ ok: boolean; reason?: string }> {
  if (SMTP_STYLE_PROVIDERS.includes(provider.provider_type) || provider.provider_type === 'custom_smtp') {
    const transport = buildSmtpTransport(provider, creds);
    try {
      await transport.verify();
      return { ok: true };
    } catch (e) {
      return { ok: false, reason: e instanceof Error ? e.message : 'smtp_verify_failed' };
    } finally {
      transport.close();
    }
  }

  if (provider.provider_type === 'resend') {
    if (!creds.apiKey) return { ok: false, reason: 'api_key_required' };
    const res = await fetch('https://api.resend.com/domains', {
      headers: { Authorization: `Bearer ${creds.apiKey}` },
    });
    if (res.ok || res.status === 200) return { ok: true };
    // 401/403 = bad key; other codes may still mean reachable
    if (res.status === 401 || res.status === 403) {
      return { ok: false, reason: `Resend auth failed HTTP ${res.status}` };
    }
    return { ok: true };
  }

  if (provider.provider_type === 'sendgrid') {
    if (!creds.apiKey) return { ok: false, reason: 'api_key_required' };
    const res = await fetch('https://api.sendgrid.com/v3/user/account', {
      headers: { Authorization: `Bearer ${creds.apiKey}` },
    });
    if (res.ok) return { ok: true };
    return { ok: false, reason: `SendGrid HTTP ${res.status}` };
  }

  // Mailgun / Postmark / others: credential presence check
  if (!creds.apiKey) return { ok: false, reason: 'api_key_required' };
  return { ok: true, reason: 'credentials_present' };
}

function buildSmtpTransport(provider: EmailProviderRow, creds: ResolvedCredentials): Transporter {
  const host = provider.smtp_host;
  if (!host) throw new Error('smtp_host_required');
  const port = provider.smtp_port ?? 587;
  const mode: EmailEncryptionMode = provider.encryption_mode ?? 'starttls';

  return nodemailer.createTransport({
    host,
    port,
    secure: mode === 'ssl',
    requireTLS: mode === 'starttls',
    connectionTimeout: provider.connection_timeout_ms,
    auth:
      provider.username && creds.password
        ? { user: provider.username, pass: creds.password }
        : undefined,
  });
}

async function sendSmtp(
  provider: EmailProviderRow,
  creds: ResolvedCredentials,
  command: SendEmailCommand,
  logger: Logger,
): Promise<SendEmailResult> {
  const transport = buildSmtpTransport(provider, creds);
  try {
    const from = formatFrom(provider.sender_name, provider.sender_email);
    const info = await transport.sendMail({
      from,
      to: command.to,
      subject: command.subject,
      html: command.html,
      text: command.text,
      replyTo: command.replyTo ?? provider.reply_to ?? undefined,
    });
    return {
      ok: true,
      providerId: provider.id,
      providerName: provider.name,
      providerType: provider.provider_type,
      externalId: info.messageId,
    };
  } catch (e) {
    const reason = e instanceof Error ? e.message : 'smtp_send_failed';
    logger.warn({ reason, provider: provider.name }, 'SMTP send failed');
    return { ok: false, reason, providerId: provider.id, providerName: provider.name };
  } finally {
    transport.close();
  }
}

async function sendApiProvider(
  provider: EmailProviderRow,
  creds: ResolvedCredentials,
  command: SendEmailCommand,
  logger: Logger,
): Promise<SendEmailResult> {
  const type: EmailProviderType = provider.provider_type;
  const from = formatFrom(provider.sender_name, provider.sender_email);
  const apiKey = creds.apiKey;
  if (!apiKey) return { ok: false, reason: 'api_key_required' };

  try {
    if (type === 'resend') {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          from,
          to: [command.to],
          subject: command.subject,
          html: command.html,
          reply_to: command.replyTo ?? provider.reply_to ?? undefined,
        }),
      });
      const raw = (await res.json().catch(() => ({}))) as { id?: string; message?: string };
      if (!res.ok) return { ok: false, reason: raw.message ?? `Resend HTTP ${res.status}` };
      return {
        ok: true,
        externalId: raw.id,
        providerId: provider.id,
        providerName: provider.name,
        providerType: type,
      };
    }

    if (type === 'sendgrid') {
      const res = await fetch('https://api.sendgrid.com/v3/mail/send', {
        method: 'POST',
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          personalizations: [{ to: [{ email: command.to }] }],
          from: { email: provider.sender_email, name: provider.sender_name },
          subject: command.subject,
          content: [{ type: 'text/html', value: command.html }],
          reply_to: command.replyTo || provider.reply_to
            ? { email: command.replyTo ?? provider.reply_to }
            : undefined,
        }),
      });
      if (!res.ok) {
        const text = await res.text().catch(() => '');
        return { ok: false, reason: text || `SendGrid HTTP ${res.status}` };
      }
      return {
        ok: true,
        externalId: res.headers.get('x-message-id') ?? 'sendgrid',
        providerId: provider.id,
        providerName: provider.name,
        providerType: type,
      };
    }

    if (type === 'postmark') {
      const res = await fetch('https://api.postmarkapp.com/email', {
        method: 'POST',
        headers: {
          'X-Postmark-Server-Token': apiKey,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({
          From: from,
          To: command.to,
          Subject: command.subject,
          HtmlBody: command.html,
          ReplyTo: command.replyTo ?? provider.reply_to ?? undefined,
        }),
      });
      const raw = (await res.json().catch(() => ({}))) as { MessageID?: string; Message?: string };
      if (!res.ok) return { ok: false, reason: raw.Message ?? `Postmark HTTP ${res.status}` };
      return {
        ok: true,
        externalId: raw.MessageID,
        providerId: provider.id,
        providerName: provider.name,
        providerType: type,
      };
    }

    if (type === 'mailgun') {
      const domain = (provider.metadata?.mailgunDomain as string) || provider.sender_email.split('@')[1];
      if (!domain) return { ok: false, reason: 'mailgun_domain_required_in_metadata' };
      const auth = Buffer.from(`api:${apiKey}`).toString('base64');
      const body = new URLSearchParams({
        from,
        to: command.to,
        subject: command.subject,
        html: command.html,
      });
      if (command.replyTo ?? provider.reply_to) {
        body.set('h:Reply-To', (command.replyTo ?? provider.reply_to)!);
      }
      const res = await fetch(`https://api.mailgun.net/v3/${domain}/messages`, {
        method: 'POST',
        headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/x-www-form-urlencoded' },
        body: body.toString(),
      });
      const raw = (await res.json().catch(() => ({}))) as { id?: string; message?: string };
      if (!res.ok) return { ok: false, reason: raw.message ?? `Mailgun HTTP ${res.status}` };
      return {
        ok: true,
        externalId: raw.id,
        providerId: provider.id,
        providerName: provider.name,
        providerType: type,
      };
    }

    return { ok: false, reason: `API provider not implemented: ${type}` };
  } catch (e) {
    const reason = e instanceof Error ? e.message : 'api_send_failed';
    logger.warn({ reason, type }, 'API email send failed');
    return { ok: false, reason };
  }
}

function formatFrom(name: string, email: string): string {
  const n = name?.trim();
  if (n) return `${n} <${email}>`;
  return email;
}
