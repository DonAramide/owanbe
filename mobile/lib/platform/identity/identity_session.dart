import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/user_role.dart';

class IdentitySession {
  static const _emailKey = 'iips_auth_email';
  static const _activeRoleKey = 'iips_active_role';
  static const _activeTenantKey = 'iips_active_tenant';
  static const _languageKey = 'iips_preferred_language';
  static const _themeKey = 'iips_preferred_theme';

  Future<void> persistPreferences({
    required String email,
    required UserRole preferredRole,
    String? tenantId,
    String? language,
    String? theme,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
    await prefs.setString(_activeRoleKey, preferredRole.name);
    if (tenantId != null) {
      await prefs.setString(_activeTenantKey, tenantId);
    } else {
      await prefs.remove(_activeTenantKey);
    }
    if (language != null) {
      await prefs.setString(_languageKey, language);
    }
    if (theme != null) {
      await prefs.setString(_themeKey, theme);
    }
  }

  Future<Map<String, String>> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString(_emailKey) ?? '',
      'role': prefs.getString(_activeRoleKey) ?? '',
      'tenant': prefs.getString(_activeTenantKey) ?? '',
      'language': prefs.getString(_languageKey) ?? 'en',
      'theme': prefs.getString(_themeKey) ?? 'system',
    };
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeRoleKey);
    await prefs.remove(_activeTenantKey);
  }
}
