import { Controller, Get, Inject, Param, Post, UseGuards, forwardRef } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { CommerceAuthGuard } from '../commerce/commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from '../commerce/commerce-auth.service';
import { OrganizerFinanceService } from '../commerce/organizer-finance.service';
import { QuasarOnboardingService } from './quasar-onboarding.service';
import { redactQuasarSecrets } from './quasar.policy';

@Controller()
@Public()
@UseGuards(CommerceAuthGuard)
export class QuasarOnboardingController {
  constructor(
    private readonly onboarding: QuasarOnboardingService,
    @Inject(forwardRef(() => OrganizerFinanceService))
    private readonly finance: OrganizerFinanceService,
  ) {}

  @Throttle({ strict: { limit: 20, ttl: 60_000 } })
  @Post('organizers/:organizerId/quasar/account')
  async activate(
    @Param('organizerId') organizerId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    await this.finance.assertOrganizerAccess(actor!, organizerId);
    return redactQuasarSecrets(await this.onboarding.activateOrganizer(actor!.tenantId, organizerId));
  }

  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Get('organizers/:organizerId/quasar/account')
  async status(
    @Param('organizerId') organizerId: string,
    @CommerceActorParam() actor: CommerceActor,
  ) {
    await this.finance.assertOrganizerAccess(actor!, organizerId);
    const account = await this.onboarding.describeOrganizer(actor!.tenantId, organizerId);
    if (!account) {
      return { onboarded: false, environment: 'test' as const };
    }
    return redactQuasarSecrets({ onboarded: true, ...account });
  }
}
