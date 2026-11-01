import 'dart:developer' as developer;

class AppLogger {
  static void info(String message, {String tag = 'Kifino'}) {
    developer.log(message, name: tag, level: 800);
  }

  static void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String tag = 'Kifino',
  }) {
    developer.log(
      message,
      name: tag,
      level: 900,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String tag = 'Kifino',
  }) {
    developer.log(
      message,
      name: tag,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
