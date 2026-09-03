import {
  buildInvitationEmailHtml,
  buildInvitationEmailSubject,
  extractInvitationEventFields,
  resolvePublicEmailImageUrl,
} from '../src/modules/events/invitation-email.builder';

describe('invitation-email.builder', () => {
  const basePayload = {
    guestName: 'Ada',
    eventTitle: 'IKENNA',
    eventType: 'Birthday Celebration',
    organizerName: 'Horizon Events',
    startsAt: new Date('2026-08-22T16:00:00+01:00'),
    venueName: 'Eko Hotel',
    venueLocation: 'Lagos, Nigeria',
    description: 'Join us for an unforgettable celebration.',
    expectedAttendees: 120,
    imageUrl: 'https://cdn.example.com/events/cover.jpg',
    templateId: 'classic-gold',
    acceptUrl: 'https://app.example.com/events/evt-1/rsvp?token=abc&action=accept',
    declineUrl: 'https://app.example.com/events/evt-1/rsvp?token=abc&action=decline',
    rsvpUrl: 'https://app.example.com/events/evt-1/rsvp?token=abc',
  };

  it('builds subject with event name', () => {
    expect(buildInvitationEmailSubject('IKENNA')).toBe("You're invited to IKENNA");
  });

  it('renders branded HTML with CTAs, details, and hero image', () => {
    const html = buildInvitationEmailHtml(basePayload);
    expect(html).toContain("You're Invited");
    expect(html).toContain('IKENNA');
    expect(html).toContain('Birthday Celebration');
    expect(html).toContain('Horizon Events');
    expect(html).toContain('Lagos, Nigeria');
    expect(html).toContain('Eko Hotel');
    expect(html).toContain('cdn.example.com/events/cover.jpg');
    expect(html).toContain('ACCEPT INVITATION');
    expect(html).toContain('Decline');
    expect(html).toContain('token=abc&amp;action=accept');
    expect(html).toContain('token=abc&amp;action=decline');
    expect(html).toContain('You do not need an Owanbe account to RSVP');
    expect(html).not.toContain('localhost');
  });

  it('omits optional sections cleanly and uses branded placeholder without image', () => {
    const html = buildInvitationEmailHtml({
      ...basePayload,
      organizerName: null,
      description: null,
      venueName: null,
      venueLocation: 'Lagos',
      expectedAttendees: null,
      imageUrl: null,
      eventType: null,
    });
    expect(html).toContain('OWANBE');
    expect(html).toContain('Lagos');
    expect(html).not.toContain('Hosted by');
    expect(html).not.toContain('<img');
  });

  it('rejects private/local image hosts and resolves public relative media', () => {
    expect(resolvePublicEmailImageUrl('http://localhost:8080/v1/media/x', 'https://api.example.com')).toBeNull();
    expect(resolvePublicEmailImageUrl('https://127.0.0.1/img.jpg', null)).toBeNull();
    expect(resolvePublicEmailImageUrl('https://cdn.example.com/a.jpg', null)).toBe(
      'https://cdn.example.com/a.jpg',
    );
    expect(resolvePublicEmailImageUrl('/v1/media/abc', 'http://localhost:8080')).toBeNull();
    expect(resolvePublicEmailImageUrl('/v1/media/abc', 'https://api.example.com')).toBe(
      'https://api.example.com/v1/media/abc',
    );
  });

  it('extracts event fields from metadata without inventing values', () => {
    const fields = extractInvitationEventFields({
      celebrantImageUrl: 'https://cdn.example.com/c.jpg',
      description: 'Hello',
      category: 'Wedding',
      venueName: 'Hall',
      city: 'Abuja',
      expectedGuests: 50,
    });
    expect(fields.imageRaw).toBe('https://cdn.example.com/c.jpg');
    expect(fields.description).toBe('Hello');
    expect(fields.eventType).toBe('Wedding');
    expect(fields.venueName).toBe('Hall');
    expect(fields.venueLocation).toContain('Abuja');
    expect(fields.expectedAttendees).toBe(50);
    expect(extractInvitationEventFields({})).toEqual({
      imageRaw: null,
      description: null,
      eventType: null,
      venueName: null,
      venueLocation: null,
      expectedAttendees: null,
    });
  });
});
