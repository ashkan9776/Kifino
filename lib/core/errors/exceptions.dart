class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code, super.details});
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.details});
}

class CurrencyMismatchException extends AppException {
  CurrencyMismatchException(String sourceCurrency, String targetCurrency)
      : super(
          'Currency mismatch: cannot perform calculation between $sourceCurrency and $targetCurrency',
          code: 'CURRENCY_MISMATCH',
        );
}

class SecurityException extends AppException {
  const SecurityException(super.message, {super.code, super.details});
}

class SyncException extends AppException {
  const SyncException(super.message, {super.code, super.details});
}

class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.code, super.details});
}
