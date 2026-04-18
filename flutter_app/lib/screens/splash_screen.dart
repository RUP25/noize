// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'welcome_screen.dart';
import '../widgets/splash_view.dart';
import '../services/auth_service.dart';
import 'listener_home_screen.dart';
import 'listener_onboarding_screen.dart';
import 'artist_home_screen.dart';
import 'creator_home_screen.dart';
import 'dart:async';

class SplashAndRouter extends StatefulWidget {
  const SplashAndRouter({super.key});

  @override
  State<SplashAndRouter> createState() => _SplashAndRouterState();
}

class _SplashAndRouterState extends State<SplashAndRouter> {
  Future<Widget>? _initFuture;
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeAndRoute();
  }

  Future<Widget> _initializeAndRoute() async {
    // Small artificial delay to show splash
    await Future.delayed(const Duration(milliseconds: 700));
    
    // Check if user is logged in
    if (_auth.isLoggedIn) {
      try {
        // Verify token is still valid by getting user info (with timeout)
        final user = await _auth.getMe().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('getMe() timeout - backend might be unreachable');
            return null;
          },
        );
        if (user != null) {
          // Check if user needs onboarding
          final needsOnboarding = (user['full_name'] == null || (user['full_name']?.toString().trim().isEmpty ?? true)) ||
              (user['date_of_birth'] == null || (user['date_of_birth']?.toString().trim().isEmpty ?? true));
          
          // Route based on user role
          final userRole = user['user_role']?.toString().toLowerCase() ?? 'guest';
          
          if (needsOnboarding) {
            return const ListenerOnboardingScreen();
          } else if (userRole == 'artist') {
            return const ArtistHomeScreen();
          } else if (userRole == 'influencer') {
            return const CreatorHomeScreen();
          } else {
            // Default to listener home
            return const ListenerHomeScreen();
          }
        }
      } catch (e) {
        // If getMe fails, token might be invalid - clear it and show welcome
        print('Token validation failed: $e');
        await _auth.logout();
      }
    }
    
    // Not logged in or token invalid - show welcome screen
    return const WelcomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SplashView();
        }
        return snap.data ?? const WelcomeScreen();
      },
    );
  }
}
