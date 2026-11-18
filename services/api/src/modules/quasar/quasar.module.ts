import { Module, forwardRef } from '@nestjs/common';
import { CommerceModule } from '../commerce/commerce.module';
import { PaymentsModule } from '../payments/payments.module';
import { QuasarAuditService } from './quasar-audit.service';
import { QuasarClientService } from './quasar-client.service';
import { QuasarReconciliationService } from './quasar-reconciliation.service';
import { QuasarSecretsCrypto } from './quasar-secrets.crypto';
import { QuasarModeService } from './quasar-mode.service';
import { QuasarOnboardingController } from './quasar-onboarding.controller';
import { QuasarOnboardingService } from './quasar-onboarding.service';
import { QuasarTransferService } from './quasar-transfer.service';
import { QuasarVaultService } from './quasar-vault.service';
import { QuasarVirtualAccountService } from './quasar-virtual-account.service';
import { QuasarWebhookController } from './quasar-webhook.controller';
import { QuasarWebhookService } from './quasar-webhook.service';

@Module({
  imports: [forwardRef(() => CommerceModule), forwardRef(() => PaymentsModule)],
  controllers: [QuasarWebhookController, QuasarOnboardingController],
  providers: [
    QuasarModeService,
    QuasarSecretsCrypto,
    QuasarClientService,
    QuasarVaultService,
    QuasarOnboardingService,
    QuasarVirtualAccountService,
    QuasarTransferService,
    QuasarWebhookService,
    QuasarAuditService,
    QuasarReconciliationService,
  ],
  exports: [
    QuasarModeService,
    QuasarOnboardingService,
    QuasarVirtualAccountService,
    QuasarTransferService,
  ],
})
export class QuasarModule {}
