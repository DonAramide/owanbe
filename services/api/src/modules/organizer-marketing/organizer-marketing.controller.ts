import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators/public.decorator';
import { CommerceAuthGuard } from '../commerce/commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from '../commerce/commerce-auth.service';
import {
  OrganizerMarketingService,
  type AudienceSegment,
  type MarketingChannel,
} from './organizer-marketing.service';

@Controller()
@Public()
@UseGuards(CommerceAuthGuard)
export class OrganizerMarketingController {
  constructor(private readonly marketing: OrganizerMarketingService) {}

  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Get('organizers/me/marketing/channels')
  async channels(@CommerceActorParam() actor: CommerceActor) {
    return this.marketing.channelAvailability(actor!.tenantId);
  }

  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Get('organizers/me/marketing/segments')
  async segments() {
    return { items: await this.marketing.listAudienceSegments() };
  }

  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Get('organizers/me/marketing/audience/preview')
  async previewAudience(
    @CommerceActorParam() actor: CommerceActor,
    @Query('eventId') eventId: string,
    @Query('segment') segment?: string,
    @Query('channel') channel?: string,
  ) {
    return this.marketing.previewAudience(actor!, {
      eventId,
      segment: (segment ?? 'all_guests') as AudienceSegment,
      channel: (channel ?? 'email') as MarketingChannel,
    });
  }

  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Get('organizers/me/marketing/campaigns')
  async list(
    @CommerceActorParam() actor: CommerceActor,
    @Query('eventId') eventId?: string,
  ) {
    return this.marketing.listCampaigns(actor!, eventId);
  }

  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Get('organizers/me/marketing/campaigns/:id')
  async get(@CommerceActorParam() actor: CommerceActor, @Param('id') id: string) {
    return this.marketing.getCampaign(actor!, id);
  }

  @Throttle({ strict: { limit: 30, ttl: 60_000 } })
  @Post('organizers/me/marketing/campaigns')
  async create(
    @CommerceActorParam() actor: CommerceActor,
    @Body()
    body: {
      eventId?: string;
      name?: string;
      channel?: MarketingChannel;
      audienceSegment?: AudienceSegment;
      subject?: string;
      body?: string;
    },
  ) {
    return this.marketing.createCampaign(actor!, {
      eventId: body.eventId,
      name: body.name ?? '',
      channel: body.channel,
      audienceSegment: body.audienceSegment,
      subject: body.subject,
      body: body.body,
    });
  }

  @Throttle({ strict: { limit: 10, ttl: 60_000 } })
  @Post('organizers/me/marketing/campaigns/:id/send')
  async send(@CommerceActorParam() actor: CommerceActor, @Param('id') id: string) {
    return this.marketing.sendCampaign(actor!, id);
  }
}
