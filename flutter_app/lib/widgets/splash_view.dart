// lib/widgets/splash_view.dart
import 'package:flutter/material.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF111414),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ensure this asset exists: assets/logo.png
            Image(image: AssetImage('assets/logo.png'), height: 120),
            SizedBox(height: 18),
            Text(
              'NOIZE.music',
              style: TextStyle(
                color: Color(0xFF78E08F),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            )
          ],
        ),
      ),
    );
  }
}
