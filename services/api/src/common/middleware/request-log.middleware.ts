import { Injectable, Logger, NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';

@Injectable()
export class RequestLogMiddleware implements NestMiddleware {
  private readonly logger = new Logger('HTTP');

  use(req: Request, res: Response, next: NextFunction) {
    const start = Date.now();
    const requestId = req.requestId ?? 'unknown';
    const tenantId = (req.headers['x-tenant-id'] as string | undefined) ?? undefined;
    const userId = (req as Request & { user?: { userId?: string } }).user?.userId;

    res.on('finish', () => {
      const durationMs = Date.now() - start;
      const eventId =
        (req.params?.eventId as string | undefined) ??
        (req.params?.id as string | undefined) ??
        undefined;
      this.logger.log({
        requestId,
        tenantId,
        userId,
        eventId,
        method: req.method,
        path: req.originalUrl,
        status: res.statusCode,
        durationMs,
      });
    });
    next();
  }
}
