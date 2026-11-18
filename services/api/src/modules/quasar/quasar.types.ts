export interface QuasarBankDestination {
  accountNumber: string;
  bankCode: string;
  accountName: string;
}

export interface QuasarMerchantRecord {
  id: string;
  owanbeTenantId: string;
  ownerKind: 'organizer' | 'vendor';
  ownerId: string;
  quasarTenantId: string;
  slug: string;
  code: string | null;
  vertical: string;
  environment: 'test' | 'live';
  apiKeyHint: string;
  walletOwnerId: string;
  webhookRegistered: boolean;
}

export interface QuasarMerchantCredentials extends QuasarMerchantRecord {
  apiKey: string;
}

export interface QuasarPublicAccount {
  environment: 'test' | 'live';
  quasarTenantId: string;
  slug: string;
  code: string | null;
  vertical: string;
  webhookRegistered: boolean;
}
