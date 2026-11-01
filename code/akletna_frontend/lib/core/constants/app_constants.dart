class AppConstants {
  static const String appName = 'Akletna';
  static const String appTagline = 'HOMECOOKED LEBANESE FOOD';

  // Demo Android emulator loopback to the isolated demo backend.
  static const String apiBaseUrl = String.fromEnvironment(
    'AKLETNA_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:18091',
  );

  // Navigation Routes
  static const String splashRoute = '/';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String homeRoute = '/home';
}
