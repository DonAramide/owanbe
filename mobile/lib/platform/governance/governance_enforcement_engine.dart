import 'governance_models.dart';
import 'governance_permissions.dart';

class GovernanceEnforcementEngine {
  // Authorization checks based on governance rules and state machine
  static bool canMessage(String vendorId, {VendorLifecycleState? state}) {
    if (state == VendorLifecycleState.suspended || state == VendorLifecycleState.blocked) {
      return false;
    }
    return true;
  }

  static bool canWithdraw(String vendorId, {VendorLifecycleState? state, bool? walletFrozen}) {
    if (walletFrozen == true || state == VendorLifecycleState.suspended || state == VendorLifecycleState.blocked) {
      return false;
    }
    return true;
  }

  static bool canCall(String vendorId, {VendorLifecycleState? state}) {
    if (state == VendorLifecycleState.suspended || state == VendorLifecycleState.blocked) {
      return false;
    }
    return true;
  }

  static bool canReceiveBookings(String vendorId, {VendorLifecycleState? state}) {
    if (state != VendorLifecycleState.active && state != VendorLifecycleState.approved) {
      return false;
    }
    return true;
  }

  static bool canUploadDocuments(String vendorId, {VendorLifecycleState? state}) {
    if (state == VendorLifecycleState.blocked) {
      return false;
    }
    return true;
  }
}
