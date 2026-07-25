/// Centralized validators for all profile editors.
class ProfileValidators {
  ProfileValidators._();

  static const maxName = 80;
  static const maxDisplayName = 120;
  static const maxBio = 1000;
  static const maxShortText = 120;
  static const maxInterestLabel = 48;
  static const maxInterests = 24;
  static const maxUrl = 2048;

  static String? required(String? value, {String label = 'This field'}) {
    if ((value ?? '').trim().isEmpty) return '$label is required';
    return null;
  }

  static String? maxLength(String? value, int max, {String? message}) {
    if ((value ?? '').trim().length > max) {
      return message ?? 'Must be $max characters or less';
    }
    return null;
  }

  static String? optionalMaxLength(String? value, int max, {String? message}) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return null;
    return maxLength(t, max, message: message);
  }

  static String? requiredMaxLength(String? value, int max, {required String label}) {
    return required(value, label: label) ?? maxLength(value, max);
  }

  /// Empty is allowed; otherwise must be http(s) with a host.
  static String? optionalHttpUrl(String? value) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return null;
    if (t.length > maxUrl) return 'URL is too long';
    final candidate = t.contains('://') ? t : 'https://$t';
    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      return 'Enter a valid URL';
    }
    return null;
  }

  static String? firstName(String? value) =>
      optionalMaxLength(value, maxName, message: 'Too long');

  static String? lastName(String? value) =>
      optionalMaxLength(value, maxName, message: 'Too long');

  static String? displayName(String? value) =>
      requiredMaxLength(value, maxDisplayName, label: 'Display name');

  static String? bio(String? value) =>
      optionalMaxLength(value, maxBio, message: 'Bio must be $maxBio characters or less');

  static String? occupation(String? value) => optionalMaxLength(value, maxShortText);

  static String? company(String? value) => optionalMaxLength(value, maxShortText);

  static String? interests(Iterable<String> selected) {
    if (selected.length > maxInterests) {
      return 'Select up to $maxInterests interests';
    }
    for (final item in selected) {
      if (item.trim().length > maxInterestLabel) {
        return 'Interest labels must be $maxInterestLabel characters or less';
      }
    }
    return null;
  }

  /// Returns first social URL error, or null if all valid.
  static String? socialLinks(Map<String, String> links) {
    for (final entry in links.entries) {
      final err = optionalHttpUrl(entry.value);
      if (err != null) return '${entry.key}: $err';
    }
    return null;
  }

  static String? combine(Iterable<String? Function()> checks) {
    for (final check in checks) {
      final err = check();
      if (err != null) return err;
    }
    return null;
  }
}
