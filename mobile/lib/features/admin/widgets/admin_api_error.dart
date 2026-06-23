import '../../../core/api/admin_platform_api.dart';
import '../../../core/api/owanbe_api_auth.dart';
import '../finance/admin_finance_models.dart';

enum AdminErrorKind { sessionExpired, unauthorized, generic }

AdminErrorKind classifyAdminError(Object error) {
  final code = _errorCode(error);
  final message = error.toString().toLowerCase();

  if (code == 'INVALID_TOKEN' ||
      code == 'AUTH_REQUIRED' ||
      code == 'AUTH_MISSING' ||
      message.contains('owanbeauthrequiredexception') ||
      message.contains('sign in required') ||
      message.contains('401')) {
    return AdminErrorKind.sessionExpired;
  }

  if (code == 'FORBIDDEN' ||
      message.contains('403') ||
      message.contains('permission') ||
      message.contains('not authorized')) {
    return AdminErrorKind.unauthorized;
  }

  return AdminErrorKind.generic;
}

String _errorCode(Object error) {
  if (error is AdminPlatformApiException) return error.code;
  if (error is AdminFinanceApiException) return error.code;
  if (error is OwanbeAuthRequiredException) return 'AUTH_REQUIRED';
  return '';
}

String friendlyAdminErrorMessage(Object error) {
  if (error is AdminPlatformApiException) return error.message;
  if (error is AdminFinanceApiException) return error.message;
  if (error is OwanbeAuthRequiredException) return error.message;
  return 'Something went wrong while loading platform data.';
}
