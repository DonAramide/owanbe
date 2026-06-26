import {
  ForbiddenException,
  Injectable,
  Inject,
  Logger,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';
import type { Pool } from 'pg';
import { PG_POOL } from '../../database/database.tokens';
import type { EnvVars } from '../../config/env.schema';
import { MetricsService } from '../observability/metrics.service';

export interface PresignUploadInput {
  tenantId: string;
  uploadedBy: string;
  filename: string;
  contentType: string;
  purpose?: string;
}

export interface PresignUploadResult {
  objectId: string;
  bucket: string;
  objectKey: string;
  uploadUrl: string;
  publicUrl: string;
  headers?: Record<string, string>;
}

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly config: ConfigService<EnvVars, true>,
    private readonly metrics: MetricsService,
  ) {}

  private bucket(): string {
    return this.config.get('STORAGE_BUCKET', { infer: true }).trim() || 'owanbe-media';
  }

  isSupabaseConfigured(): boolean {
    return Boolean(
      this.config.get('SUPABASE_URL', { infer: true }).trim() &&
        this.config.get('SUPABASE_SERVICE_ROLE_KEY', { infer: true }).trim(),
    );
  }

  async createPresignedUpload(input: PresignUploadInput): Promise<PresignUploadResult> {
    const safeName = input.filename.replace(/[^a-zA-Z0-9._-]/g, '_').slice(0, 120);
    const objectKey = `${input.tenantId}/${input.purpose ?? 'general'}/${randomUUID()}-${safeName}`;
    const bucket = this.bucket();

    let uploadUrl: string;
    let publicUrl: string;

    const base = this.config.get('PUBLIC_API_BASE_URL', { infer: true }).trim() || 'http://localhost:8080';
    uploadUrl = `${base.replace(/\/$/, '')}/v1/media/upload/${encodeURIComponent(objectKey)}`;

    if (this.isSupabaseConfigured()) {
      const supabaseUrl = this.config.get('SUPABASE_URL', { infer: true }).replace(/\/$/, '');
      publicUrl = `${supabaseUrl}/storage/v1/object/public/${bucket}/${objectKey}`;
    } else {
      publicUrl = uploadUrl;
      this.logger.warn('Supabase storage not configured — using API upload proxy URL');
    }

    const { rows } = await this.pool.query<{ id: string }>(
      `INSERT INTO media_objects (tenant_id, bucket, object_key, content_type, public_url, uploaded_by, purpose)
       VALUES ($1, $2, $3, $4, $5, $6::uuid, $7)
       RETURNING id::text`,
      [input.tenantId, bucket, objectKey, input.contentType, publicUrl, input.uploadedBy, input.purpose ?? 'general'],
    );

    this.metrics.inc('storage_presign_total');
    return { objectId: rows[0]!.id, bucket, objectKey, uploadUrl, publicUrl };
  }

  /** Server-side upload proxy — service role key never leaves the API. */
  async proxyUpload(params: {
    tenantId: string;
    userId: string;
    encodedKey: string;
    contentType: string;
    body: Buffer;
  }): Promise<{ ok: true; publicUrl: string }> {
    const objectKey = decodeURIComponent(params.encodedKey);
    const { rows } = await this.pool.query<{ id: string; uploaded_by: string; public_url: string; bucket: string }>(
      `SELECT id, uploaded_by::text, public_url, bucket
       FROM media_objects
       WHERE tenant_id = $1 AND object_key = $2`,
      [params.tenantId, objectKey],
    );
    const row = rows[0];
    if (!row) {
      throw new NotFoundException({ code: 'OBJECT_NOT_FOUND', message: 'Upload target not found' });
    }
    if (row.uploaded_by !== params.userId) {
      throw new ForbiddenException({ code: 'UPLOAD_FORBIDDEN', message: 'Not allowed to upload to this object' });
    }

    if (!this.isSupabaseConfigured()) {
      this.metrics.inc('storage_proxy_upload_total');
      return { ok: true, publicUrl: row.public_url };
    }

    const supabaseUrl = this.config.get('SUPABASE_URL', { infer: true }).replace(/\/$/, '');
    const serviceKey = this.config.get('SUPABASE_SERVICE_ROLE_KEY', { infer: true });
    const res = await fetch(`${supabaseUrl}/storage/v1/object/${row.bucket}/${objectKey}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${serviceKey}`,
        'Content-Type': params.contentType || 'application/octet-stream',
        'x-upsert': 'false',
      },
      body: new Uint8Array(params.body),
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => '');
      throw new UnprocessableEntityException({
        code: 'STORAGE_UPLOAD_FAILED',
        message: detail || 'Storage upload failed',
      });
    }

    this.metrics.inc('storage_proxy_upload_total');
    return { ok: true, publicUrl: row.public_url };
  }

  async resolvePublicUrl(tenantId: string, objectId: string): Promise<string | null> {
    const { rows } = await this.pool.query<{ public_url: string }>(
      `SELECT public_url FROM media_objects WHERE tenant_id = $1 AND id = $2::uuid`,
      [tenantId, objectId],
    );
    return rows[0]?.public_url ?? null;
  }
}
