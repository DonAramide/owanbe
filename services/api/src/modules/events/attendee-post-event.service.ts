import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Inject,
} from '@nestjs/common';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { CommerceActor } from '../commerce/commerce-auth.service';
import { EventsAccessService } from './events-access.service';

/** Days after ends_at during which submitted feedback may still be edited. */
const FEEDBACK_EDIT_GRACE_DAYS = 30;

export type AttendeeFeedbackView = {
  eventId: string;
  rating: number;
  comment: string | null;
  submittedAt: string;
  updatedAt: string;
  editable: boolean;
  editableUntil: string | null;
};

@Injectable()
export class AttendeePostEventService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly access: EventsAccessService,
  ) {}

  async getFeedback(actor: CommerceActor, eventKey: string): Promise<{
    feedback: AttendeeFeedbackView | null;
    editableUntil: string | null;
    canSubmit: boolean;
  }> {
    const event = await this.access.resolveEventRow(actor.tenantId, eventKey, true);
    await this.assertViewerAttends(actor, event.id);
    const editableUntil = this.editableUntilIso(event.ends_at);
    const canSubmit = this.isEditable(editableUntil);

    const { rows } = await this.pool.query<{
      rating: number;
      comment: string | null;
      created_at: Date;
      updated_at: Date;
    }>(
      `SELECT rating, comment, created_at, updated_at
       FROM event_attendee_feedback
       WHERE tenant_id = $1 AND event_id = $2 AND user_id = $3
       LIMIT 1`,
      [actor.tenantId, event.id, actor.userId],
    );

    if (!rows.length) {
      return { feedback: null, editableUntil, canSubmit };
    }

    const row = rows[0];
    return {
      feedback: {
        eventId: event.id,
        rating: Number(row.rating),
        comment: row.comment,
        submittedAt: row.created_at.toISOString(),
        updatedAt: row.updated_at.toISOString(),
        editable: canSubmit,
        editableUntil,
      },
      editableUntil,
      canSubmit,
    };
  }

  async upsertFeedback(
    actor: CommerceActor,
    eventKey: string,
    body: { rating?: unknown; comment?: unknown },
  ): Promise<AttendeeFeedbackView> {
    const event = await this.access.resolveEventRow(actor.tenantId, eventKey, true);
    await this.assertViewerAttends(actor, event.id);

    const editableUntil = this.editableUntilIso(event.ends_at);
    if (!this.isEditable(editableUntil)) {
      throw new ForbiddenException({
        code: 'FEEDBACK_CLOSED',
        message: 'Feedback for this event is closed',
      });
    }

    const rating = Number(body.rating);
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      throw new BadRequestException({
        code: 'INVALID_RATING',
        message: 'Rating must be an integer from 1 to 5',
      });
    }

    const commentRaw = body.comment == null ? null : String(body.comment).trim();
    const comment = commentRaw && commentRaw.length > 0 ? commentRaw.slice(0, 4000) : null;

    const { rows } = await this.pool.query<{
      rating: number;
      comment: string | null;
      created_at: Date;
      updated_at: Date;
    }>(
      `INSERT INTO event_attendee_feedback
         (tenant_id, event_id, user_id, rating, comment)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (tenant_id, event_id, user_id)
       DO UPDATE SET
         rating = EXCLUDED.rating,
         comment = EXCLUDED.comment,
         updated_at = now()
       RETURNING rating, comment, created_at, updated_at`,
      [actor.tenantId, event.id, actor.userId, rating, comment],
    );

    const row = rows[0];
    return {
      eventId: event.id,
      rating: Number(row.rating),
      comment: row.comment,
      submittedAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString(),
      editable: true,
      editableUntil,
    };
  }

  private editableUntilIso(endsAt: Date | null): string | null {
    if (!endsAt) return null;
    const until = new Date(endsAt.getTime());
    until.setUTCDate(until.getUTCDate() + FEEDBACK_EDIT_GRACE_DAYS);
    return until.toISOString();
  }

  private isEditable(editableUntilIso: string | null): boolean {
    if (!editableUntilIso) return true;
    return Date.now() <= new Date(editableUntilIso).getTime();
  }

  private async assertViewerAttends(actor: CommerceActor, eventId: string) {
    const { rows } = await this.pool.query(
      `SELECT 1 FROM ticket_entitlements
       WHERE tenant_id = $1 AND event_id = $2 AND holder_user_id = $3
         AND status IN ('issued', 'checked_in')
       LIMIT 1`,
      [actor.tenantId, eventId, actor.userId],
    );
    if (!rows.length) {
      throw new ForbiddenException({
        code: 'NOT_ATTENDING',
        message: 'You need a ticket for this event to leave feedback',
      });
    }
  }
}
