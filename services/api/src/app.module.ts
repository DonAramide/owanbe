import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { AuthModule } from './auth/auth.module';
import configuration from './config/configuration';
import { envValidationSchema } from './config/env.schema';
import { DatabaseModule } from './database/database.module';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { TenantHeaderGuard } from './common/guards/tenant-header.guard';
import { OwanbeThrottlerGuard } from './common/guards/owanbe-throttler.guard';
import { RequestIdMiddleware } from './common/middleware/request-id.middleware';
import { UsersModule } from './modules/users/users.module';
import { VendorsModule } from './modules/vendors/vendors.module';
import { OnboardingModule } from './modules/onboarding/onboarding.module';
import { AdminOnboardingModule } from './modules/admin-onboarding/admin-onboarding.module';
import { BookingsModule } from './modules/bookings/bookings.module';
import { CommerceModule } from './modules/commerce/commerce.module';
import { EventsModule } from './modules/events/events.module';
import { PlatformAdminModule } from './modules/platform-admin/platform-admin.module';
import { SuperAdminModule } from './modules/super-admin/super-admin.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { HealthModule } from './modules/health/health.module';
import { RolesModule } from './roles/roles.module';
import { AuditModule } from './audit/audit.module';
import { SecurityModule } from './security/security.module';
import { PermissionsModule } from './permissions/permissions.module';
import { PermissionsGuard } from './permissions/permissions.guard';
import { ComplianceModule } from './modules/compliance/compliance.module';
import { IntegrationsModule } from './integrations/integrations.module';
import { EventConfigModule } from './modules/event-config/event-config.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
      validationSchema: envValidationSchema,
      validationOptions: { abortEarly: true, allowUnknown: true },
    }),
    ThrottlerModule.forRoot({
      throttlers: [
        { name: 'default', ttl: 60_000, limit: 200 },
        { name: 'public', ttl: 60_000, limit: 500 },
        { name: 'onboarding', ttl: 60_000, limit: 40 },
        { name: 'strict', ttl: 60_000, limit: 30 },
      ],
    }),
    DatabaseModule,
    SecurityModule,
    PermissionsModule,
    RolesModule,
    AuditModule,
    AuthModule,
    HealthModule,
    UsersModule,
    VendorsModule,
    OnboardingModule,
    AdminOnboardingModule,
    BookingsModule,
    CommerceModule,
    EventsModule,
    PlatformAdminModule,
    SuperAdminModule,
    PaymentsModule,
    ComplianceModule,
    IntegrationsModule,
    EventConfigModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: TenantHeaderGuard },
    { provide: APP_GUARD, useClass: OwanbeThrottlerGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_GUARD, useClass: PermissionsGuard },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(RequestIdMiddleware).forRoutes('*');
  }
}
