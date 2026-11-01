import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/kitchen_shell.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AkletnaApp());
}

class AkletnaApp extends StatelessWidget {
  const AkletnaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppConstants.splashRoute,
      routes: {
        AppConstants.splashRoute: (context) => const SplashScreen(),
        AppConstants.loginRoute: (context) => const LoginScreen(),
        AppConstants.registerRoute: (context) => const RegisterScreen(),
        AppConstants.homeRoute: (context) => const KitchenShell(),
      },
    );
  }
}
