import 'governance_enforcement_engine.dart';
import 'governance_models.dart';

class GovernanceGuard {
  static void assertCanMessage(String vendorId, VendorLifecycleState state) {
    if (!GovernanceEnforcementEngine.canMessage(vendorId, state: state)) {
      throw Exception('Messaging disabled by administrator policy overrides.');
    }
  }

  static void assertCanWithdraw(String vendorId, VendorLifecycleState state, bool walletFrozen) {
    if (!GovernanceEnforcementEngine.canWithdraw(vendorId, state: state, walletFrozen: walletFrozen)) {
      throw Exception('Wallet frozen. Payout requests restricted.');
    }
  }
}
