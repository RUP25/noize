// lib/utils/localization_helper.dart
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Helper class for easy access to localizations
class L10n {
  static AppLocalizations? of(BuildContext context) {
    return AppLocalizations.of(context);
  }
  
  // Common translations as static methods for convenience
  static String getLanguage(BuildContext context) {
    return of(context)?.language ?? 'Language';
  }
  
  static String getSave(BuildContext context) {
    return of(context)?.save ?? 'Save';
  }
  
  static String getCancel(BuildContext context) {
    return of(context)?.cancel ?? 'Cancel';
  }
  
  static String getSettings(BuildContext context) {
    return of(context)?.settings ?? 'Settings';
  }
  
  static String getProfile(BuildContext context) {
    return of(context)?.profile ?? 'Profile';
  }
  
  static String getHome(BuildContext context) {
    return of(context)?.home ?? 'Home';
  }
  
  static String getSearch(BuildContext context) {
    return of(context)?.search ?? 'Search';
  }
  
  static String getLogin(BuildContext context) {
    return of(context)?.login ?? 'Login';
  }
  
  static String getLogout(BuildContext context) {
    return of(context)?.logout ?? 'Logout';
  }
  
  static String getWelcome(BuildContext context) {
    return of(context)?.welcome ?? 'Welcome';
  }
  
  static String getError(BuildContext context) {
    return of(context)?.error ?? 'Error';
  }
  
  static String getSuccess(BuildContext context) {
    return of(context)?.success ?? 'Success';
  }
  
  static String getLoading(BuildContext context) {
    return of(context)?.loading ?? 'Loading...';
  }
}
