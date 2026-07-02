import { VendorNegotiationsService } from '../src/modules/event-config/vendor-negotiations.service';
import type { Pool } from 'pg';
import type { EventsAccessService } from '../src/modules/events/events-access.service';

describe('AI Negotiation Engine Tests', () => {
  let service: VendorNegotiationsService;

  beforeEach(() => {
    service = new VendorNegotiationsService(
      {} as Pool,
      {} as EventsAccessService,
    );
  });

  it('should parse price proposals from message strings', () => {
    expect(service.parsePriceProposal('I can do 250k for this.')).toBe(25000000);
    expect(service.parsePriceProposal('How about ₦350,000?')).toBe(35000000);
    expect(service.parsePriceProposal('We agree on 150000?')).toBe(15000000);
    expect(service.parsePriceProposal('Let us settle for 4000')).toBe(400000);
  });

  it('should flag suspicious off-platform redirections and banking info (Fraud Detection)', () => {
    const f1 = service.scanForFraud('Send directly to my GTBank account');
    expect(f1.flagged).toBe(true);
    expect(f1.reason).toContain('Detected off-platform redirect request or custom banking terms');

    const f2 = service.scanForFraud('WhatsApp me on 08012345678');
    expect(f2.flagged).toBe(true);

    const f3 = service.scanForFraud('Can we discuss pricing changes tomorrow?');
    expect(f3.flagged).toBe(false);
  });

  it('should calculate correct agreement confidence score', () => {
    const s1 = service.calculateAgreementConfidence('Deal, let us proceed!', 42500000);
    expect(s1.confidence).toBe(98); // 50 (price) + 48 (deal keyword)
    expect(s1.reasons).toContain('Valid price proposal detected');
    expect(s1.reasons).toContain('Consensus confirmation phrase matched');
  });
});
