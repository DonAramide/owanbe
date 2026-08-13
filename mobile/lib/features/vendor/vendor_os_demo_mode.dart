import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Explicit Vendor OS Demo Mode — never auto-enabled for production users.
///
/// Set `VENDOR_OS_DEMO_MODE=true` in `assets/env/owanbe_config` only for
/// internal demos / QA. When false (default), Vendor OS starts empty and
/// binds only to authenticated vendor data.
abstract final class VendorOsDemoMode {
  static bool get isEnabled {
    final raw = (dotenv.env['VENDOR_OS_DEMO_MODE'] ?? 'false').trim().toLowerCase();
    return raw == 'true' || raw == '1' || raw == 'yes';
  }
}
