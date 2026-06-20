import { Module } from '@nestjs/common';
import { PassportModule } from '@nestjs/passport';
import { DevAdminAuthService } from './dev-admin-auth.service';
import { DevSuperAdminAuthService } from './dev-super-admin-auth.service';
import { SupabaseJwtStrategy } from './supabase-jwt.strategy';

@Module({
  imports: [PassportModule.register({ defaultStrategy: 'supabase-jwt' })],
  providers: [SupabaseJwtStrategy, DevAdminAuthService, DevSuperAdminAuthService],
  exports: [PassportModule, DevAdminAuthService, DevSuperAdminAuthService],
})
export class AuthModule {}
