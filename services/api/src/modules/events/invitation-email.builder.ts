/**
 * Phase 15 invitation email HTML — branded invitation (not a system notification).
 * Uses existing RSVP deep-link URLs; does not change token/RSVP architecture.
 */

export type InvitationEmailTheme = {
  headerBg: string;
  accent: string;
  accentText: string;
  cardBorder: string;
  acceptBg: string;
  acceptText: string;
  declineBorder: string;
  declineText: string;
  eyebrow: string;
};

/** Light mapping from Invitation Hub template_id → email accents (no template engine). */
const TEMPLATE_THEMES: Record<string, InvitationEmailTheme> = {
  'classic-gold': {
    headerBg: '#4B2C6F',
    accent: '#D4A853',
    accentText: '#1A1028',
    cardBorder: '#E8D5B5',
    acceptBg: '#D4A853',
    acceptText: '#1A1028',
    declineBorder: '#4B2C6F',
    declineText: '#4B2C6F',
    eyebrow: '#D4A853',
  },
  'ivory-lace': {
    headerBg: '#4B2C6F',
    accent: '#4B2C6F',
    accentText: '#FFFFFF',
    cardBorder: '#E8D5B5',
    acceptBg: '#4B2C6F',
    acceptText: '#FFFFFF',
    declineBorder: '#8B7355',
    declineText: '#4B2C6F',
    eyebrow: '#8B7355',
  },
  'sunset-owanbe': {
    headerBg: '#7C2D12',
    accent: '#DC2626',
    accentText: '#FFFFFF',
    cardBorder: '#FDBA74',
    acceptBg: '#DC2626',
    acceptText: '#FFFFFF',
    declineBorder: '#7C2D12',
    declineText: '#7C2D12',
    eyebrow: '#EA580C',
  },
  'emerald-gala': {
    headerBg: '#064E3B',
    accent: '#10B981',
    accentText: '#042F2E',
    cardBorder: '#6EE7B7',
    acceptBg: '#059669',
    acceptText: '#FFFFFF',
    declineBorder: '#064E3B',
    declineText: '#064E3B',
    eyebrow: '#10B981',
  },
  'royal-purple': {
    headerBg: '#3B0764',
    accent: '#C084FC',
    accentText: '#1E0533',
    cardBorder: '#A78BFA',
    acceptBg: '#7C3AED',
    acceptText: '#FFFFFF',
    declineBorder: '#3B0764',
    declineText: '#3B0764',
    eyebrow: '#C084FC',
  },
  'blush-garden': {
    headerBg: '#831843',
    accent: '#F472B6',
    accentText: '#1F0A14',
    cardBorder: '#FBCFE8',
    acceptBg: '#DB2777',
    acceptText: '#FFFFFF',
    declineBorder: '#831843',
    declineText: '#831843',
    eyebrow: '#F472B6',
  },
  'midnight-elegance': {
    headerBg: '#0F172A',
    accent: '#D4A853',
    accentText: '#0F172A',
    cardBorder: '#334155',
    acceptBg: '#D4A853',
    acceptText: '#0F172A',
    declineBorder: '#94A3B8',
    declineText: '#0F172A',
    eyebrow: '#D4A853',
  },
  'coastal-breeze': {
    headerBg: '#0C4A6E',
    accent: '#38BDF8',
    accentText: '#0C4A6E',
    cardBorder: '#BAE6FD',
    acceptBg: '#0284C7',
    acceptText: '#FFFFFF',
    declineBorder: '#0C4A6E',
    declineText: '#0C4A6E',
    eyebrow: '#38BDF8',
  },
};

const DEFAULT_THEME: InvitationEmailTheme = TEMPLATE_THEMES['classic-gold']!;

export function themeForTemplateId(templateId: string | null | undefined): InvitationEmailTheme {
  const key = (templateId ?? '').trim().toLowerCase();
  if (key && TEMPLATE_THEMES[key]) return TEMPLATE_THEMES[key]!;
  return DEFAULT_THEME;
}

export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

const PRIVATE_HOSTS = new Set(['localhost', '127.0.0.1', '0.0.0.0', '::1']);

/**
 * Only recipient-reachable http(s) URLs. Rejects localhost / private hosts.
 * Relative paths (e.g. /v1/media/...) resolve against a public API base when safe.
 */
export function resolvePublicEmailImageUrl(
  raw: string | null | undefined,
  publicApiBaseUrl: string | null | undefined,
): string | null {
  const value = (raw ?? '').trim();
  if (!value) return null;

  if (/^https?:\/\//i.test(value)) {
    try {
      const u = new URL(value);
      if (PRIVATE_HOSTS.has(u.hostname.toLowerCase())) return null;
      if (u.protocol !== 'http:' && u.protocol !== 'https:') return null;
      return value;
    } catch {
      return null;
    }
  }

  if (value.startsWith('/') && publicApiBaseUrl) {
    const base = publicApiBaseUrl.trim().replace(/\/$/, '');
    if (!base) return null;
    try {
      const u = new URL(base);
      if (PRIVATE_HOSTS.has(u.hostname.toLowerCase())) return null;
      return `${base}${value}`;
    } catch {
      return null;
    }
  }

  return null;
}

function formatEventWhen(startsAt: string | Date | null | undefined): { dateLine: string | null; timeLine: string | null } {
  if (!startsAt) return { dateLine: null, timeLine: null };
  const d = startsAt instanceof Date ? startsAt : new Date(startsAt);
  if (Number.isNaN(d.getTime())) return { dateLine: null, timeLine: null };
  const dateLine = new Intl.DateTimeFormat('en-GB', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }).format(d);
  const timeLine = new Intl.DateTimeFormat('en-GB', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  }).format(d);
  return { dateLine, timeLine };
}

function pickMetaString(meta: Record<string, unknown>, keys: string[]): string | null {
  for (const key of keys) {
    const v = meta[key];
    if (typeof v === 'string' && v.trim()) return v.trim();
  }
  return null;
}

function pickMetaNumber(meta: Record<string, unknown>, keys: string[]): number | null {
  for (const key of keys) {
    const v = meta[key];
    if (typeof v === 'number' && Number.isFinite(v) && v > 0) return Math.floor(v);
    if (typeof v === 'string' && /^\d+$/.test(v.trim())) {
      const n = Number(v.trim());
      if (n > 0) return n;
    }
  }
  return null;
}

export type InvitationEmailPayload = {
  guestName: string | null;
  eventTitle: string;
  eventType: string | null;
  organizerName: string | null;
  startsAt: string | Date | null;
  venueName: string | null;
  venueLocation: string | null;
  description: string | null;
  expectedAttendees: number | null;
  imageUrl: string | null;
  templateId: string | null;
  acceptUrl: string;
  declineUrl: string;
  rsvpUrl: string;
};

export function buildInvitationEmailSubject(eventTitle: string): string {
  const title = eventTitle.trim() || 'an event';
  return `You're invited to ${title}`;
}

export function buildInvitationEmailText(payload: InvitationEmailPayload): string {
  const name = (payload.guestName ?? '').trim() || 'there';
  const lines = [
    `Hi ${name},`,
    '',
    `You're invited to ${payload.eventTitle}.`,
    '',
  ];
  const { dateLine, timeLine } = formatEventWhen(payload.startsAt);
  if (dateLine) lines.push(`Date: ${dateLine}`);
  if (timeLine) lines.push(`Time: ${timeLine}`);
  if (payload.venueName) lines.push(`Venue: ${payload.venueName}`);
  if (payload.venueLocation) lines.push(`Location: ${payload.venueLocation}`);
  if (payload.organizerName) lines.push(`Hosted by: ${payload.organizerName}`);
  if (payload.description) {
    lines.push('', payload.description);
  }
  lines.push(
    '',
    `Accept invitation: ${payload.acceptUrl}`,
    `Decline: ${payload.declineUrl}`,
    '',
    'You do not need an Owanbe account to RSVP.',
    '',
    `Or open: ${payload.rsvpUrl}`,
  );
  return lines.join('\n');
}

export function buildInvitationEmailHtml(payload: InvitationEmailPayload): string {
  const theme = themeForTemplateId(payload.templateId);
  const name = escapeHtml((payload.guestName ?? '').trim() || 'there');
  const title = escapeHtml(payload.eventTitle.trim() || 'Event');
  const { dateLine, timeLine } = formatEventWhen(payload.startsAt);

  const rows: string[] = [];
  if (dateLine) {
    rows.push(detailRow('Date', dateLine));
  }
  if (timeLine) {
    rows.push(detailRow('Time', timeLine));
  }
  if (payload.venueName) {
    rows.push(detailRow('Venue', payload.venueName));
  }
  if (payload.venueLocation) {
    rows.push(detailRow('Location', payload.venueLocation));
  }
  if (payload.eventType) {
    rows.push(detailRow('Event type', payload.eventType));
  }
  if (payload.expectedAttendees != null && payload.expectedAttendees > 0) {
    rows.push(detailRow('Expected guests', String(payload.expectedAttendees)));
  }

  const organizerBlock = payload.organizerName
    ? `<p style="margin:20px 0 0;font-size:14px;line-height:1.5;color:#5B4A6E;">
        <span style="display:block;font-size:11px;letter-spacing:0.08em;text-transform:uppercase;color:${theme.eyebrow};font-weight:700;">Hosted by</span>
        <span style="font-size:16px;color:#1A1028;font-weight:600;">${escapeHtml(payload.organizerName)}</span>
      </p>`
    : '';

  const descriptionBlock = payload.description
    ? `<p style="margin:20px 0 0;font-size:15px;line-height:1.6;color:#3F3351;">${escapeHtml(payload.description)}</p>`
    : '';

  const hero = payload.imageUrl
    ? `<tr>
        <td style="padding:0;line-height:0;font-size:0;">
          <img src="${escapeHtml(payload.imageUrl)}" alt="${title}" width="600" style="display:block;width:100%;max-width:600px;height:auto;border:0;outline:none;" />
        </td>
      </tr>`
    : `<tr>
        <td style="padding:36px 24px;background:${theme.headerBg};text-align:center;">
          <p style="margin:0;font-family:Georgia,'Times New Roman',serif;font-size:28px;letter-spacing:0.12em;color:${theme.accent};font-weight:700;">OWANBE</p>
          <p style="margin:8px 0 0;font-size:12px;letter-spacing:0.2em;text-transform:uppercase;color:#F8F7FC;opacity:0.85;">Celebration Platform</p>
        </td>
      </tr>`;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="color-scheme" content="light" />
  <title>${title}</title>
</head>
<body style="margin:0;padding:0;background:#F3EEF8;-webkit-text-size-adjust:100%;">
  <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#F3EEF8;">
    <tr>
      <td align="center" style="padding:24px 12px;">
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="600" style="width:100%;max-width:600px;background:#FFFFFF;border:1px solid ${theme.cardBorder};border-radius:12px;overflow:hidden;">
          ${hero}
          <tr>
            <td style="padding:28px 28px 8px;text-align:center;">
              <p style="margin:0;font-size:12px;letter-spacing:0.22em;text-transform:uppercase;color:${theme.eyebrow};font-weight:700;">You're Invited</p>
              <h1 style="margin:12px 0 0;font-family:Georgia,'Times New Roman',serif;font-size:28px;line-height:1.25;color:#1A1028;font-weight:700;">${title}</h1>
              ${
                payload.eventType
                  ? `<p style="margin:10px 0 0;font-size:15px;color:#5B4A6E;">${escapeHtml(payload.eventType)}</p>`
                  : ''
              }
              <p style="margin:16px 0 0;font-size:15px;color:#3F3351;">Hi ${name},</p>
            </td>
          </tr>
          <tr>
            <td style="padding:8px 28px 0;">
              <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#FAF7FC;border-radius:8px;">
                <tr>
                  <td style="padding:16px 18px;">
                    ${rows.length ? rows.join('') : `<p style="margin:0;font-size:14px;color:#5B4A6E;">Join us for this celebration.</p>`}
                    ${organizerBlock}
                    ${descriptionBlock}
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:28px 28px 12px;text-align:center;">
              <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center" style="margin:0 auto;">
                <tr>
                  <td align="center" bgcolor="${theme.acceptBg}" style="border-radius:8px;background:${theme.acceptBg};">
                    <a href="${escapeHtml(payload.acceptUrl)}" style="display:inline-block;padding:14px 28px;font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:700;letter-spacing:0.04em;text-decoration:none;color:${theme.acceptText};border-radius:8px;">ACCEPT INVITATION</a>
                  </td>
                </tr>
              </table>
              <p style="margin:16px 0 0;">
                <a href="${escapeHtml(payload.declineUrl)}" style="font-family:Arial,Helvetica,sans-serif;font-size:14px;font-weight:600;color:${theme.declineText};text-decoration:underline;">Decline</a>
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding:8px 28px 28px;text-align:center;">
              <p style="margin:0;font-size:13px;line-height:1.5;color:#6B5B7A;">You do not need an Owanbe account to RSVP.</p>
              <p style="margin:12px 0 0;font-size:11px;line-height:1.4;color:#9A8BA8;">
                Having trouble with the buttons?
                <a href="${escapeHtml(payload.rsvpUrl)}" style="color:#6B5B7A;">Open your invitation</a>
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding:14px 28px;background:${theme.headerBg};text-align:center;">
              <p style="margin:0;font-size:11px;letter-spacing:0.16em;text-transform:uppercase;color:${theme.accent};">Owanbe</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

function detailRow(label: string, value: string): string {
  return `<p style="margin:0 0 12px;font-size:14px;line-height:1.45;color:#3F3351;">
    <span style="display:block;font-size:11px;letter-spacing:0.08em;text-transform:uppercase;color:#8B7A9C;font-weight:700;">${escapeHtml(label)}</span>
    <span style="font-size:15px;color:#1A1028;font-weight:600;">${escapeHtml(value)}</span>
  </p>`;
}

export function extractInvitationEventFields(meta: Record<string, unknown> | null | undefined): {
  imageRaw: string | null;
  description: string | null;
  eventType: string | null;
  venueName: string | null;
  venueLocation: string | null;
  expectedAttendees: number | null;
} {
  const m = meta && typeof meta === 'object' ? meta : {};
  const venueName = pickMetaString(m, ['venueName', 'venue', 'locationName']);
  const address = pickMetaString(m, ['venueAddress', 'address']);
  const city = pickMetaString(m, ['city', 'location', 'locationCity']);
  let venueLocation: string | null = null;
  if (address && city && address.toLowerCase() !== city.toLowerCase()) {
    venueLocation = `${address}, ${city}`;
  } else {
    venueLocation = address || city;
  }
  // Avoid duplicating venue name in location line
  if (venueName && venueLocation && venueLocation.toLowerCase() === venueName.toLowerCase()) {
    venueLocation = address && address.toLowerCase() !== venueName.toLowerCase() ? address : city;
    if (venueLocation && venueLocation.toLowerCase() === venueName.toLowerCase()) {
      venueLocation = null;
    }
  }

  return {
    imageRaw: pickMetaString(m, ['celebrantImageUrl', 'coverImageUrl', 'heroImageUrl', 'imageUrl']),
    description: pickMetaString(m, ['description', 'summary', 'about']),
    eventType: pickMetaString(m, ['category', 'eventType', 'type', 'celebrationType']),
    venueName,
    venueLocation,
    expectedAttendees: pickMetaNumber(m, ['expectedGuests', 'expectedAttendees', 'guestCount']),
  };
}
