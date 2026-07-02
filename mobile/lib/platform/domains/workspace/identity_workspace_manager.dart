import 'package:flutter/foundation.dart';
import '../../identity/identity_platform.dart';
import '../../identity/identity_models.dart';

class IdentityWorkspaceManager extends ChangeNotifier {
  IdentityWorkspaceManager._();
  static final IdentityWorkspaceManager instance = IdentityWorkspaceManager._();

  final List<String> _recentWorkspaces = [];
  final List<String> _favoriteWorkspaces = [];

  List<String> get recentWorkspaces => List.unmodifiable(_recentWorkspaces);
  List<String> get favoriteWorkspaces => List.unmodifiable(_favoriteWorkspaces);

  UserContext? get userContext => IdentityPlatform.instance.currentUserContext;

  void selectWorkspace(UserRole role) {
    IdentityPlatform.instance.switchActiveRole(role);
    
    final roleName = role.name;
    _recentWorkspaces.remove(roleName);
    _recentWorkspaces.insert(0, roleName);
    if (_recentWorkspaces.length > 5) {
      _recentWorkspaces.removeLast();
    }
    
    notifyListeners();
  }

  void toggleFavorite(UserRole role) {
    final roleName = role.name;
    if (_favoriteWorkspaces.contains(roleName)) {
      _favoriteWorkspaces.remove(roleName);
    } else {
      _favoriteWorkspaces.add(roleName);
    }
    notifyListeners();
  }

  void switchTenant(String tenantId) {
    final current = IdentityPlatform.instance.currentUserContext;
    if (current != null) {
      IdentityPlatform.instance.signOut(); // Revoke session for safety on tenant context switch
    }
  }
}
