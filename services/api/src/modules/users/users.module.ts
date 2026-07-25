import { Module } from '@nestjs/common';
import { AuthModule } from '../../auth/auth.module';
import { RolesModule } from '../../roles/roles.module';
import { AuthMeController } from './auth-me.controller';
import { AuthSignupController, AdminUserPortalController } from './auth-signup.controller';
import { AuthSignupService } from './auth-signup.service';
import { UsersService } from './users.service';
import { WorkspaceService } from './workspace.service';
import { WorkspaceController } from './workspace.controller';
import { PublicProfileController } from './public-profile.controller';

@Module({
  imports: [AuthModule, RolesModule],
  controllers: [
    AuthMeController,
    AuthSignupController,
    AdminUserPortalController,
    WorkspaceController,
    PublicProfileController,
  ],
  providers: [UsersService, AuthSignupService, WorkspaceService],
  exports: [UsersService, AuthSignupService, WorkspaceService],
})
export class UsersModule {}
