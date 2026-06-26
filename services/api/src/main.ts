import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { RequestMethod, ValidationPipe } from '@nestjs/common';
import { SanitizeInputPipe } from './common/pipes/sanitize-input.pipe';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { OwanbeExceptionFilter } from './common/filters/owanbe-exception.filter';
import { IntegrationsModeService } from './integrations/integrations-mode.service';
import { MetricsService } from './integrations/observability/metrics.service';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    bufferLogs: true,
    rawBody: true,
  });
  app.get(IntegrationsModeService).requireProductionConfig();
  app.enableCors({
    origin: process.env.NODE_ENV === 'production'
      ? (process.env.CORS_ORIGINS ?? '').split(',').filter(Boolean)
      : true,
    credentials: true,
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Tenant-Id', 'Accept'],
  });
  app.setGlobalPrefix('v1', {
    exclude: [
      { path: 'health', method: RequestMethod.GET },
      { path: 'metrics', method: RequestMethod.GET },
      { path: 'webhooks/quaser', method: RequestMethod.POST },
    ],
  });
  app.useGlobalPipes(new SanitizeInputPipe(), new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );
  app.useGlobalFilters(new OwanbeExceptionFilter(app.get(MetricsService)));
  const port = process.env.PORT ?? 8080;
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`Owanbe API listening on http://localhost:${port}/v1`);
}

bootstrap().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});
