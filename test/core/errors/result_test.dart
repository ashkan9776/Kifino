import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/errors/failures.dart';
import 'package:kifino/core/errors/result.dart';

void main() {
  group('Result Type Tests', () {
    test('Success returns data and isSuccess is true', () {
      const result = Success<int>(42);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, equals(42));
      expect(result.failureOrNull, isNull);

      final mapped = result.map((x) => x * 2);
      expect(mapped.dataOrNull, equals(84));
    });

    test('FailureResult returns failure and isFailure is true', () {
      const failure = DatabaseFailure('Record not found');
      const result = FailureResult<int>(failure);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, equals(failure));

      final folded = result.fold(
        onSuccess: (data) => 'Success $data',
        onFailure: (f) => 'Failed: ${f.message}',
      );
      expect(folded, equals('Failed: Record not found'));
    });
  });
}
