import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('ar'),
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @ok.
  ///
  /// In bn, this message translates to:
  /// **'ঠিক আছে'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In bn, this message translates to:
  /// **'বাতিল'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In bn, this message translates to:
  /// **'সংরক্ষণ'**
  String get save;

  /// No description provided for @retry.
  ///
  /// In bn, this message translates to:
  /// **'আবার চেষ্টা করুন'**
  String get retry;

  /// No description provided for @next.
  ///
  /// In bn, this message translates to:
  /// **'পরবর্তী'**
  String get next;

  /// No description provided for @back.
  ///
  /// In bn, this message translates to:
  /// **'পেছনে'**
  String get back;

  /// No description provided for @done.
  ///
  /// In bn, this message translates to:
  /// **'সম্পন্ন'**
  String get done;

  /// No description provided for @search.
  ///
  /// In bn, this message translates to:
  /// **'খুঁজুন'**
  String get search;

  /// No description provided for @share.
  ///
  /// In bn, this message translates to:
  /// **'শেয়ার'**
  String get share;

  /// No description provided for @copy.
  ///
  /// In bn, this message translates to:
  /// **'কপি'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In bn, this message translates to:
  /// **'কপি হয়েছে'**
  String get copied;

  /// No description provided for @see_all.
  ///
  /// In bn, this message translates to:
  /// **'সব দেখুন'**
  String get see_all;

  /// No description provided for @loading.
  ///
  /// In bn, this message translates to:
  /// **'লোড হচ্ছে…'**
  String get loading;

  /// No description provided for @empty_generic.
  ///
  /// In bn, this message translates to:
  /// **'এখনো কিছু নেই'**
  String get empty_generic;

  /// No description provided for @error_generic.
  ///
  /// In bn, this message translates to:
  /// **'কিছু একটা সমস্যা হয়েছে'**
  String get error_generic;

  /// No description provided for @offline.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন — পরিবর্তনগুলো সেভ থাকবে, নেট এলে সিঙ্ক হবে'**
  String get offline;

  /// No description provided for @offline_short.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন'**
  String get offline_short;

  /// No description provided for @online.
  ///
  /// In bn, this message translates to:
  /// **'অনলাইন'**
  String get online;

  /// No description provided for @guest.
  ///
  /// In bn, this message translates to:
  /// **'গেস্ট'**
  String get guest;

  /// No description provided for @version.
  ///
  /// In bn, this message translates to:
  /// **'সংস্করণ'**
  String get version;

  /// No description provided for @tab_home.
  ///
  /// In bn, this message translates to:
  /// **'হোম'**
  String get tab_home;

  /// No description provided for @tab_amal.
  ///
  /// In bn, this message translates to:
  /// **'আমল'**
  String get tab_amal;

  /// No description provided for @tab_dawah.
  ///
  /// In bn, this message translates to:
  /// **'দাওয়াত'**
  String get tab_dawah;

  /// No description provided for @tab_ilm.
  ///
  /// In bn, this message translates to:
  /// **'ইলম'**
  String get tab_ilm;

  /// No description provided for @tab_more.
  ///
  /// In bn, this message translates to:
  /// **'আরও'**
  String get tab_more;

  /// No description provided for @onb_title.
  ///
  /// In bn, this message translates to:
  /// **'সুন্নাহ লাইফে স্বাগতম'**
  String get onb_title;

  /// No description provided for @onb_step1_title.
  ///
  /// In bn, this message translates to:
  /// **'ভাষা নির্বাচন করুন'**
  String get onb_step1_title;

  /// No description provided for @onb_step2_title.
  ///
  /// In bn, this message translates to:
  /// **'আপনার পরিচয়'**
  String get onb_step2_title;

  /// No description provided for @onb_name.
  ///
  /// In bn, this message translates to:
  /// **'নাম'**
  String get onb_name;

  /// No description provided for @onb_name_hint.
  ///
  /// In bn, this message translates to:
  /// **'যেমন: আব্দুল্লাহ'**
  String get onb_name_hint;

  /// No description provided for @onb_gender.
  ///
  /// In bn, this message translates to:
  /// **'লিঙ্গ'**
  String get onb_gender;

  /// No description provided for @onb_male.
  ///
  /// In bn, this message translates to:
  /// **'ভাই (পুরুষ)'**
  String get onb_male;

  /// No description provided for @onb_female.
  ///
  /// In bn, this message translates to:
  /// **'বোন (নারী)'**
  String get onb_female;

  /// No description provided for @onb_female_privacy.
  ///
  /// In bn, this message translates to:
  /// **'বোনদের প্রতি আমাদের অঙ্গীকার: আপনার নাম, আমল ও পরিচয় কেবল মহিলা পরিদর্শক ও মহিলা উসরা প্রধান দেখতে পারবেন। ছেলে পরিদর্শক বা অ্যাডমিন-ও মহিলা সদস্যের তথ্য দেখার সুযোগ পাবেন না — এটি ডেটাবেস স্তরেই নিশ্চিত করা হয়েছে।'**
  String get onb_female_privacy;

  /// No description provided for @onb_step3_title.
  ///
  /// In bn, this message translates to:
  /// **'অবস্থান ও মাযহাব'**
  String get onb_step3_title;

  /// No description provided for @onb_city.
  ///
  /// In bn, this message translates to:
  /// **'শহর'**
  String get onb_city;

  /// No description provided for @onb_city_search.
  ///
  /// In bn, this message translates to:
  /// **'শহরের নাম লিখুন…'**
  String get onb_city_search;

  /// No description provided for @onb_madhhab.
  ///
  /// In bn, this message translates to:
  /// **'মাযহাব (আসর)'**
  String get onb_madhhab;

  /// No description provided for @onb_method.
  ///
  /// In bn, this message translates to:
  /// **'হিসাব পদ্ধতি'**
  String get onb_method;

  /// No description provided for @onb_custom_location.
  ///
  /// In bn, this message translates to:
  /// **'নিজের অক্ষাংশ-দ্রাঘিমাংশ'**
  String get onb_custom_location;

  /// No description provided for @onb_lat.
  ///
  /// In bn, this message translates to:
  /// **'অক্ষাংশ'**
  String get onb_lat;

  /// No description provided for @onb_lng.
  ///
  /// In bn, this message translates to:
  /// **'দ্রাঘিমাংশ'**
  String get onb_lng;

  /// No description provided for @onb_start.
  ///
  /// In bn, this message translates to:
  /// **'শুরু করুন — গেস্ট হিসেবে'**
  String get onb_start;

  /// No description provided for @onb_signin.
  ///
  /// In bn, this message translates to:
  /// **'সাইন ইন'**
  String get onb_signin;

  /// No description provided for @auth_title.
  ///
  /// In bn, this message translates to:
  /// **'ফোন দিয়ে সাইন ইন'**
  String get auth_title;

  /// No description provided for @auth_phone.
  ///
  /// In bn, this message translates to:
  /// **'মোবাইল নম্বর'**
  String get auth_phone;

  /// No description provided for @auth_phone_hint.
  ///
  /// In bn, this message translates to:
  /// **'০১XXXXXXXXX'**
  String get auth_phone_hint;

  /// No description provided for @auth_request_otp.
  ///
  /// In bn, this message translates to:
  /// **'কোড পাঠান'**
  String get auth_request_otp;

  /// No description provided for @auth_otp.
  ///
  /// In bn, this message translates to:
  /// **'ভেরিফিকেশন কোড'**
  String get auth_otp;

  /// No description provided for @auth_verify.
  ///
  /// In bn, this message translates to:
  /// **'যাচাই করুন'**
  String get auth_verify;

  /// No description provided for @auth_dev_code.
  ///
  /// In bn, this message translates to:
  /// **'ডেভ কোড'**
  String get auth_dev_code;

  /// No description provided for @auth_signout.
  ///
  /// In bn, this message translates to:
  /// **'সাইন আউট'**
  String get auth_signout;

  /// No description provided for @auth_guest_note.
  ///
  /// In bn, this message translates to:
  /// **'গেস্ট হিসেবে থাকলে আমল শুধু এই ফোনে সেভ থাকবে। সাইন ইন করলে সব একসাথে চলে আসবে।'**
  String get auth_guest_note;

  /// No description provided for @auth_invalid_phone.
  ///
  /// In bn, this message translates to:
  /// **'সঠিক মোবাইল নম্বর দিন'**
  String get auth_invalid_phone;

  /// No description provided for @auth_google.
  ///
  /// In bn, this message translates to:
  /// **'Google দিয়ে সাইন ইন'**
  String get auth_google;

  /// No description provided for @auth_apple.
  ///
  /// In bn, this message translates to:
  /// **'Apple দিয়ে সাইন ইন'**
  String get auth_apple;

  /// No description provided for @auth_or.
  ///
  /// In bn, this message translates to:
  /// **'অথবা'**
  String get auth_or;

  /// No description provided for @auth_social_error.
  ///
  /// In bn, this message translates to:
  /// **'সাইন-ইন ব্যর্থ হয়েছে — আবার চেষ্টা করুন'**
  String get auth_social_error;

  /// No description provided for @complete_profile_title.
  ///
  /// In bn, this message translates to:
  /// **'প্রোফাইল সম্পূর্ণ করুন'**
  String get complete_profile_title;

  /// No description provided for @complete_profile_note.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাকাউন্ট চালু করতে নাম ও লিঙ্গ দিন। লিঙ্গ একবার দেওয়ার পর আর পরিবর্তন করা যায় না।'**
  String get complete_profile_note;

  /// No description provided for @prayer_next.
  ///
  /// In bn, this message translates to:
  /// **'পরবর্তী ওয়াক্ত'**
  String get prayer_next;

  /// No description provided for @prayer_remaining.
  ///
  /// In bn, this message translates to:
  /// **'বাকি'**
  String get prayer_remaining;

  /// No description provided for @prayer_schedule.
  ///
  /// In bn, this message translates to:
  /// **'আজকের সময়সূচি'**
  String get prayer_schedule;

  /// No description provided for @prayer_current.
  ///
  /// In bn, this message translates to:
  /// **'চলছে'**
  String get prayer_current;

  /// No description provided for @prayer_forbidden_times.
  ///
  /// In bn, this message translates to:
  /// **'নিষিদ্ধ সময় — নামাজ পড়া নিষেধ'**
  String get prayer_forbidden_times;

  /// No description provided for @prayer_forbidden_sunrise.
  ///
  /// In bn, this message translates to:
  /// **'সূর্যোদয় ওঠা-নামার সময়'**
  String get prayer_forbidden_sunrise;

  /// No description provided for @prayer_forbidden_zawal.
  ///
  /// In bn, this message translates to:
  /// **'যাওয়াল — সূর্য মাথার উপর'**
  String get prayer_forbidden_zawal;

  /// No description provided for @prayer_forbidden_sunset.
  ///
  /// In bn, this message translates to:
  /// **'সূর্যাস্তের সময়'**
  String get prayer_forbidden_sunset;

  /// No description provided for @prayer_bell_hint.
  ///
  /// In bn, this message translates to:
  /// **'ঘণ্টি চাপুন — এই ওয়াক্তের আগে নোটিফিকেশন'**
  String get prayer_bell_hint;

  /// No description provided for @prayer_bell_on.
  ///
  /// In bn, this message translates to:
  /// **'ঘণ্টি চালু আছে'**
  String get prayer_bell_on;

  /// No description provided for @prayer_prompt_title.
  ///
  /// In bn, this message translates to:
  /// **'আপনার নামাজ হয়েছে?'**
  String get prayer_prompt_title;

  /// No description provided for @prayer_prompt_done_jamaat.
  ///
  /// In bn, this message translates to:
  /// **'জামাতে হয়েছে'**
  String get prayer_prompt_done_jamaat;

  /// No description provided for @prayer_post_salat.
  ///
  /// In bn, this message translates to:
  /// **'নামাজের পরের আমল লিখে ফেলুন — ২০ মিনিট আগেই জিজ্ঞেস করেছিলাম'**
  String get prayer_post_salat;

  /// No description provided for @amal_today.
  ///
  /// In bn, this message translates to:
  /// **'আজকের আমল'**
  String get amal_today;

  /// No description provided for @amal_month.
  ///
  /// In bn, this message translates to:
  /// **'মাসের গ্রিড'**
  String get amal_month;

  /// No description provided for @amal_jamaat.
  ///
  /// In bn, this message translates to:
  /// **'জামাতে'**
  String get amal_jamaat;

  /// No description provided for @amal_alone.
  ///
  /// In bn, this message translates to:
  /// **'একা'**
  String get amal_alone;

  /// No description provided for @amal_qaza.
  ///
  /// In bn, this message translates to:
  /// **'কাযা'**
  String get amal_qaza;

  /// No description provided for @amal_locked.
  ///
  /// In bn, this message translates to:
  /// **'লক'**
  String get amal_locked;

  /// No description provided for @amal_locked_msg.
  ///
  /// In bn, this message translates to:
  /// **'এই দিনের আমল লক হয়ে গেছে — পরের দিন ইশরাকের পর দিন বন্ধ হয়।'**
  String get amal_locked_msg;

  /// No description provided for @amal_unlock_request.
  ///
  /// In bn, this message translates to:
  /// **'আনলক চাই'**
  String get amal_unlock_request;

  /// No description provided for @amal_unlock_requested.
  ///
  /// In bn, this message translates to:
  /// **'উসরা প্রধানকে আনলকের অনুরোধ পাঠানো হয়েছে'**
  String get amal_unlock_requested;

  /// No description provided for @amal_streak.
  ///
  /// In bn, this message translates to:
  /// **'ধারাবাহিকতা'**
  String get amal_streak;

  /// No description provided for @amal_days.
  ///
  /// In bn, this message translates to:
  /// **'দিন'**
  String get amal_days;

  /// No description provided for @amal_sync_pending.
  ///
  /// In bn, this message translates to:
  /// **'টি পরিবর্তন সিঙ্ক বাকি'**
  String get amal_sync_pending;

  /// No description provided for @amal_synced.
  ///
  /// In bn, this message translates to:
  /// **'সব সিঙ্ক হয়েছে'**
  String get amal_synced;

  /// No description provided for @amal_completion.
  ///
  /// In bn, this message translates to:
  /// **'সম্পন্নতা'**
  String get amal_completion;

  /// No description provided for @amal_habit_builder.
  ///
  /// In bn, this message translates to:
  /// **'অভ্যাস গড়ার চ্যালেঞ্জ'**
  String get amal_habit_builder;

  /// No description provided for @amal_habit_builder_desc.
  ///
  /// In bn, this message translates to:
  /// **'৭ দিন ধরে প্রতিদিন একটি আমল — স্ট্রিক ধরে রাখুন'**
  String get amal_habit_builder_desc;

  /// No description provided for @amal_self_test.
  ///
  /// In bn, this message translates to:
  /// **'ইমান ও তাকওয়া সেলফ-টেস্ট'**
  String get amal_self_test;

  /// No description provided for @amal_no_defs.
  ///
  /// In bn, this message translates to:
  /// **'আমল ক্যাটালগ খালি — সাইন ইন করলে সম্পূর্ণ তালিকা আসবে'**
  String get amal_no_defs;

  /// No description provided for @amal_target_reached.
  ///
  /// In bn, this message translates to:
  /// **'লক্ষ্য পূরণ'**
  String get amal_target_reached;

  /// No description provided for @amal_locked_icon.
  ///
  /// In bn, this message translates to:
  /// **'🔒 লক'**
  String get amal_locked_icon;

  /// No description provided for @dawah_member_code.
  ///
  /// In bn, this message translates to:
  /// **'আমার মেম্বার কোড'**
  String get dawah_member_code;

  /// No description provided for @dawah_referral.
  ///
  /// In bn, this message translates to:
  /// **'রেফারেল লিংক'**
  String get dawah_referral;

  /// No description provided for @dawah_madu.
  ///
  /// In bn, this message translates to:
  /// **'আমার মাদউ'**
  String get dawah_madu;

  /// No description provided for @dawah_invited.
  ///
  /// In bn, this message translates to:
  /// **'মোট দাওয়াত দিয়েছি'**
  String get dawah_invited;

  /// No description provided for @dawah_usrah.
  ///
  /// In bn, this message translates to:
  /// **'আমার উসরা'**
  String get dawah_usrah;

  /// No description provided for @dawah_usrah_head.
  ///
  /// In bn, this message translates to:
  /// **'উসরা প্রধান'**
  String get dawah_usrah_head;

  /// No description provided for @dawah_members.
  ///
  /// In bn, this message translates to:
  /// **'সদস্য'**
  String get dawah_members;

  /// No description provided for @dawah_announcements.
  ///
  /// In bn, this message translates to:
  /// **'ঘোষণা ও প্রশ্ন'**
  String get dawah_announcements;

  /// No description provided for @dawah_reviews.
  ///
  /// In bn, this message translates to:
  /// **'সাপ্তাহিক রিভিউ ইতিহাস'**
  String get dawah_reviews;

  /// No description provided for @dawah_my_level.
  ///
  /// In bn, this message translates to:
  /// **'আমার স্তর'**
  String get dawah_my_level;

  /// No description provided for @dawah_months_in_level.
  ///
  /// In bn, this message translates to:
  /// **'এই স্তরে মাস'**
  String get dawah_months_in_level;

  /// No description provided for @dawah_requirements.
  ///
  /// In bn, this message translates to:
  /// **'উন্নতির শর্তাবলি'**
  String get dawah_requirements;

  /// No description provided for @dawah_next_level.
  ///
  /// In bn, this message translates to:
  /// **'পরবর্তী স্তর'**
  String get dawah_next_level;

  /// No description provided for @dawah_assessments.
  ///
  /// In bn, this message translates to:
  /// **'মূল্যায়নের ইতিহাস'**
  String get dawah_assessments;

  /// No description provided for @dawah_level_none_next.
  ///
  /// In bn, this message translates to:
  /// **'দায়ী হিসেবে নিজেকে গড়ে তুলুন — মেম্বার কোড শেয়ার করে দাওয়াত দিন'**
  String get dawah_level_none_next;

  /// No description provided for @ilm_quran.
  ///
  /// In bn, this message translates to:
  /// **'আল-কুরআন'**
  String get ilm_quran;

  /// No description provided for @ilm_adhkar.
  ///
  /// In bn, this message translates to:
  /// **'আযকার'**
  String get ilm_adhkar;

  /// No description provided for @ilm_duas.
  ///
  /// In bn, this message translates to:
  /// **'দোয়া ভাণ্ডার'**
  String get ilm_duas;

  /// No description provided for @ilm_names99.
  ///
  /// In bn, this message translates to:
  /// **'আল্লাহর ৯৯ নাম'**
  String get ilm_names99;

  /// No description provided for @ilm_baby_names.
  ///
  /// In bn, this message translates to:
  /// **'ইসলামিক নাম'**
  String get ilm_baby_names;

  /// No description provided for @ilm_iman_branches.
  ///
  /// In bn, this message translates to:
  /// **'ঈমানের ৭০ শাখা'**
  String get ilm_iman_branches;

  /// No description provided for @ilm_sunnahs.
  ///
  /// In bn, this message translates to:
  /// **'সুন্নাহ ও বিস্মৃত সুন্নাহ'**
  String get ilm_sunnahs;

  /// No description provided for @ilm_articles.
  ///
  /// In bn, this message translates to:
  /// **'আর্টিকেল'**
  String get ilm_articles;

  /// No description provided for @quran_reader.
  ///
  /// In bn, this message translates to:
  /// **'কুরআন পড়ুন'**
  String get quran_reader;

  /// No description provided for @quran_translation_toggle.
  ///
  /// In bn, this message translates to:
  /// **'বাংলা অনুবাদ'**
  String get quran_translation_toggle;

  /// No description provided for @quran_bookmark.
  ///
  /// In bn, this message translates to:
  /// **'বুকমার্ক'**
  String get quran_bookmark;

  /// No description provided for @quran_resume.
  ///
  /// In bn, this message translates to:
  /// **'শেষ পড়া থেকে শুরু করুন'**
  String get quran_resume;

  /// No description provided for @quran_tilawat_logged.
  ///
  /// In bn, this message translates to:
  /// **'তিলাওয়াত আমলনামায় যোগ হয়েছে'**
  String get quran_tilawat_logged;

  /// No description provided for @adhkar_morning.
  ///
  /// In bn, this message translates to:
  /// **'সকালের আযকার'**
  String get adhkar_morning;

  /// No description provided for @adhkar_evening.
  ///
  /// In bn, this message translates to:
  /// **'সন্ধ্যার আযকার'**
  String get adhkar_evening;

  /// No description provided for @adhkar_complete.
  ///
  /// In bn, this message translates to:
  /// **'সেট সম্পূর্ণ — আমলনামায় টিক দেওয়া হলো'**
  String get adhkar_complete;

  /// No description provided for @adhkar_tap_count.
  ///
  /// In bn, this message translates to:
  /// **'গণনার জন্য চাপুন'**
  String get adhkar_tap_count;

  /// No description provided for @names_boy.
  ///
  /// In bn, this message translates to:
  /// **'ছেলে'**
  String get names_boy;

  /// No description provided for @names_girl.
  ///
  /// In bn, this message translates to:
  /// **'মেয়ে'**
  String get names_girl;

  /// No description provided for @quiz_start.
  ///
  /// In bn, this message translates to:
  /// **'শুরু করুন'**
  String get quiz_start;

  /// No description provided for @quiz_result.
  ///
  /// In bn, this message translates to:
  /// **'ফলাফল'**
  String get quiz_result;

  /// No description provided for @quiz_correct.
  ///
  /// In bn, this message translates to:
  /// **'সঠিক!'**
  String get quiz_correct;

  /// No description provided for @quiz_wrong.
  ///
  /// In bn, this message translates to:
  /// **'ভুল'**
  String get quiz_wrong;

  /// No description provided for @quiz_retry.
  ///
  /// In bn, this message translates to:
  /// **'আবার দিন'**
  String get quiz_retry;

  /// No description provided for @more_zakat.
  ///
  /// In bn, this message translates to:
  /// **'যাকাত ক্যালকুলেটর'**
  String get more_zakat;

  /// No description provided for @more_qibla.
  ///
  /// In bn, this message translates to:
  /// **'কিবলা কম্পাস'**
  String get more_qibla;

  /// No description provided for @more_mosque.
  ///
  /// In bn, this message translates to:
  /// **'আমার মসজিদ'**
  String get more_mosque;

  /// No description provided for @more_masala.
  ///
  /// In bn, this message translates to:
  /// **'মাসআলা জিজ্ঞাসা'**
  String get more_masala;

  /// No description provided for @more_live.
  ///
  /// In bn, this message translates to:
  /// **'লাইভ প্রোগ্রাম'**
  String get more_live;

  /// No description provided for @more_faq.
  ///
  /// In bn, this message translates to:
  /// **'জিজ্ঞাসা (FAQ)'**
  String get more_faq;

  /// No description provided for @more_about.
  ///
  /// In bn, this message translates to:
  /// **'আমাদের সম্পর্কে'**
  String get more_about;

  /// No description provided for @more_feedback.
  ///
  /// In bn, this message translates to:
  /// **'মতামত দিন'**
  String get more_feedback;

  /// No description provided for @more_profile.
  ///
  /// In bn, this message translates to:
  /// **'প্রোফাইল'**
  String get more_profile;

  /// No description provided for @zakat_gold.
  ///
  /// In bn, this message translates to:
  /// **'স্বর্ণ (গ্রাম)'**
  String get zakat_gold;

  /// No description provided for @zakat_silver.
  ///
  /// In bn, this message translates to:
  /// **'রূপা (গ্রাম)'**
  String get zakat_silver;

  /// No description provided for @zakat_cash.
  ///
  /// In bn, this message translates to:
  /// **'নগদ ও ব্যাংক'**
  String get zakat_cash;

  /// No description provided for @zakat_investments.
  ///
  /// In bn, this message translates to:
  /// **'ব্যবসা ও বিনিয়োগ'**
  String get zakat_investments;

  /// No description provided for @zakat_debts.
  ///
  /// In bn, this message translates to:
  /// **'ঋণ (বাদ যাবে)'**
  String get zakat_debts;

  /// No description provided for @zakat_nisab.
  ///
  /// In bn, this message translates to:
  /// **'নিসাব (৮৫ গ্রাম স্বর্ণ)'**
  String get zakat_nisab;

  /// No description provided for @zakat_payable.
  ///
  /// In bn, this message translates to:
  /// **'যাকাত দিতে হবে'**
  String get zakat_payable;

  /// No description provided for @zakat_below_nisab.
  ///
  /// In bn, this message translates to:
  /// **'নিসাব পরিমাণ সম্পদ নেই — যাকাত ফরজ নয়'**
  String get zakat_below_nisab;

  /// No description provided for @zakat_donate.
  ///
  /// In bn, this message translates to:
  /// **'দান করুন'**
  String get zakat_donate;

  /// No description provided for @qibla_distance.
  ///
  /// In bn, this message translates to:
  /// **'কাবা থেকে দূরত্ব'**
  String get qibla_distance;

  /// No description provided for @qibla_note.
  ///
  /// In bn, this message translates to:
  /// **'ফোন সমতলে ধরে উত্তর দিক ঠিক করে নিন, তারপর তীরের দিকে মুখ করুন'**
  String get qibla_note;

  /// No description provided for @masala_question.
  ///
  /// In bn, this message translates to:
  /// **'আপনার প্রশ্ন লিখুন'**
  String get masala_question;

  /// No description provided for @masala_your_name.
  ///
  /// In bn, this message translates to:
  /// **'আপনার নাম'**
  String get masala_your_name;

  /// No description provided for @masala_sent.
  ///
  /// In bn, this message translates to:
  /// **'প্রশ্ন পাঠানো হয়েছে — মুফতি সাহেব উত্তর দিলে জানানো হবে'**
  String get masala_sent;

  /// No description provided for @feedback_sent.
  ///
  /// In bn, this message translates to:
  /// **'ধন্যবাদ! মতামত পাঠানো হয়েছে'**
  String get feedback_sent;

  /// No description provided for @live_now.
  ///
  /// In bn, this message translates to:
  /// **'এখন লাইভ'**
  String get live_now;

  /// No description provided for @live_upcoming.
  ///
  /// In bn, this message translates to:
  /// **'আসছে'**
  String get live_upcoming;

  /// No description provided for @live_past.
  ///
  /// In bn, this message translates to:
  /// **'সমাপ্ত'**
  String get live_past;

  /// No description provided for @live_notify.
  ///
  /// In bn, this message translates to:
  /// **'মনে করিয়ে দিন'**
  String get live_notify;

  /// No description provided for @profile_theme.
  ///
  /// In bn, this message translates to:
  /// **'থিম'**
  String get profile_theme;

  /// No description provided for @profile_theme_light.
  ///
  /// In bn, this message translates to:
  /// **'লাইট'**
  String get profile_theme_light;

  /// No description provided for @profile_theme_dark.
  ///
  /// In bn, this message translates to:
  /// **'ডার্ক'**
  String get profile_theme_dark;

  /// No description provided for @profile_theme_system.
  ///
  /// In bn, this message translates to:
  /// **'সিস্টেম'**
  String get profile_theme_system;

  /// No description provided for @profile_language.
  ///
  /// In bn, this message translates to:
  /// **'ভাষা'**
  String get profile_language;

  /// No description provided for @profile_category.
  ///
  /// In bn, this message translates to:
  /// **'ক্যাটাগরি'**
  String get profile_category;

  /// No description provided for @profile_category_general.
  ///
  /// In bn, this message translates to:
  /// **'সাধারণ'**
  String get profile_category_general;

  /// No description provided for @profile_category_hafez.
  ///
  /// In bn, this message translates to:
  /// **'হাফেজ'**
  String get profile_category_hafez;

  /// No description provided for @profile_category_alim.
  ///
  /// In bn, this message translates to:
  /// **'আলেম'**
  String get profile_category_alim;

  /// No description provided for @profile_female_privacy_title.
  ///
  /// In bn, this message translates to:
  /// **'বোনদের গোপনীয়তার নিশ্চয়তা'**
  String get profile_female_privacy_title;

  /// No description provided for @app_about.
  ///
  /// In bn, this message translates to:
  /// **'সুন্নাহ লাইফ — আস-সুন্নাহ ফাউন্ডেশনের দাওয়াতুস সুন্নাহ বিভাগের পক্ষ থেকে। নামাজ, আমল, ইলম আর তারবিয়াত — সব এক অ্যাপে।'**
  String get app_about;

  /// No description provided for @today_vs.
  ///
  /// In bn, this message translates to:
  /// **'আজ'**
  String get today_vs;

  /// No description provided for @today_progress.
  ///
  /// In bn, this message translates to:
  /// **'আজকের অগ্রগতি'**
  String get today_progress;

  /// No description provided for @month_prev.
  ///
  /// In bn, this message translates to:
  /// **'আগের মাস'**
  String get month_prev;

  /// No description provided for @month_next.
  ///
  /// In bn, this message translates to:
  /// **'পরের মাস'**
  String get month_next;

  /// No description provided for @day_detail.
  ///
  /// In bn, this message translates to:
  /// **'দিনের বিবরণ'**
  String get day_detail;

  /// No description provided for @habit_pick.
  ///
  /// In bn, this message translates to:
  /// **'আমল বাছুন'**
  String get habit_pick;

  /// No description provided for @tilawat_session.
  ///
  /// In bn, this message translates to:
  /// **'তিলাওয়াত সেশন'**
  String get tilawat_session;

  /// No description provided for @tilawat_minutes.
  ///
  /// In bn, this message translates to:
  /// **'মিনিট পড়েছেন'**
  String get tilawat_minutes;

  /// No description provided for @tilawat_pages.
  ///
  /// In bn, this message translates to:
  /// **'পৃষ্ঠা হিসেবে লিখুন'**
  String get tilawat_pages;

  /// No description provided for @dawah_gate_title.
  ///
  /// In bn, this message translates to:
  /// **'দাওয়াত কেন্দ্র'**
  String get dawah_gate_title;

  /// No description provided for @dawah_signin_needed.
  ///
  /// In bn, this message translates to:
  /// **'দাওয়াত কেন্দ্র ব্যবহার করতে সাইন ইন করুন — দায়ী, উসরা প্রধান ও পরিদর্শকদের জন্য।'**
  String get dawah_signin_needed;

  /// No description provided for @dawah_role_needed.
  ///
  /// In bn, this message translates to:
  /// **'এই অংশটি দায়ী ও তত্ত্বাবধায়কদের জন্য। আপনার একাউন্টে এখনো দায়ীর ভূমিকা নেই।'**
  String get dawah_role_needed;

  /// No description provided for @quran_surahs.
  ///
  /// In bn, this message translates to:
  /// **'সূরা'**
  String get quran_surahs;

  /// No description provided for @quran_ayahs.
  ///
  /// In bn, this message translates to:
  /// **'আয়াত'**
  String get quran_ayahs;

  /// No description provided for @quran_bismillah.
  ///
  /// In bn, this message translates to:
  /// **'বিসমিল্লাহির রাহমানির রাহীম'**
  String get quran_bismillah;

  /// No description provided for @more_share_app.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাপ শেয়ার করুন'**
  String get more_share_app;

  /// No description provided for @more_share_text.
  ///
  /// In bn, this message translates to:
  /// **'সুন্নাহ লাইফ — নামাজের সময়, আমলনামা, কুরআন আর তারবিয়াত এক অ্যাপে। https://sunnahlife.app'**
  String get more_share_text;

  /// No description provided for @send.
  ///
  /// In bn, this message translates to:
  /// **'পাঠান'**
  String get send;

  /// No description provided for @not_available_offline.
  ///
  /// In bn, this message translates to:
  /// **'এই অংশে ইন্টারনেট লাগবে — অনুগ্রহ করে সংযোগ দিন'**
  String get not_available_offline;

  /// No description provided for @categories.
  ///
  /// In bn, this message translates to:
  /// **'ক্যাটাগরি'**
  String get categories;

  /// No description provided for @exact_alarm_title.
  ///
  /// In bn, this message translates to:
  /// **'নামাজের নিখুঁত অ্যালার্ম'**
  String get exact_alarm_title;

  /// No description provided for @exact_alarm_desc.
  ///
  /// In bn, this message translates to:
  /// **'ফোন ঘুমিয়ে থাকলেও ঠিক সময়ে ঘণ্টি বাজাতে অনুমতি দিন।'**
  String get exact_alarm_desc;

  /// No description provided for @exact_alarm_grant.
  ///
  /// In bn, this message translates to:
  /// **'অনুমতি দিন'**
  String get exact_alarm_grant;

  /// No description provided for @hijri_adjust.
  ///
  /// In bn, this message translates to:
  /// **'হিজরি সমন্বয় (দিন)'**
  String get hijri_adjust;

  /// No description provided for @prayer_please_login.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাকাউন্টে সেভ হবে'**
  String get prayer_please_login;

  /// No description provided for @all_set.
  ///
  /// In bn, this message translates to:
  /// **'সব ঠিক আছে'**
  String get all_set;

  /// No description provided for @app_title.
  ///
  /// In bn, this message translates to:
  /// **'সুন্নাহ লাইফ'**
  String get app_title;

  /// No description provided for @boot_failed.
  ///
  /// In bn, this message translates to:
  /// **'শুরু করা যায়নি'**
  String get boot_failed;

  /// No description provided for @org_footer.
  ///
  /// In bn, this message translates to:
  /// **'আস-সুন্নাহ ফাউন্ডেশন · দাওয়াতুস সুন্নাহ'**
  String get org_footer;

  /// No description provided for @onb_org.
  ///
  /// In bn, this message translates to:
  /// **'আস-সুন্নাহ ফাউন্ডেশন — দাওয়াতুস সুন্নাহ'**
  String get onb_org;

  /// No description provided for @onb_bismillah_start.
  ///
  /// In bn, this message translates to:
  /// **'বিসমিল্লাহ — শুরু করুন'**
  String get onb_bismillah_start;

  /// No description provided for @onb_bd_defaults.
  ///
  /// In bn, this message translates to:
  /// **'বাংলাদেশের জন্য ডিফল্ট: করাচি পদ্ধতি ও হানাফি আসর। সব হিসাব আপনার ফোনেই হয় — ইন্টারনেট ছাড়াও কাজ করবে।'**
  String get onb_bd_defaults;

  /// No description provided for @lang_desc_bn.
  ///
  /// In bn, this message translates to:
  /// **'বাংলাদেশের প্রধান ভাষা'**
  String get lang_desc_bn;

  /// No description provided for @lang_desc_en.
  ///
  /// In bn, this message translates to:
  /// **'ইংরেজি'**
  String get lang_desc_en;

  /// No description provided for @lang_desc_ar.
  ///
  /// In bn, this message translates to:
  /// **'আরবি — ডান থেকে বাম'**
  String get lang_desc_ar;

  /// No description provided for @country_bd.
  ///
  /// In bn, this message translates to:
  /// **'বাংলাদেশ'**
  String get country_bd;

  /// No description provided for @country_abroad.
  ///
  /// In bn, this message translates to:
  /// **'বিদেশ'**
  String get country_abroad;

  /// No description provided for @country_intl.
  ///
  /// In bn, this message translates to:
  /// **'আন্তর্জাতিক'**
  String get country_intl;

  /// No description provided for @city_picker_title.
  ///
  /// In bn, this message translates to:
  /// **'শহর নির্বাচন করুন'**
  String get city_picker_title;

  /// No description provided for @city_no_match.
  ///
  /// In bn, this message translates to:
  /// **'কোনো শহর মেলেনি — বানান দেখে নিন বা মূল তালিকা থেকে বাছুন'**
  String get city_no_match;

  /// No description provided for @waqt_fajr.
  ///
  /// In bn, this message translates to:
  /// **'ফজর'**
  String get waqt_fajr;

  /// No description provided for @waqt_sunrise.
  ///
  /// In bn, this message translates to:
  /// **'সূর্যোদয়'**
  String get waqt_sunrise;

  /// No description provided for @waqt_ishraq.
  ///
  /// In bn, this message translates to:
  /// **'ইশরাক'**
  String get waqt_ishraq;

  /// No description provided for @waqt_duha.
  ///
  /// In bn, this message translates to:
  /// **'দুহা'**
  String get waqt_duha;

  /// No description provided for @waqt_dhuhr.
  ///
  /// In bn, this message translates to:
  /// **'যোহর'**
  String get waqt_dhuhr;

  /// No description provided for @waqt_asr.
  ///
  /// In bn, this message translates to:
  /// **'আসর'**
  String get waqt_asr;

  /// No description provided for @waqt_maghrib.
  ///
  /// In bn, this message translates to:
  /// **'মাগরিব'**
  String get waqt_maghrib;

  /// No description provided for @waqt_sunset.
  ///
  /// In bn, this message translates to:
  /// **'সূর্যাস্ত'**
  String get waqt_sunset;

  /// No description provided for @waqt_isha.
  ///
  /// In bn, this message translates to:
  /// **'এশা'**
  String get waqt_isha;

  /// No description provided for @waqt_tahajjud.
  ///
  /// In bn, this message translates to:
  /// **'তাহাজ্জুদ'**
  String get waqt_tahajjud;

  /// No description provided for @month_1.
  ///
  /// In bn, this message translates to:
  /// **'জানুয়ারি'**
  String get month_1;

  /// No description provided for @month_2.
  ///
  /// In bn, this message translates to:
  /// **'ফেব্রুয়ারি'**
  String get month_2;

  /// No description provided for @month_3.
  ///
  /// In bn, this message translates to:
  /// **'মার্চ'**
  String get month_3;

  /// No description provided for @month_4.
  ///
  /// In bn, this message translates to:
  /// **'এপ্রিল'**
  String get month_4;

  /// No description provided for @month_5.
  ///
  /// In bn, this message translates to:
  /// **'মে'**
  String get month_5;

  /// No description provided for @month_6.
  ///
  /// In bn, this message translates to:
  /// **'জুন'**
  String get month_6;

  /// No description provided for @month_7.
  ///
  /// In bn, this message translates to:
  /// **'জুলাই'**
  String get month_7;

  /// No description provided for @month_8.
  ///
  /// In bn, this message translates to:
  /// **'আগস্ট'**
  String get month_8;

  /// No description provided for @month_9.
  ///
  /// In bn, this message translates to:
  /// **'সেপ্টেম্বর'**
  String get month_9;

  /// No description provided for @month_10.
  ///
  /// In bn, this message translates to:
  /// **'অক্টোবর'**
  String get month_10;

  /// No description provided for @month_11.
  ///
  /// In bn, this message translates to:
  /// **'নভেম্বর'**
  String get month_11;

  /// No description provided for @month_12.
  ///
  /// In bn, this message translates to:
  /// **'ডিসেম্বর'**
  String get month_12;

  /// No description provided for @prayer_offline_chip.
  ///
  /// In bn, this message translates to:
  /// **'সব হিসাব অফলাইনে আপনার ফোনেই হয়'**
  String get prayer_offline_chip;

  /// No description provided for @prayer_bell_enable.
  ///
  /// In bn, this message translates to:
  /// **'ঘণ্টি চালু করুন'**
  String get prayer_bell_enable;

  /// No description provided for @prayer_bell_disable.
  ///
  /// In bn, this message translates to:
  /// **'ঘণ্টি বন্ধ করুন'**
  String get prayer_bell_disable;

  /// No description provided for @role_user.
  ///
  /// In bn, this message translates to:
  /// **'সাধারণ ব্যবহারকারী'**
  String get role_user;

  /// No description provided for @role_daee.
  ///
  /// In bn, this message translates to:
  /// **'দায়ী'**
  String get role_daee;

  /// No description provided for @role_usrah_head.
  ///
  /// In bn, this message translates to:
  /// **'উসরা প্রধান'**
  String get role_usrah_head;

  /// No description provided for @role_invigilator.
  ///
  /// In bn, this message translates to:
  /// **'পরিদর্শক'**
  String get role_invigilator;

  /// No description provided for @role_full_admin.
  ///
  /// In bn, this message translates to:
  /// **'প্রধান অ্যাডমিন'**
  String get role_full_admin;

  /// No description provided for @level_none.
  ///
  /// In bn, this message translates to:
  /// **'শুরুর পর্যায়'**
  String get level_none;

  /// No description provided for @level_muhibbus_sunnah.
  ///
  /// In bn, this message translates to:
  /// **'মুহিব্বুস সুন্নাহ'**
  String get level_muhibbus_sunnah;

  /// No description provided for @level_farze_ain_1.
  ///
  /// In bn, this message translates to:
  /// **'ফরযে আইন — ক্যাটাগরি ১'**
  String get level_farze_ain_1;

  /// No description provided for @level_farze_ain_2.
  ///
  /// In bn, this message translates to:
  /// **'ফরযে আইন — ক্যাটাগরি ২'**
  String get level_farze_ain_2;

  /// No description provided for @madhhab_hanafi.
  ///
  /// In bn, this message translates to:
  /// **'হানাফি'**
  String get madhhab_hanafi;

  /// No description provided for @madhhab_shafii.
  ///
  /// In bn, this message translates to:
  /// **'শাফেয়ি'**
  String get madhhab_shafii;

  /// No description provided for @method_karachi.
  ///
  /// In bn, this message translates to:
  /// **'করাচি (১৮°/১৮°)'**
  String get method_karachi;

  /// No description provided for @method_mwl.
  ///
  /// In bn, this message translates to:
  /// **'মুসলিম ওয়ার্ল্ড লীগ'**
  String get method_mwl;

  /// No description provided for @method_isna.
  ///
  /// In bn, this message translates to:
  /// **'ISNA (উত্তর আমেরিকা)'**
  String get method_isna;

  /// No description provided for @method_egypt.
  ///
  /// In bn, this message translates to:
  /// **'মিসরীয়'**
  String get method_egypt;

  /// No description provided for @method_makkah.
  ///
  /// In bn, this message translates to:
  /// **'উম্মুল কুরা (মক্কা)'**
  String get method_makkah;

  /// No description provided for @method_dubai.
  ///
  /// In bn, this message translates to:
  /// **'দুবাই'**
  String get method_dubai;

  /// No description provided for @cat_salah.
  ///
  /// In bn, this message translates to:
  /// **'নামাজ'**
  String get cat_salah;

  /// No description provided for @cat_quran.
  ///
  /// In bn, this message translates to:
  /// **'কুরআন'**
  String get cat_quran;

  /// No description provided for @cat_dhikr.
  ///
  /// In bn, this message translates to:
  /// **'যিকর ও দোয়া'**
  String get cat_dhikr;

  /// No description provided for @cat_akhlaq.
  ///
  /// In bn, this message translates to:
  /// **'আখলাক'**
  String get cat_akhlaq;

  /// No description provided for @cat_dawat.
  ///
  /// In bn, this message translates to:
  /// **'দাওয়াত'**
  String get cat_dawat;

  /// No description provided for @cat_lifestyle.
  ///
  /// In bn, this message translates to:
  /// **'জীবনাচরণ'**
  String get cat_lifestyle;

  /// No description provided for @cat_sunnah.
  ///
  /// In bn, this message translates to:
  /// **'সাপ্তাহিক ও মাসিক সুন্নাহ'**
  String get cat_sunnah;

  /// No description provided for @cat_personal.
  ///
  /// In bn, this message translates to:
  /// **'ব্যক্তিগত লক্ষ্য'**
  String get cat_personal;

  /// No description provided for @target_label.
  ///
  /// In bn, this message translates to:
  /// **'লক্ষ্য'**
  String get target_label;

  /// No description provided for @amal_done.
  ///
  /// In bn, this message translates to:
  /// **'হয়েছে'**
  String get amal_done;

  /// No description provided for @amal_not_done.
  ///
  /// In bn, this message translates to:
  /// **'হয়নি'**
  String get amal_not_done;

  /// No description provided for @amal_auto_logged.
  ///
  /// In bn, this message translates to:
  /// **'স্বয়ংক্রিয়ভাবে লেখা হয়েছে'**
  String get amal_auto_logged;

  /// No description provided for @amal_unlock_reason.
  ///
  /// In bn, this message translates to:
  /// **'মোবাইল অ্যাপ থেকে অনুরোধ'**
  String get amal_unlock_reason;

  /// No description provided for @cadence_weekly_fri.
  ///
  /// In bn, this message translates to:
  /// **'শুক্রবার'**
  String get cadence_weekly_fri;

  /// No description provided for @cadence_weekly_mon_thu.
  ///
  /// In bn, this message translates to:
  /// **'সোম ও বৃহস্পতিবার'**
  String get cadence_weekly_mon_thu;

  /// No description provided for @cadence_ayyam_beez.
  ///
  /// In bn, this message translates to:
  /// **'আইয়ামে বীজ (১৩–১৫)'**
  String get cadence_ayyam_beez;

  /// No description provided for @tilawat_target_pages.
  ///
  /// In bn, this message translates to:
  /// **'পৃষ্ঠা'**
  String get tilawat_target_pages;

  /// No description provided for @tilawat_target_general.
  ///
  /// In bn, this message translates to:
  /// **'তিলাওয়াত: ১ পৃষ্ঠা'**
  String get tilawat_target_general;

  /// No description provided for @tilawat_target_hafez.
  ///
  /// In bn, this message translates to:
  /// **'তিলাওয়াত: ১ পারা'**
  String get tilawat_target_hafez;

  /// No description provided for @tilawat_target_alim.
  ///
  /// In bn, this message translates to:
  /// **'তিলাওয়াত: ১০ পৃষ্ঠা'**
  String get tilawat_target_alim;

  /// No description provided for @dawah_tab_usrah.
  ///
  /// In bn, this message translates to:
  /// **'উসরা'**
  String get dawah_tab_usrah;

  /// No description provided for @dawah_tab_reviews.
  ///
  /// In bn, this message translates to:
  /// **'রিভিউ'**
  String get dawah_tab_reviews;

  /// No description provided for @dawah_share_message.
  ///
  /// In bn, this message translates to:
  /// **'আসসালামু আলাইকুম। সুন্নাহ লাইফ অ্যাপে আমার সাথে যুক্ত হোন:'**
  String get dawah_share_message;

  /// No description provided for @dawah_no_usrah.
  ///
  /// In bn, this message translates to:
  /// **'আপনি এখনো কোনো উসরায় যুক্ত নন — অ্যাডমিন যুক্ত করলে এখানে দেখা যাবে'**
  String get dawah_no_usrah;

  /// No description provided for @dawah_no_reviews.
  ///
  /// In bn, this message translates to:
  /// **'এখনো কোনো সাপ্তাহিক রিভিউ হয়নি'**
  String get dawah_no_reviews;

  /// No description provided for @dawah_week.
  ///
  /// In bn, this message translates to:
  /// **'সপ্তাহ'**
  String get dawah_week;

  /// No description provided for @review_status_overdue.
  ///
  /// In bn, this message translates to:
  /// **'বিলম্বিত'**
  String get review_status_overdue;

  /// No description provided for @review_status_pending.
  ///
  /// In bn, this message translates to:
  /// **'অপেক্ষমাণ'**
  String get review_status_pending;

  /// No description provided for @badge_new.
  ///
  /// In bn, this message translates to:
  /// **'নতুন'**
  String get badge_new;

  /// No description provided for @quran_juz.
  ///
  /// In bn, this message translates to:
  /// **'জুয়'**
  String get quran_juz;

  /// No description provided for @sunnah_cat_all.
  ///
  /// In bn, this message translates to:
  /// **'সব'**
  String get sunnah_cat_all;

  /// No description provided for @sunnah_cat_daily.
  ///
  /// In bn, this message translates to:
  /// **'দৈনন্দিন সুন্নাহ'**
  String get sunnah_cat_daily;

  /// No description provided for @sunnah_cat_forgotten.
  ///
  /// In bn, this message translates to:
  /// **'বিস্মৃত সুন্নাহ'**
  String get sunnah_cat_forgotten;

  /// No description provided for @sunnah_cat_salah.
  ///
  /// In bn, this message translates to:
  /// **'নামাজের সুন্নাহ'**
  String get sunnah_cat_salah;

  /// No description provided for @iman_branch_heart.
  ///
  /// In bn, this message translates to:
  /// **'অন্তরের ঈমান'**
  String get iman_branch_heart;

  /// No description provided for @iman_branch_tongue.
  ///
  /// In bn, this message translates to:
  /// **'জবানের ঈমান'**
  String get iman_branch_tongue;

  /// No description provided for @iman_branch_body.
  ///
  /// In bn, this message translates to:
  /// **'দেহের ঈমান'**
  String get iman_branch_body;

  /// No description provided for @quiz_minutes.
  ///
  /// In bn, this message translates to:
  /// **'মিনিট'**
  String get quiz_minutes;

  /// No description provided for @quiz_questions.
  ///
  /// In bn, this message translates to:
  /// **'প্রশ্ন'**
  String get quiz_questions;

  /// No description provided for @quiz_great.
  ///
  /// In bn, this message translates to:
  /// **'আলহামদুলিল্লাহ — দুর্দান্ত!'**
  String get quiz_great;

  /// No description provided for @quiz_needs_more.
  ///
  /// In bn, this message translates to:
  /// **'আরও একটু পড়া দরকার — আবার চেষ্টা করুন'**
  String get quiz_needs_more;

  /// No description provided for @unit_km.
  ///
  /// In bn, this message translates to:
  /// **'কিমি'**
  String get unit_km;

  /// No description provided for @feedback_hint.
  ///
  /// In bn, this message translates to:
  /// **'আপনার মতামত লিখুন…'**
  String get feedback_hint;

  /// No description provided for @live_sisters_only.
  ///
  /// In bn, this message translates to:
  /// **'শুধু বোনদের সেশন'**
  String get live_sisters_only;

  /// No description provided for @live_host.
  ///
  /// In bn, this message translates to:
  /// **'উপস্থাপক'**
  String get live_host;

  /// No description provided for @live_will_remind.
  ///
  /// In bn, this message translates to:
  /// **'মনে করিয়ে দেওয়া হবে ইনশাআল্লাহ'**
  String get live_will_remind;

  /// No description provided for @qibla_north.
  ///
  /// In bn, this message translates to:
  /// **'উত্তর'**
  String get qibla_north;

  /// No description provided for @qibla_dial_hint.
  ///
  /// In bn, this message translates to:
  /// **'ডায়াল ঘোরান — তীরটি যেন উপরে থাকে'**
  String get qibla_dial_hint;

  /// No description provided for @qibla_dial.
  ///
  /// In bn, this message translates to:
  /// **'ডায়াল'**
  String get qibla_dial;

  /// No description provided for @masala_note.
  ///
  /// In bn, this message translates to:
  /// **'দ্বীনি মাসআলা লিখে জানান — মুফতি সাহেব ইনশাআল্লাহ উত্তর দিবেন।'**
  String get masala_note;

  /// No description provided for @masala_phone.
  ///
  /// In bn, this message translates to:
  /// **'মোবাইল (ঐচ্ছিক)'**
  String get masala_phone;

  /// No description provided for @masala_offline.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইনে পাঠানো যাবে না — ইন্টারনেট সংযোগ দরকার'**
  String get masala_offline;

  /// No description provided for @profile_app_section.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাপ'**
  String get profile_app_section;

  /// No description provided for @hijri_increase.
  ///
  /// In bn, this message translates to:
  /// **'হিজরি সমন্বয় বাড়ান'**
  String get hijri_increase;

  /// No description provided for @hijri_decrease.
  ///
  /// In bn, this message translates to:
  /// **'হিজরি সমন্বয় কমান'**
  String get hijri_decrease;

  /// No description provided for @gender_admin_only.
  ///
  /// In bn, this message translates to:
  /// **'শুধু অ্যাডমিন পরিবর্তন করতে পারেন'**
  String get gender_admin_only;

  /// No description provided for @increase.
  ///
  /// In bn, this message translates to:
  /// **'বাড়ান'**
  String get increase;

  /// No description provided for @decrease.
  ///
  /// In bn, this message translates to:
  /// **'কমান'**
  String get decrease;

  /// No description provided for @onb_setup.
  ///
  /// In bn, this message translates to:
  /// **'সেটআপ'**
  String get onb_setup;

  /// No description provided for @compass_n.
  ///
  /// In bn, this message translates to:
  /// **'উত্তর'**
  String get compass_n;

  /// No description provided for @compass_ne.
  ///
  /// In bn, this message translates to:
  /// **'উত্তর-পূর্ব'**
  String get compass_ne;

  /// No description provided for @compass_e.
  ///
  /// In bn, this message translates to:
  /// **'পূর্ব'**
  String get compass_e;

  /// No description provided for @compass_se.
  ///
  /// In bn, this message translates to:
  /// **'দক্ষিণ-পূর্ব'**
  String get compass_se;

  /// No description provided for @compass_s.
  ///
  /// In bn, this message translates to:
  /// **'দক্ষিণ'**
  String get compass_s;

  /// No description provided for @compass_sw.
  ///
  /// In bn, this message translates to:
  /// **'দক্ষিণ-পশ্চিম'**
  String get compass_sw;

  /// No description provided for @compass_w.
  ///
  /// In bn, this message translates to:
  /// **'পশ্চিম'**
  String get compass_w;

  /// No description provided for @compass_nw.
  ///
  /// In bn, this message translates to:
  /// **'উত্তর-পশ্চিম'**
  String get compass_nw;

  /// No description provided for @zakat_percent_note.
  ///
  /// In bn, this message translates to:
  /// **'সম্পদের ২.৫%'**
  String get zakat_percent_note;

  /// No description provided for @zakat_net.
  ///
  /// In bn, this message translates to:
  /// **'নেট'**
  String get zakat_net;

  /// No description provided for @zakat_donation_link.
  ///
  /// In bn, this message translates to:
  /// **'দানের লিংক'**
  String get zakat_donation_link;

  /// No description provided for @live_programs_count.
  ///
  /// In bn, this message translates to:
  /// **'টি প্রোগ্রাম'**
  String get live_programs_count;
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
      <String>['ar', 'bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
