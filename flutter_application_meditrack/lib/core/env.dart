import 'package:flutter/foundation.dart';

class Env {
  // Em debug, liga o mock por padrão. Em prod fica off.
  static const useMockAuth = bool.fromEnvironment('USE_MOCK_AUTH', defaultValue: kDebugMode);

  static const mockEmail = String.fromEnvironment('MOCK_EMAIL', defaultValue: 'dev@meditrack.app');
  static const mockPass  = String.fromEnvironment('MOCK_PASS',  defaultValue: '12345678');
}
