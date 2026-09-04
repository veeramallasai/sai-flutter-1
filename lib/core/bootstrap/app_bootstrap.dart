class AppBootstrap {
  AppBootstrap._();

  /// Firebase initialization is intentionally disabled.
  /// Phase-1 customer authentication now uses the shared Spring Boot JWT API.
  static Future<void> initialize() async {}
}
