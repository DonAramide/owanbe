import { Controller, Get, Param, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { Public } from '../../common/decorators/public.decorator';
import { CommerceAuthGuard } from '../../modules/commerce/commerce-auth.guard';
import { CommerceActorParam, type CommerceActor } from '../../modules/commerce/commerce-auth.service';
import { EventsAccessService } from '../../modules/events/events-access.service';
import { RealtimeBroadcastService } from './realtime-broadcast.service';

@Controller()
export class EventFeedStreamController {
  constructor(
    private readonly broadcast: RealtimeBroadcastService,
    private readonly access: EventsAccessService,
  ) {}

  @Public()
  @UseGuards(CommerceAuthGuard)
  @Get('events/:eventId/feed/stream')
  async streamFeed(
    @Param('eventId') eventKey: string,
    @CommerceActorParam() actor: CommerceActor,
    @Res() res: Response,
  ) {
    const event = await this.access.assertOrganizerOwnsEvent(actor!.tenantId, actor!.userId, eventKey);

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();

    const send = (data: unknown) => {
      res.write(`data: ${JSON.stringify(data)}\n\n`);
    };

    send({ type: 'connected', eventId: eventKey, timestamp: new Date().toISOString() });

    const unsubscribe = this.broadcast.subscribe(actor!.tenantId, event.id, (evt) => send({ type: 'feed', ...evt }));

    const heartbeat = setInterval(() => {
      res.write(': ping\n\n');
    }, 25_000);

    res.on('close', () => {
      clearInterval(heartbeat);
      unsubscribe();
    });
  }
}
