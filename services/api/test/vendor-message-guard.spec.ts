import {
  detectPlatformBypass,
  PLATFORM_KEEP_IN_OWANBE,
} from '../src/modules/vendor-operations/vendor-message-guard';

describe('detectPlatformBypass', () => {
  it('allows operational discussion', () => {
    expect(detectPlatformBypass('Can you provide catering for 150 guests?').blocked).toBe(false);
    expect(detectPlatformBypass('Arrival at 2:00 PM with 4 staff').blocked).toBe(false);
  });

  it('blocks contact and payment bypass', () => {
    expect(detectPlatformBypass('WhatsApp me').blocked).toBe(true);
    expect(detectPlatformBypass('Call me on 08012345678').reason).toBe(PLATFORM_KEEP_IN_OWANBE);
    expect(detectPlatformBypass('Pay me directly').blocked).toBe(true);
    expect(detectPlatformBypass("Let's do this outside Owanbe").blocked).toBe(true);
  });
});
