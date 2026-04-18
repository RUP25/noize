import 'dart:math';

/// Shared NOIZE Guest (entry funnel) playback rules: limited skips per app session.
/// Conversion target: NOIZE Listen (full library, ad-free, downloads, no guest caps).
class GuestPlaybackPolicy {
  GuestPlaybackPolicy._();

  static const int maxSkipsPerSession = 6;
  static int _used = 0;

  static int get skipsRemaining => max(0, maxSkipsPerSession - _used);

  /// Call when starting a fresh Welcome → Continue as Guest session.
  static void resetSession() {
    _used = 0;
  }

  /// Returns true if a skip is allowed (increments usage). False if quota is exhausted.
  static bool tryConsumeSkip() {
    if (_used >= maxSkipsPerSession) return false;
    _used++;
    return true;
  }
}
