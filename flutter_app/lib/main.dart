// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'providers/language_provider.dart';
import 'providers/player_state_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Add error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('Flutter Error: ${details.exception}');
    print('Stack trace: ${details.stack}');
  };

  // Handle platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    print('Platform Error: $error');
    print('Stack trace: $stack');
    return true;
  };

  try {
    // Initialize auth service (loads stored token)
    await AuthService().init();

    // Initialize language service
    final languageProvider = LanguageProvider();
    await languageProvider.init();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: languageProvider),
          ChangeNotifierProvider(create: (_) => PlayerStateProvider()),
        ],
        child: const NoizeApp(),
      ),
    );
  } catch (e, stackTrace) {
    print('Error during initialization: $e');
    print('Stack trace: $stackTrace');
    // Run app anyway with error screen
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Initialization Error: $e'),
                const SizedBox(height: 8),
                Text('Check console for details', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NoizeApp extends StatelessWidget {
  const NoizeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'NOIZE.music',
          
          // Localization configuration
          locale: languageProvider.currentLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          
          theme: ThemeData.dark(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: const Color(0xFF111414),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF78E08F),
              secondary: Color(0xFF38A169),
            ),
          ),
          home: const SplashAndRouter(),
        );
      },
    );
  }
}
