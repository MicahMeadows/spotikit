import 'package:logger/logger.dart';

class SpotikitLog {
  static final Logger logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
    ),
  );

  static bool _loggingEnabled = false;
  static bool _errorLoggingEnabled = true;

  static void log(String message) {
    if (_loggingEnabled) {
      logger.i(message);
    }
  }

  static void error(String message) {
    if (_errorLoggingEnabled) {
      logger.e(message);
    }
  }

  static void enableLogging({bool errorLogging = true}) {
    _loggingEnabled = true;
    _errorLoggingEnabled = errorLogging;
  }

  static void disableErrorLogging() {
    _errorLoggingEnabled = false;
  }

  static void disableLogging() {
    _loggingEnabled = false;
  }
}
