import 'package:flutter/foundation.dart';

/// Shared save / cancel / dirty / loading / error behaviour for profile editors.
class ProfileEditController extends ChangeNotifier {
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  String? _successMessage;

  bool get isSaving => _saving;
  bool get isDirty => _dirty;
  bool get hasError => _error != null && _error!.isNotEmpty;
  String? get errorMessage => _error;
  String? get successMessage => _successMessage;

  void markDirty([bool dirty = true]) {
    if (_dirty == dirty) return;
    _dirty = dirty;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void setError(String message) {
    _error = message;
    _saving = false;
    notifyListeners();
  }

  /// Runs [action] with loading/error/success handling.
  /// Returns true on success.
  Future<bool> runSave(Future<void> Function() action, {String successMessage = 'Profile updated'}) async {
    if (_saving) return false;
    _saving = true;
    _error = null;
    _successMessage = null;
    notifyListeners();
    try {
      await action();
      _saving = false;
      _dirty = false;
      _successMessage = successMessage;
      notifyListeners();
      return true;
    } catch (e) {
      _saving = false;
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> confirmDiscardIfDirty(Future<bool> Function() askUser) async {
    if (!_dirty || _saving) return true;
    return askUser();
  }

  void reset() {
    _saving = false;
    _dirty = false;
    _error = null;
    _successMessage = null;
    notifyListeners();
  }

  static String _friendlyError(Object e) {
    final text = e.toString();
    if (text.isEmpty) return 'Could not save profile. Try again.';
    return text;
  }
}
