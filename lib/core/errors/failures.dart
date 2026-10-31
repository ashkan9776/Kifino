import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

final class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.code});
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code});
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.code});
}

final class CurrencyMismatchFailure extends Failure {
  const CurrencyMismatchFailure(super.message, {super.code});
}

final class SyncFailure extends Failure {
  const SyncFailure(super.message, {super.code});
}

final class SecurityFailure extends Failure {
  const SecurityFailure(super.message, {super.code});
}

final class ParsingFailure extends Failure {
  const ParsingFailure(super.message, {super.code});
}

final class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.code});
}
