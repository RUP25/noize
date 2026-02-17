import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../screens/premium_lock_screen.dart';
import '../screens/upgrade_screen.dart';

Future<void> showPremiumFeatureLock({
  required BuildContext context,
  String planType = 'listen',
}) async {
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => PremiumLockScreen(planType: planType)),
  );
}

Future<void> showPremiumFeatureLockDialog({
  required BuildContext context,
  String planType = 'listen',
}) async {
  final l10n = AppLocalizations.of(context);
  const accent = Color(0xFF78E08F);

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: Text(
        l10n?.premiumFeatureLockScreenHeader ??
            'This feature is for premium members only.',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Text(
        l10n?.premiumFeatureLockScreenBody ??
            'Get access to exclusive content, playlists, and earnings by upgrading today.',
        style: TextStyle(color: Colors.grey.shade300),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n?.cancel ?? 'Cancel',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UpgradeScreen(planType: planType)),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.black,
          ),
          child: Text(
            l10n?.premiumFeatureLockScreenCta ?? 'UNLOCK WITH PREMIUM',
          ),
        ),
      ],
    ),
  );
}

Future<void> showDonationBadgePopup({required BuildContext context}) async {
  final l10n = AppLocalizations.of(context);
  const accent = Color(0xFF78E08F);

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: Text(
        l10n?.donationBadgePopupHeader ?? 'You just made a difference.',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Text(
        l10n?.donationBadgePopupBody ??
            'Your support helps real people around the world. A badge has been added to your profile.',
        style: TextStyle(color: Colors.grey.shade300),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.black,
          ),
          child: Text(l10n?.close ?? 'Close'),
        ),
      ],
    ),
  );
}

Future<bool> showDowngradeConfirmation({required BuildContext context}) async {
  final l10n = AppLocalizations.of(context);
  const accent = Color(0xFF78E08F);

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: Text(
        l10n?.downgradeConfirmationHeader ?? "You're about to downgrade your plan.",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Text(
        l10n?.downgradeConfirmationBody ??
            'Some features will be disabled. You can upgrade again anytime.',
        style: TextStyle(color: Colors.grey.shade300),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            l10n?.cancel ?? 'Cancel',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.black,
          ),
          child: Text(
            l10n?.downgradeConfirmationCta ?? 'CONFIRM DOWNGRADE',
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}

