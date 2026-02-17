import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi')
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'NOIZE.music'**
  String get appTitle;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @signup.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signup;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// No description provided for @unlike.
  ///
  /// In en, this message translates to:
  /// **'Unlike'**
  String get unlike;

  /// No description provided for @follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// No description provided for @unfollow.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get unfollow;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @languageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Language updated successfully'**
  String get languageUpdated;

  /// No description provided for @languageUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update language'**
  String get languageUpdateFailed;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @emailNotifications.
  ///
  /// In en, this message translates to:
  /// **'Email Notifications'**
  String get emailNotifications;

  /// No description provided for @newMessage.
  ///
  /// In en, this message translates to:
  /// **'New Message'**
  String get newMessage;

  /// No description provided for @newFollower.
  ///
  /// In en, this message translates to:
  /// **'New Follower'**
  String get newFollower;

  /// No description provided for @newLike.
  ///
  /// In en, this message translates to:
  /// **'New Like'**
  String get newLike;

  /// No description provided for @newComment.
  ///
  /// In en, this message translates to:
  /// **'New Comment'**
  String get newComment;

  /// No description provided for @weeklyDigest.
  ///
  /// In en, this message translates to:
  /// **'Weekly Digest'**
  String get weeklyDigest;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacySettings.
  ///
  /// In en, this message translates to:
  /// **'Privacy Settings'**
  String get privacySettings;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @locationNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get locationNotSet;

  /// No description provided for @enterLocation.
  ///
  /// In en, this message translates to:
  /// **'Enter Location'**
  String get enterLocation;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @channelName.
  ///
  /// In en, this message translates to:
  /// **'Channel Name'**
  String get channelName;

  /// No description provided for @artistName.
  ///
  /// In en, this message translates to:
  /// **'Artist Name'**
  String get artistName;

  /// No description provided for @album.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get album;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @uploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload Photo'**
  String get uploadPhoto;

  /// No description provided for @uploadBanner.
  ///
  /// In en, this message translates to:
  /// **'Upload Banner'**
  String get uploadBanner;

  /// No description provided for @uploadSong.
  ///
  /// In en, this message translates to:
  /// **'Upload Song'**
  String get uploadSong;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No description provided for @uploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Upload successful'**
  String get uploadSuccess;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadFailed;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get saveFailed;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Continue button text
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @listener.
  ///
  /// In en, this message translates to:
  /// **'Listener'**
  String get listener;

  /// No description provided for @artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artist;

  /// No description provided for @influencer.
  ///
  /// In en, this message translates to:
  /// **'Influencer'**
  String get influencer;

  /// No description provided for @browseAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Browse as Guest'**
  String get browseAsGuest;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember Me'**
  String get rememberMe;

  /// No description provided for @enterOTP.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOTP;

  /// No description provided for @requestOTP.
  ///
  /// In en, this message translates to:
  /// **'Request OTP'**
  String get requestOTP;

  /// No description provided for @verifyOTP.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get verifyOTP;

  /// No description provided for @otpSent.
  ///
  /// In en, this message translates to:
  /// **'OTP sent successfully'**
  String get otpSent;

  /// No description provided for @otpFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send OTP'**
  String get otpFailed;

  /// No description provided for @invalidOTP.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP'**
  String get invalidOTP;

  /// No description provided for @resendOTP.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get resendOTP;

  /// No description provided for @noSongs.
  ///
  /// In en, this message translates to:
  /// **'No songs available'**
  String get noSongs;

  /// No description provided for @noArtists.
  ///
  /// In en, this message translates to:
  /// **'No artists found'**
  String get noArtists;

  /// No description provided for @noPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists'**
  String get noPlaylists;

  /// No description provided for @playlist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlist;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @createPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create Playlist'**
  String get createPlaylist;

  /// No description provided for @myPlaylists.
  ///
  /// In en, this message translates to:
  /// **'My Playlists'**
  String get myPlaylists;

  /// No description provided for @publicPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Public Playlists'**
  String get publicPlaylists;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get addToPlaylist;

  /// No description provided for @removeFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Remove from Playlist'**
  String get removeFromPlaylist;

  /// No description provided for @followers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get followers;

  /// No description provided for @following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// No description provided for @likes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get likes;

  /// No description provided for @views.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get views;

  /// No description provided for @songs.
  ///
  /// In en, this message translates to:
  /// **'songs'**
  String get songs;

  /// No description provided for @recentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get recentlyPlayed;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @newReleases.
  ///
  /// In en, this message translates to:
  /// **'New Releases'**
  String get newReleases;

  /// No description provided for @yourMusic.
  ///
  /// In en, this message translates to:
  /// **'Your Music'**
  String get yourMusic;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search songs, artists, albums...'**
  String get searchPlaceholder;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get searchResults;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @enterSearchQuery.
  ///
  /// In en, this message translates to:
  /// **'Enter a search query'**
  String get enterSearchQuery;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get networkError;

  /// No description provided for @serverError.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get serverError;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred'**
  String get unknownError;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to server'**
  String get connectionFailed;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait...'**
  String get pleaseWait;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @areYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get areYouSure;

  /// No description provided for @thisActionCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone'**
  String get thisActionCannotBeUndone;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @manageNotificationPreferences.
  ///
  /// In en, this message translates to:
  /// **'Manage notification preferences'**
  String get manageNotificationPreferences;

  /// No description provided for @managePrivacyPreferences.
  ///
  /// In en, this message translates to:
  /// **'Manage privacy preferences'**
  String get managePrivacyPreferences;

  /// No description provided for @updateYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Update your password'**
  String get updateYourPassword;

  /// No description provided for @permanentlyDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account'**
  String get permanentlyDeleteAccount;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAndConditions;

  /// No description provided for @viewTermsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'View terms and conditions'**
  String get viewTermsAndConditions;

  /// No description provided for @viewPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'View privacy policy'**
  String get viewPrivacyPolicy;

  /// No description provided for @sendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get sendFeedback;

  /// No description provided for @shareYourThoughts.
  ///
  /// In en, this message translates to:
  /// **'Share your thoughts and suggestions'**
  String get shareYourThoughts;

  /// No description provided for @helpAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpAndSupport;

  /// No description provided for @getHelpWithAccount.
  ///
  /// In en, this message translates to:
  /// **'Get help with your account'**
  String get getHelpWithAccount;

  /// No description provided for @supportAndFeedback.
  ///
  /// In en, this message translates to:
  /// **'Support & Feedback'**
  String get supportAndFeedback;

  /// No description provided for @signOutOfDevice.
  ///
  /// In en, this message translates to:
  /// **'Sign out of this device'**
  String get signOutOfDevice;

  /// No description provided for @top50Charts.
  ///
  /// In en, this message translates to:
  /// **'Top 50 Charts'**
  String get top50Charts;

  /// No description provided for @noSongsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No songs available'**
  String get noSongsAvailable;

  /// No description provided for @upgradeToNOIZEListen.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to NOIZE Listen'**
  String get upgradeToNOIZEListen;

  /// No description provided for @upgradeToNOIZEREP.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to NOIZE REP'**
  String get upgradeToNOIZEREP;

  /// No description provided for @upgradeNow.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Now'**
  String get upgradeNow;

  /// No description provided for @upgradeToREP.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to REP'**
  String get upgradeToREP;

  /// No description provided for @getAdFreeMusic.
  ///
  /// In en, this message translates to:
  /// **'Get ad-free music, unlimited skips,\nand offline downloads'**
  String get getAdFreeMusic;

  /// No description provided for @listenAndEarnRewards.
  ///
  /// In en, this message translates to:
  /// **'Listen & Earn rewards,\nKYC verification, referral bonuses'**
  String get listenAndEarnRewards;

  /// No description provided for @freeUserUpgradeReminderBannerHeader.
  ///
  /// In en, this message translates to:
  /// **'Want to earn while you listen?'**
  String get freeUserUpgradeReminderBannerHeader;

  /// No description provided for @freeUserUpgradeReminderBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to NOIZE REP and start earning by supporting music you love.'**
  String get freeUserUpgradeReminderBannerBody;

  /// No description provided for @freeUserUpgradeReminderBannerCta.
  ///
  /// In en, this message translates to:
  /// **'UPGRADE NOW'**
  String get freeUserUpgradeReminderBannerCta;

  /// No description provided for @premiumFeatureLockScreenHeader.
  ///
  /// In en, this message translates to:
  /// **'This feature is for premium members only.'**
  String get premiumFeatureLockScreenHeader;

  /// No description provided for @premiumFeatureLockScreenBody.
  ///
  /// In en, this message translates to:
  /// **'Get access to exclusive content, playlists, and earnings by upgrading today.'**
  String get premiumFeatureLockScreenBody;

  /// No description provided for @premiumFeatureLockScreenCta.
  ///
  /// In en, this message translates to:
  /// **'UNLOCK WITH PREMIUM'**
  String get premiumFeatureLockScreenCta;

  /// No description provided for @donationBadgePopupHeader.
  ///
  /// In en, this message translates to:
  /// **'You just made a difference.'**
  String get donationBadgePopupHeader;

  /// No description provided for @donationBadgePopupBody.
  ///
  /// In en, this message translates to:
  /// **'Your support helps real people around the world. A badge has been added to your profile.'**
  String get donationBadgePopupBody;

  /// No description provided for @artistPromotionEngagementHeader.
  ///
  /// In en, this message translates to:
  /// **'Boost Your Favorite Artist'**
  String get artistPromotionEngagementHeader;

  /// No description provided for @artistPromotionEngagementBody.
  ///
  /// In en, this message translates to:
  /// **'Join the campaign, earn rewards, and help their music reach the world.'**
  String get artistPromotionEngagementBody;

  /// No description provided for @artistPromotionEngagementCta.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT & EARN'**
  String get artistPromotionEngagementCta;

  /// No description provided for @listenerOnlySubscriptionPitchHeader.
  ///
  /// In en, this message translates to:
  /// **'Love listening? Listen more with NOIZE Listen.'**
  String get listenerOnlySubscriptionPitchHeader;

  /// No description provided for @listenerOnlySubscriptionPitchBody.
  ///
  /// In en, this message translates to:
  /// **'Ad-free. Unlimited playlists. Offline downloads.'**
  String get listenerOnlySubscriptionPitchBody;

  /// No description provided for @listenerOnlySubscriptionPitchCta.
  ///
  /// In en, this message translates to:
  /// **'GO PREMIUM'**
  String get listenerOnlySubscriptionPitchCta;

  /// No description provided for @downgradeConfirmationHeader.
  ///
  /// In en, this message translates to:
  /// **'You\'re about to downgrade your plan.'**
  String get downgradeConfirmationHeader;

  /// No description provided for @downgradeConfirmationBody.
  ///
  /// In en, this message translates to:
  /// **'Some features will be disabled. You can upgrade again anytime.'**
  String get downgradeConfirmationBody;

  /// No description provided for @downgradeConfirmationCta.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM DOWNGRADE'**
  String get downgradeConfirmationCta;

  /// No description provided for @repScoreBoosterReminderHeader.
  ///
  /// In en, this message translates to:
  /// **'Share more. Earn more.'**
  String get repScoreBoosterReminderHeader;

  /// No description provided for @repScoreBoosterReminderBody.
  ///
  /// In en, this message translates to:
  /// **'Boost your REP Score and unlock exclusive rewards.'**
  String get repScoreBoosterReminderBody;

  /// No description provided for @noLikedSongsYet.
  ///
  /// In en, this message translates to:
  /// **'No liked songs yet'**
  String get noLikedSongsYet;

  /// No description provided for @noPlaylistsYet.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get noPlaylistsYet;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @playlistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist Name'**
  String get playlistName;

  /// No description provided for @makePublic.
  ///
  /// In en, this message translates to:
  /// **'Make Public'**
  String get makePublic;

  /// No description provided for @shareWithOtherUsers.
  ///
  /// In en, this message translates to:
  /// **'Share with other users'**
  String get shareWithOtherUsers;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @removedFromLiked.
  ///
  /// In en, this message translates to:
  /// **'Removed from liked'**
  String get removedFromLiked;

  /// No description provided for @playlistCreated.
  ///
  /// In en, this message translates to:
  /// **'Playlist created!'**
  String get playlistCreated;

  /// No description provided for @liked.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get liked;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @by.
  ///
  /// In en, this message translates to:
  /// **'By'**
  String get by;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @noizeGuest.
  ///
  /// In en, this message translates to:
  /// **'NOIZE Guest'**
  String get noizeGuest;

  /// No description provided for @guestModeLimitations.
  ///
  /// In en, this message translates to:
  /// **'Guest Mode Limitations'**
  String get guestModeLimitations;

  /// No description provided for @listenWithAds.
  ///
  /// In en, this message translates to:
  /// **'• Listen with ads and limited skips\n• Create private playlists (cannot share)\n• Cannot download or earn rewards'**
  String get listenWithAds;

  /// No description provided for @loginRequiredToPlay.
  ///
  /// In en, this message translates to:
  /// **'Login required to play'**
  String get loginRequiredToPlay;

  /// No description provided for @upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrade;

  /// No description provided for @editPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Edit Playlist'**
  String get editPlaylist;

  /// No description provided for @playlistUpdated.
  ///
  /// In en, this message translates to:
  /// **'Playlist updated!'**
  String get playlistUpdated;

  /// No description provided for @deletePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Delete Playlist'**
  String get deletePlaylist;

  /// No description provided for @deletePlaylistConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete'**
  String get deletePlaylistConfirm;

  /// No description provided for @playlistDeleted.
  ///
  /// In en, this message translates to:
  /// **'Playlist deleted!'**
  String get playlistDeleted;

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete'**
  String get deleteFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
