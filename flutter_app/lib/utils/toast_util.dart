// lib/utils/toast_util.dart
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void showToast(String msg) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx)
          .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
    } else {
      debugPrint(msg);
    }
  });
}
