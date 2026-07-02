class ServiceException implements Exception {
  const ServiceException(this.message);
  final String message;
  @override
  String toString() => 'ServiceException: $message';
}

class ValidationException extends ServiceException {
  const ValidationException(super.message);
}

class AuthorizationException extends ServiceException {
  const AuthorizationException(super.message);
}

class WorkflowException extends ServiceException {
  const WorkflowException(super.message);
}

class BusinessRuleException extends ServiceException {
  const BusinessRuleException(super.message);
}

class ResourceNotFoundException extends ServiceException {
  const ResourceNotFoundException(super.message);
}
