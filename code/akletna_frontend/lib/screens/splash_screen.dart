import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_exception.dart';
import '../core/storage/token_storage.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  final AuthService? authService;
  final TokenStorage? tokenStorage;

  const SplashScreen({super.key, this.authService, this.tokenStorage});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final TokenStorage _tokenStorage;
  late final AuthService _authService;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tokenStorage = widget.tokenStorage ?? TokenStorage();
    _authService = widget.authService ?? AuthService();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    setState(() => _errorMessage = null);
    // Keep splash visible for at least 1.5 seconds for branding smoothness
    final delay = Future.delayed(const Duration(milliseconds: 1500));

    try {
      final hasToken = await _tokenStorage.hasToken();

      if (!hasToken) {
        await delay;
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppConstants.loginRoute);
        return;
      }

      // Token exists: verify validity by fetching current user profile
      await _authService.getCurrentUser();

      await delay;
      if (!mounted) return;
      // Valid session -> Home Screen
      Navigator.pushReplacementNamed(context, AppConstants.homeRoute);
    } on ApiException catch (e) {
      await delay;
      if (!mounted) return;
      if (e.statusCode == 401) {
        try {
          await _tokenStorage.deleteToken();
        } catch (_) {
          if (!mounted) return;
          setState(
            () => _errorMessage =
                'Could not clear your session. Please try again.',
          );
          return;
        }
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppConstants.loginRoute);
      } else {
        setState(
          () => _errorMessage =
              'Could not verify your session. Please try again.',
        );
      }
    } catch (_) {
      await delay;
      if (!mounted) return;
      setState(
        () =>
            _errorMessage = 'Could not verify your session. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Decorative Food Icon Badge
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),

                // Arabic Title
                const Text(
                  'أكلتنا',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),

                // English Title
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle / Tagline
                const Text(
                  AppConstants.appTagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.0,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),

                // Subtle loader
                if (_errorMessage == null)
                  const CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(_errorMessage!, textAlign: TextAlign.center),
                  ),
                  TextButton(
                    onPressed: _checkAuthentication,
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
