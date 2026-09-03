export function isSelfServiceProcurement(buyerVendorId: string, providerVendorId: string): boolean {
  return buyerVendorId === providerVendorId;
}
