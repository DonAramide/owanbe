import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { ThrottlerException } from '@nestjs/throttler';
import type { Request, Response } from 'express';
import type { MetricsService } from '../../integrations/observability/metrics.service';

function requestIdFrom(host: ArgumentsHost): string {
  const req = host.switchToHttp().getRequest<Request>();
  return req.requestId ?? 'unknown';
}

function normalizeMessage(value: unknown, fallback: string): string {
  if (typeof value === 'string') return value;
  if (Array.isArray(value)) return value.map(String).join('; ');
  if (value != null && typeof value === 'object') return JSON.stringify(value);
  return fallback;
}

@Catch()
export class OwanbeExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(OwanbeExceptionFilter.name);

  constructor(private readonly metrics?: MetricsService) {}

  private recordHttpError(status: number, code: string, route: string): void {
    this.metrics?.inc('api_errors_total', {
      status: String(status),
      code,
      route: route.split('?')[0] ?? 'unknown',
    });
  }

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const requestId = requestIdFrom(host);
    const route = request.path ?? 'unknown';

    if (exception instanceof ThrottlerException) {
      this.recordHttpError(HttpStatus.TOO_MANY_REQUESTS, 'THROTTLED', route);
      response.status(HttpStatus.TOO_MANY_REQUESTS).json({
        code: 'THROTTLED',
        message: exception.message || 'Too many requests',
        request_id: requestId,
      });
      return;
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const res = exception.getResponse();
      const body =
        typeof res === 'string'
          ? { code: HttpStatus[status] ?? 'HTTP_ERROR', message: res }
          : (res as Record<string, unknown>);
      const code = (body.code as string) ?? HttpStatus[status] ?? 'HTTP_ERROR';
      const message = normalizeMessage(body.message, exception.message);
      this.recordHttpError(status, code, route);
      response.status(status).json({
        code,
        message,
        request_id: requestId,
      });
      return;
    }

    this.logger.error({ requestId, err: exception });
    this.recordHttpError(HttpStatus.INTERNAL_SERVER_ERROR, 'INTERNAL', route);
    response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      code: 'INTERNAL',
      message: 'Internal server error',
      request_id: requestId,
    });
  }
}
