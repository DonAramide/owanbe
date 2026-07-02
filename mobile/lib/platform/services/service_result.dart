enum ServiceResultType {
  success,
  validationFailure,
  authorizationFailure,
  businessRuleFailure,
  externalDependencyFailure,
  notFound
}

class ServiceResult<T> {
  const ServiceResult({
    required this.type,
    this.data,
    this.message,
  });

  final ServiceResultType type;
  final T? data;
  final String? message;

  bool get isSuccess => type == ServiceResultType.success;
  bool get isFailure => !isSuccess;

  factory ServiceResult.success(T data) {
    return ServiceResult(type: ServiceResultType.success, data: data);
  }

  factory ServiceResult.validationFailure(String message) {
    return ServiceResult(type: ServiceResultType.validationFailure, message: message);
  }

  factory ServiceResult.authorizationFailure(String message) {
    return ServiceResult(type: ServiceResultType.authorizationFailure, message: message);
  }

  factory ServiceResult.businessRuleFailure(String message) {
    return ServiceResult(type: ServiceResultType.businessRuleFailure, message: message);
  }

  factory ServiceResult.externalDependencyFailure(String message) {
    return ServiceResult(type: ServiceResultType.externalDependencyFailure, message: message);
  }

  factory ServiceResult.notFound(String message) {
    return ServiceResult(type: ServiceResultType.notFound, message: message);
  }

  factory ServiceResult.failure(String message) {
    return ServiceResult(type: ServiceResultType.externalDependencyFailure, message: message);
  }
}
