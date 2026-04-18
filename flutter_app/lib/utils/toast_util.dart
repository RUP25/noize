// lib/utils/toast_util.dart
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void showToast(String msg) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      final mediaQuery = MediaQuery.of(ctx);
      final safeAreaTop = mediaQuery.padding.top;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: mediaQuery.size.height - safeAreaTop - 80,
            left: 16,
            right: 16,
          ),
        ),
      );
    } else {
      debugPrint(msg);
    }
  });
}
