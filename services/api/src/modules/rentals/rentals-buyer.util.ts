/** Pure helpers for vendor-as-buyer rentals. No new booking table. */

export function isSelfRental(buyerVendorId: string | null | undefined, providerVendorId: string): boolean {
  if (!buyerVendorId) return false;
  return buyerVendorId === providerVendorId;
}

/** Packages are rented as one offering; SKUs keep requested quantity. */
export function resolveRentalQuantity(isPackage: boolean, quantityRequested: number): number {
  if (isPackage) return 1;
  return Math.floor(Number(quantityRequested) || 0);
}
