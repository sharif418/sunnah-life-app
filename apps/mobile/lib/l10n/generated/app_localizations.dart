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
  /// **'৬ সংখ্যার কোড'**
  String get auth_otp;

  /// No description provided for @auth_verify.
  ///
  /// In bn, this message translates to:
  /// **'যাচাই করুন'**
  String get auth_verify;

  /// No description provided for @auth_dev_code.
  ///
  /// In bn, this message translates to:
  /// **'পরীক্ষামূলক কোড'**
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
  /// **'ঈমান ও তাকওয়া সেলফ-টেস্ট'**
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
  /// **'এই স্তরের লক্ষ্য'**
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

  /// No description provided for @quran_goto_ayah.
  ///
  /// In bn, this message translates to:
  /// **'আয়াতে যান'**
  String get quran_goto_ayah;

  /// No description provided for @quran_goto_ayah_hint.
  ///
  /// In bn, this message translates to:
  /// **'আয়াত নম্বর লিখুন'**
  String get quran_goto_ayah_hint;

  /// No description provided for @quran_invalid_ayah.
  ///
  /// In bn, this message translates to:
  /// **'আয়াত নম্বরটি সঠিক নয়'**
  String get quran_invalid_ayah;

  /// No description provided for @quran_reciter.
  ///
  /// In bn, this message translates to:
  /// **'বাদক নির্বাচন করুন'**
  String get quran_reciter;

  /// No description provided for @quran_play_ayah.
  ///
  /// In bn, this message translates to:
  /// **'আয়াত শুনুন'**
  String get quran_play_ayah;

  /// No description provided for @quran_stop_audio.
  ///
  /// In bn, this message translates to:
  /// **'অডিও বন্ধ করুন'**
  String get quran_stop_audio;

  /// No description provided for @quran_audio_error.
  ///
  /// In bn, this message translates to:
  /// **'অডিও চালানো যায়নি — ইন্টারনেট সংযোগ দেখে নিন'**
  String get quran_audio_error;

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
  /// **'হিজরি তারিখ সমন্বয়'**
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
  /// **'ফরযে আইন — ক্যাটাগরি ১'**
  String get level_farze_ain_1;

  /// No description provided for @level_farze_ain_2.
  ///
  /// In bn, this message translates to:
  /// **'ফরযে আইন — ক্যাটাগরি ২'**
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
  /// **'ডায়াল ঘুরিয়ে উ (N) চিহ্নটি উত্তর দিকে আনুন — তীর তখন কিবলার দিক দেখাবে'**
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

  /// No description provided for @ilm_courses.
  ///
  /// In bn, this message translates to:
  /// **'কোর্স'**
  String get ilm_courses;

  /// No description provided for @ilm_quizzes.
  ///
  /// In bn, this message translates to:
  /// **'কুইজ'**
  String get ilm_quizzes;

  /// No description provided for @ilm_live_quiz.
  ///
  /// In bn, this message translates to:
  /// **'লাইভ কুইজ'**
  String get ilm_live_quiz;

  /// No description provided for @course_lessons_unit.
  ///
  /// In bn, this message translates to:
  /// **'পাঠ'**
  String get course_lessons_unit;

  /// No description provided for @course_enrolled_unit.
  ///
  /// In bn, this message translates to:
  /// **'জন ভর্তি'**
  String get course_enrolled_unit;

  /// No description provided for @course_start.
  ///
  /// In bn, this message translates to:
  /// **'কোর্সটি শুরু করুন'**
  String get course_start;

  /// No description provided for @course_continue.
  ///
  /// In bn, this message translates to:
  /// **'চালিয়ে যান'**
  String get course_continue;

  /// No description provided for @course_enroll.
  ///
  /// In bn, this message translates to:
  /// **'কোর্সে ভর্তি হোন'**
  String get course_enroll;

  /// No description provided for @course_enrolled.
  ///
  /// In bn, this message translates to:
  /// **'ভর্তি আছেন'**
  String get course_enrolled;

  /// No description provided for @course_enrolling.
  ///
  /// In bn, this message translates to:
  /// **'ভর্তি হচ্ছে…'**
  String get course_enrolling;

  /// No description provided for @course_signin_to_enroll.
  ///
  /// In bn, this message translates to:
  /// **'কোর্সে ভর্তি হতে সাইন ইন করুন'**
  String get course_signin_to_enroll;

  /// No description provided for @course_progress_of.
  ///
  /// In bn, this message translates to:
  /// **'পাঠ সম্পন্ন'**
  String get course_progress_of;

  /// No description provided for @courses_empty_title.
  ///
  /// In bn, this message translates to:
  /// **'কোর্স শীঘ্রই আসছে, ইনশাআল্লাহ'**
  String get courses_empty_title;

  /// No description provided for @courses_empty_hint.
  ///
  /// In bn, this message translates to:
  /// **'আস-সুন্নাহ ফাউন্ডেশনের স্টাডি-সার্কেল ও কোর্সগুলো এখানে যুক্ত হবে।'**
  String get courses_empty_hint;

  /// No description provided for @courses_load_failed.
  ///
  /// In bn, this message translates to:
  /// **'কোর্স লোড করা যায়নি'**
  String get courses_load_failed;

  /// No description provided for @lesson_complete.
  ///
  /// In bn, this message translates to:
  /// **'পাঠ সম্পন্ন হয়েছে'**
  String get lesson_complete;

  /// No description provided for @lesson_unmark.
  ///
  /// In bn, this message translates to:
  /// **'সম্পন্ন থেকে সরান'**
  String get lesson_unmark;

  /// No description provided for @lesson_next.
  ///
  /// In bn, this message translates to:
  /// **'পরের পাঠ'**
  String get lesson_next;

  /// No description provided for @quiz_play.
  ///
  /// In bn, this message translates to:
  /// **'কুইজ খেলুন'**
  String get quiz_play;

  /// No description provided for @quiz_live_eligible.
  ///
  /// In bn, this message translates to:
  /// **'লাইভ কুইজযোগ্য'**
  String get quiz_live_eligible;

  /// No description provided for @quiz_best.
  ///
  /// In bn, this message translates to:
  /// **'সেরা'**
  String get quiz_best;

  /// No description provided for @quiz_last.
  ///
  /// In bn, this message translates to:
  /// **'সর্বশেষ'**
  String get quiz_last;

  /// No description provided for @quiz_question_of.
  ///
  /// In bn, this message translates to:
  /// **'প্রশ্ন'**
  String get quiz_question_of;

  /// No description provided for @quiz_choose_option.
  ///
  /// In bn, this message translates to:
  /// **'একটি উত্তর বেছে নিন'**
  String get quiz_choose_option;

  /// No description provided for @quiz_correct_was.
  ///
  /// In bn, this message translates to:
  /// **'সঠিক উত্তর ছিল'**
  String get quiz_correct_was;

  /// No description provided for @quiz_explanation.
  ///
  /// In bn, this message translates to:
  /// **'ব্যাখ্যা'**
  String get quiz_explanation;

  /// No description provided for @quiz_next_question.
  ///
  /// In bn, this message translates to:
  /// **'পরের প্রশ্ন'**
  String get quiz_next_question;

  /// No description provided for @quiz_finish.
  ///
  /// In bn, this message translates to:
  /// **'ফলাফল দেখুন'**
  String get quiz_finish;

  /// No description provided for @quiz_result_saved.
  ///
  /// In bn, this message translates to:
  /// **'স্কোর সার্ভারে সংরক্ষিত হয়েছে'**
  String get quiz_result_saved;

  /// No description provided for @quiz_result_local.
  ///
  /// In bn, this message translates to:
  /// **'সাইন ইন করলে স্কোর সংরক্ষিত হতো'**
  String get quiz_result_local;

  /// No description provided for @quiz_play_again.
  ///
  /// In bn, this message translates to:
  /// **'আবার খেলুন'**
  String get quiz_play_again;

  /// No description provided for @quiz_back_to_list.
  ///
  /// In bn, this message translates to:
  /// **'তালিকায় ফিরুন'**
  String get quiz_back_to_list;

  /// No description provided for @quizzes_empty_title.
  ///
  /// In bn, this message translates to:
  /// **'কুইজ শীঘ্রই আসছে, ইনশাআল্লাহ'**
  String get quizzes_empty_title;

  /// No description provided for @quizzes_empty_hint.
  ///
  /// In bn, this message translates to:
  /// **'কুরআন-সুন্নাহ, আকীদা ও ফিকহের কুইজ এখানে যুক্ত হবে।'**
  String get quizzes_empty_hint;

  /// No description provided for @quizzes_load_failed.
  ///
  /// In bn, this message translates to:
  /// **'কুইজ লোড করা যায়নি'**
  String get quizzes_load_failed;

  /// No description provided for @live_quiz_desc.
  ///
  /// In bn, this message translates to:
  /// **'আপনার উসরার ঘরে ঢুকে একসাথে কুইজ খেলুন — প্রশ্ন আসবে একে একে, সবার স্কোর লিডারবোর্ডে উঠবে। উসরা প্রধান কুইজ শুরু করলেই আপনার স্ক্রিনে প্রশ্ন চলে আসবে, ইনশাআল্লাহ।'**
  String get live_quiz_desc;

  /// No description provided for @live_quiz_enter.
  ///
  /// In bn, this message translates to:
  /// **'কুইজ ঘরে প্রবেশ করুন'**
  String get live_quiz_enter;

  /// No description provided for @live_quiz_joining.
  ///
  /// In bn, this message translates to:
  /// **'যোগ হচ্ছে…'**
  String get live_quiz_joining;

  /// No description provided for @live_quiz_connected.
  ///
  /// In bn, this message translates to:
  /// **'সংযুক্ত'**
  String get live_quiz_connected;

  /// No description provided for @live_quiz_disconnected.
  ///
  /// In bn, this message translates to:
  /// **'বিচ্ছিন্ন'**
  String get live_quiz_disconnected;

  /// No description provided for @live_quiz_signin_hint.
  ///
  /// In bn, this message translates to:
  /// **'উসরার সদস্য হিসেবে সাইন ইন করলে আপনার উসরা প্রধানের চালানো লাইভ কুইজে অংশ নিতে পারবেন।'**
  String get live_quiz_signin_hint;

  /// No description provided for @live_quiz_for_usrah.
  ///
  /// In bn, this message translates to:
  /// **'লাইভ কুইজ — উসরার জন্য'**
  String get live_quiz_for_usrah;

  /// No description provided for @live_quiz_host_controls.
  ///
  /// In bn, this message translates to:
  /// **'উসরা প্রধান — কুইজ নিয়ন্ত্রণ'**
  String get live_quiz_host_controls;

  /// No description provided for @live_quiz_start.
  ///
  /// In bn, this message translates to:
  /// **'কুইজ শুরু করুন'**
  String get live_quiz_start;

  /// No description provided for @live_quiz_next.
  ///
  /// In bn, this message translates to:
  /// **'পরের প্রশ্ন'**
  String get live_quiz_next;

  /// No description provided for @live_quiz_reveal_now.
  ///
  /// In bn, this message translates to:
  /// **'ফলাফল দেখান'**
  String get live_quiz_reveal_now;

  /// No description provided for @live_quiz_end.
  ///
  /// In bn, this message translates to:
  /// **'শেষ করুন'**
  String get live_quiz_end;

  /// No description provided for @live_quiz_leave.
  ///
  /// In bn, this message translates to:
  /// **'ঘর থেকে বেরিয়ে যান'**
  String get live_quiz_leave;

  /// No description provided for @live_quiz_lobby_host.
  ///
  /// In bn, this message translates to:
  /// **'একটি কুইজ বেছে নিয়ে শুরু করুন — আপনার উসরার সদস্যরা যোগ দিচ্ছেন।'**
  String get live_quiz_lobby_host;

  /// No description provided for @live_quiz_lobby_player.
  ///
  /// In bn, this message translates to:
  /// **'উসরা প্রধান কুইজ শুরু করলে প্রশ্ন এখানে আসবে…'**
  String get live_quiz_lobby_player;

  /// No description provided for @live_quiz_answered.
  ///
  /// In bn, this message translates to:
  /// **'উত্তর জমা হয়েছে — অপেক্ষা করুন…'**
  String get live_quiz_answered;

  /// No description provided for @live_quiz_host_hint.
  ///
  /// In bn, this message translates to:
  /// **'সবাই উত্তর দিলে অটো ফলাফল — তাড়াতাড়ি দেখতে “ফলাফল দেখান” চাপুন'**
  String get live_quiz_host_hint;

  /// No description provided for @live_quiz_reveal_title.
  ///
  /// In bn, this message translates to:
  /// **'ফলাফল'**
  String get live_quiz_reveal_title;

  /// No description provided for @live_quiz_final.
  ///
  /// In bn, this message translates to:
  /// **'কুইজ শেষ — চূড়ান্ত ফলাফল'**
  String get live_quiz_final;

  /// No description provided for @live_quiz_leaderboard.
  ///
  /// In bn, this message translates to:
  /// **'লিডারবোর্ড'**
  String get live_quiz_leaderboard;

  /// No description provided for @live_quiz_players.
  ///
  /// In bn, this message translates to:
  /// **'সদস্যরা'**
  String get live_quiz_players;

  /// No description provided for @live_quiz_connect_failed.
  ///
  /// In bn, this message translates to:
  /// **'কুইজ সার্ভারে পৌঁছানো যাচ্ছে না'**
  String get live_quiz_connect_failed;

  /// No description provided for @live_quiz_secs.
  ///
  /// In bn, this message translates to:
  /// **'সে'**
  String get live_quiz_secs;

  /// No description provided for @live_quiz_people.
  ///
  /// In bn, this message translates to:
  /// **'জন'**
  String get live_quiz_people;

  /// No description provided for @usrah_q_title.
  ///
  /// In bn, this message translates to:
  /// **'উসরার প্রশ্নোত্তর'**
  String get usrah_q_title;

  /// No description provided for @usrah_q_hint.
  ///
  /// In bn, this message translates to:
  /// **'দায়ী হিসেবে সাইন ইন করলে আপনার উসরার ভেতরে প্রশ্ন করতে পারবেন এবং উসরা প্রধানের উত্তর দেখতে পারবেন।'**
  String get usrah_q_hint;

  /// No description provided for @usrah_q_ask_hint.
  ///
  /// In bn, this message translates to:
  /// **'আপনার প্রশ্ন লিখুন…'**
  String get usrah_q_ask_hint;

  /// No description provided for @usrah_q_send.
  ///
  /// In bn, this message translates to:
  /// **'প্রশ্ন পাঠান'**
  String get usrah_q_send;

  /// No description provided for @usrah_q_sending.
  ///
  /// In bn, this message translates to:
  /// **'পাঠানো হচ্ছে…'**
  String get usrah_q_sending;

  /// No description provided for @usrah_q_sent.
  ///
  /// In bn, this message translates to:
  /// **'প্রশ্ন পাঠানো হয়েছে — উসরা প্রধান উত্তর দিলে এখানে দেখা যাবে'**
  String get usrah_q_sent;

  /// No description provided for @usrah_q_empty.
  ///
  /// In bn, this message translates to:
  /// **'এখনো কোনো প্রশ্ন নেই — প্রথম প্রশ্নটি আপনিই করুন'**
  String get usrah_q_empty;

  /// No description provided for @usrah_q_answered_by.
  ///
  /// In bn, this message translates to:
  /// **'উত্তর দিয়েছেন'**
  String get usrah_q_answered_by;

  /// No description provided for @usrah_q_awaiting.
  ///
  /// In bn, this message translates to:
  /// **'উসরা প্রধানের উত্তরের অপেক্ষায়'**
  String get usrah_q_awaiting;

  /// No description provided for @usrah_q_answer_hint.
  ///
  /// In bn, this message translates to:
  /// **'উত্তর লিখুন…'**
  String get usrah_q_answer_hint;

  /// No description provided for @usrah_q_answer_submit.
  ///
  /// In bn, this message translates to:
  /// **'উত্তর প্রকাশ করুন'**
  String get usrah_q_answer_submit;

  /// No description provided for @usrah_q_answered.
  ///
  /// In bn, this message translates to:
  /// **'উত্তর প্রকাশিত হয়েছে'**
  String get usrah_q_answered;

  /// No description provided for @usrah_q_cat_general.
  ///
  /// In bn, this message translates to:
  /// **'সাধারণ'**
  String get usrah_q_cat_general;

  /// No description provided for @usrah_q_cat_aqeedah.
  ///
  /// In bn, this message translates to:
  /// **'আকীদা'**
  String get usrah_q_cat_aqeedah;

  /// No description provided for @usrah_q_cat_salah.
  ///
  /// In bn, this message translates to:
  /// **'সালাত'**
  String get usrah_q_cat_salah;

  /// No description provided for @usrah_q_cat_quran.
  ///
  /// In bn, this message translates to:
  /// **'কুরআন'**
  String get usrah_q_cat_quran;

  /// No description provided for @usrah_q_cat_muamalah.
  ///
  /// In bn, this message translates to:
  /// **'লেনদেন'**
  String get usrah_q_cat_muamalah;

  /// No description provided for @usrah_q_cat_tarbiyah.
  ///
  /// In bn, this message translates to:
  /// **'তারবিয়াত'**
  String get usrah_q_cat_tarbiyah;

  /// No description provided for @dawah_req_title.
  ///
  /// In bn, this message translates to:
  /// **'স্তরের প্রয়োজনীয়তা'**
  String get dawah_req_title;

  /// No description provided for @dawah_req_progress_unit.
  ///
  /// In bn, this message translates to:
  /// **'পূরণ'**
  String get dawah_req_progress_unit;

  /// No description provided for @dawah_req_invigilator_check.
  ///
  /// In bn, this message translates to:
  /// **'পরিদর্শক যাচাই'**
  String get dawah_req_invigilator_check;

  /// No description provided for @dawah_req_all_met.
  ///
  /// In bn, this message translates to:
  /// **'মাশাআল্লাহ — সব শর্ত পূরণ হয়েছে! স্তর উন্নতির অপেক্ষায়।'**
  String get dawah_req_all_met;

  /// No description provided for @dawah_req_auto_hint.
  ///
  /// In bn, this message translates to:
  /// **'সব শর্ত পূরণ হলে রাতের মূল্যায়নে স্তর স্বয়ংক্রিয়ভাবে উন্নত হবে, ইনশাআল্লাহ।'**
  String get dawah_req_auto_hint;

  /// No description provided for @dawah_req_load_failed.
  ///
  /// In bn, this message translates to:
  /// **'চেকলিস্ট আনা যায়নি'**
  String get dawah_req_load_failed;

  /// No description provided for @dawah_req_live_action.
  ///
  /// In bn, this message translates to:
  /// **'লাইভ চেকলিস্ট'**
  String get dawah_req_live_action;

  /// No description provided for @bell_minutes_title.
  ///
  /// In bn, this message translates to:
  /// **'ঘণ্টির সময় নির্ধারণ'**
  String get bell_minutes_title;

  /// No description provided for @bell_minutes_before.
  ///
  /// In bn, this message translates to:
  /// **'ওয়াক্তের আগে (মিনিট)'**
  String get bell_minutes_before;

  /// No description provided for @bell_minutes_after.
  ///
  /// In bn, this message translates to:
  /// **'নামাজের পরে (মিনিট)'**
  String get bell_minutes_after;

  /// No description provided for @bell_minutes_reset.
  ///
  /// In bn, this message translates to:
  /// **'রিসেট'**
  String get bell_minutes_reset;

  /// No description provided for @bell_minutes_done.
  ///
  /// In bn, this message translates to:
  /// **'ঠিক আছে'**
  String get bell_minutes_done;

  /// No description provided for @sync_sheet_title.
  ///
  /// In bn, this message translates to:
  /// **'সিঙ্ক অবস্থা'**
  String get sync_sheet_title;

  /// No description provided for @sync_now.
  ///
  /// In bn, this message translates to:
  /// **'এখনই সিঙ্ক করুন'**
  String get sync_now;

  /// No description provided for @sync_last_synced.
  ///
  /// In bn, this message translates to:
  /// **'সর্বশেষ সিঙ্ক'**
  String get sync_last_synced;

  /// No description provided for @sync_never.
  ///
  /// In bn, this message translates to:
  /// **'এখনো সিঙ্ক হয়নি'**
  String get sync_never;

  /// No description provided for @sync_failed_entries.
  ///
  /// In bn, this message translates to:
  /// **'সমস্যায় পড়া এন্ট্রি'**
  String get sync_failed_entries;

  /// No description provided for @sync_failed_short.
  ///
  /// In bn, this message translates to:
  /// **'সমস্যা'**
  String get sync_failed_short;

  /// No description provided for @sync_dead_discard.
  ///
  /// In bn, this message translates to:
  /// **'বাদ দিন'**
  String get sync_dead_discard;

  /// No description provided for @sync_error_unexpected.
  ///
  /// In bn, this message translates to:
  /// **'অপ্রত্যাশিত সমস্যা — আবার চেষ্টা করুন'**
  String get sync_error_unexpected;

  /// No description provided for @gps_find_city.
  ///
  /// In bn, this message translates to:
  /// **'GPS দিয়ে খুঁজুন'**
  String get gps_find_city;

  /// No description provided for @gps_find_city_hint.
  ///
  /// In bn, this message translates to:
  /// **'আপনার নিকটতম জেলা স্বয়ংক্রিয়ভাবে খুঁজে নেওয়া হবে'**
  String get gps_find_city_hint;

  /// No description provided for @gps_locating.
  ///
  /// In bn, this message translates to:
  /// **'অবস্থান নেওয়া হচ্ছে…'**
  String get gps_locating;

  /// No description provided for @gps_your_location.
  ///
  /// In bn, this message translates to:
  /// **'আপনার অবস্থান'**
  String get gps_your_location;

  /// No description provided for @gps_approx.
  ///
  /// In bn, this message translates to:
  /// **'অনুমান'**
  String get gps_approx;

  /// No description provided for @gps_approx_note.
  ///
  /// In bn, this message translates to:
  /// **'নিকটতম তালিকাভুক্ত শহর থেকে অনেক দূরে'**
  String get gps_approx_note;

  /// No description provided for @gps_tap_confirm.
  ///
  /// In bn, this message translates to:
  /// **'ট্যাপ করে নিশ্চিত করুন'**
  String get gps_tap_confirm;

  /// No description provided for @gps_permission_denied.
  ///
  /// In bn, this message translates to:
  /// **'অনুমতি দেওয়া হয়নি — তালিকা থেকে শহর বেছে নিন'**
  String get gps_permission_denied;

  /// No description provided for @gps_permission_denied_forever.
  ///
  /// In bn, this message translates to:
  /// **'অনুমতি বন্ধ আছে — সেটিংস থেকে অনুমতি দিন'**
  String get gps_permission_denied_forever;

  /// No description provided for @gps_open_settings.
  ///
  /// In bn, this message translates to:
  /// **'সেটিংস খুলুন'**
  String get gps_open_settings;

  /// No description provided for @gps_service_off.
  ///
  /// In bn, this message translates to:
  /// **'ফোনের লোকেশন বন্ধ আছে'**
  String get gps_service_off;

  /// No description provided for @gps_open_location_settings.
  ///
  /// In bn, this message translates to:
  /// **'লোকেশন চালু করুন'**
  String get gps_open_location_settings;

  /// No description provided for @gps_unavailable.
  ///
  /// In bn, this message translates to:
  /// **'অবস্থান পাওয়া যায়নি — আবার চেষ্টা করুন'**
  String get gps_unavailable;

  /// No description provided for @unit_m.
  ///
  /// In bn, this message translates to:
  /// **'মি'**
  String get unit_m;

  /// No description provided for @qibla_compass_heading.
  ///
  /// In bn, this message translates to:
  /// **'বর্তমান দিক'**
  String get qibla_compass_heading;

  /// No description provided for @qibla_calibration_title.
  ///
  /// In bn, this message translates to:
  /// **'কম্পাস ক্যালিব্রেট করুন'**
  String get qibla_calibration_title;

  /// No description provided for @qibla_calibration_hint.
  ///
  /// In bn, this message translates to:
  /// **'ফোনটি বাতাসে ৮ আকৃতিতে কয়েকবার ঘোরান, তারপর আবার দেখুন'**
  String get qibla_calibration_hint;

  /// No description provided for @qibla_compass_unavailable.
  ///
  /// In bn, this message translates to:
  /// **'এই ফোনে কম্পাস পাওয়া যায়নি — নিচের ম্যানুয়াল ডায়াল ব্যবহার করুন'**
  String get qibla_compass_unavailable;

  /// No description provided for @mosques_near_me.
  ///
  /// In bn, this message translates to:
  /// **'আমার কাছাকাছি'**
  String get mosques_near_me;

  /// No description provided for @mosques_from_city.
  ///
  /// In bn, this message translates to:
  /// **'এই শহর থেকে'**
  String get mosques_from_city;

  /// No description provided for @mosques_from_location.
  ///
  /// In bn, this message translates to:
  /// **'আপনার অবস্থান থেকে'**
  String get mosques_from_location;

  /// No description provided for @mosques_use_city.
  ///
  /// In bn, this message translates to:
  /// **'শহর থেকে দেখুন'**
  String get mosques_use_city;

  /// No description provided for @mosque_direction.
  ///
  /// In bn, this message translates to:
  /// **'দিক'**
  String get mosque_direction;

  /// No description provided for @more_autosilent.
  ///
  /// In bn, this message translates to:
  /// **'অটো-সাইলেন্ট'**
  String get more_autosilent;

  /// No description provided for @autosilent_explain_title.
  ///
  /// In bn, this message translates to:
  /// **'জামাতের সময় ফোন নিঃশব্দ'**
  String get autosilent_explain_title;

  /// No description provided for @autosilent_explain_body.
  ///
  /// In bn, this message translates to:
  /// **'প্রতি ওয়াক্তের শুরুতে ফোন সাইলেন্ট (শুধু জরুরি) হয়ে যায় এবং নির্দিষ্ট সময় পর আগের অবস্থায় ফিরে আসে। এর জন্য অ্যান্ড্রয়েডের ‘বিরক্ত না করুন’ (Do Not Disturb) অনুমতি দরকার।'**
  String get autosilent_explain_body;

  /// No description provided for @autosilent_dnd_status.
  ///
  /// In bn, this message translates to:
  /// **'অনুমতির অবস্থা'**
  String get autosilent_dnd_status;

  /// No description provided for @autosilent_granted.
  ///
  /// In bn, this message translates to:
  /// **'অনুমতি দেওয়া আছে'**
  String get autosilent_granted;

  /// No description provided for @autosilent_not_granted.
  ///
  /// In bn, this message translates to:
  /// **'অনুমতি নেই'**
  String get autosilent_not_granted;

  /// No description provided for @autosilent_grant.
  ///
  /// In bn, this message translates to:
  /// **'অনুমতি দিন'**
  String get autosilent_grant;

  /// No description provided for @autosilent_recheck.
  ///
  /// In bn, this message translates to:
  /// **'আবার চেক করুন'**
  String get autosilent_recheck;

  /// No description provided for @autosilent_return_hint.
  ///
  /// In bn, this message translates to:
  /// **'অনুমতি দিয়ে অ্যাপে ফিরে এলে অবস্থা নিজেই হালনাগাদ হবে'**
  String get autosilent_return_hint;

  /// No description provided for @autosilent_master.
  ///
  /// In bn, this message translates to:
  /// **'অটো-সাইলেন্ট চালু'**
  String get autosilent_master;

  /// No description provided for @autosilent_minutes_label.
  ///
  /// In bn, this message translates to:
  /// **'সাইলেন্ট থাকার সময়'**
  String get autosilent_minutes_label;

  /// No description provided for @autosilent_minutes_suffix.
  ///
  /// In bn, this message translates to:
  /// **'মিনিট সাইলেন্ট'**
  String get autosilent_minutes_suffix;

  /// No description provided for @autosilent_waqts_title.
  ///
  /// In bn, this message translates to:
  /// **'কোন কোন ওয়াক্তে চালু হবে'**
  String get autosilent_waqts_title;

  /// No description provided for @autosilent_reboot_note.
  ///
  /// In bn, this message translates to:
  /// **'ফোন রিস্টার্টের পর অ্যাপ একবার খুললে সময়সূচি আবার চালু হয়ে যায়।'**
  String get autosilent_reboot_note;

  /// No description provided for @more_donate.
  ///
  /// In bn, this message translates to:
  /// **'দান করুন'**
  String get more_donate;

  /// No description provided for @donation_open_failed.
  ///
  /// In bn, this message translates to:
  /// **'লিংক খোলা যায়নি'**
  String get donation_open_failed;

  /// No description provided for @referral_by.
  ///
  /// In bn, this message translates to:
  /// **'রেফার করেছেন'**
  String get referral_by;

  /// No description provided for @header_notifications.
  ///
  /// In bn, this message translates to:
  /// **'নোটিফিকেশন'**
  String get header_notifications;

  /// No description provided for @header_reminders.
  ///
  /// In bn, this message translates to:
  /// **'রিমাইন্ডার'**
  String get header_reminders;

  /// No description provided for @notifications_guest_hint.
  ///
  /// In bn, this message translates to:
  /// **'সাইন ইন করলে উসরা ঘোষণা, সাপ্তাহিক রিভিউ ও লাইভ রিমাইন্ডার এখানে দেখা যাবে।'**
  String get notifications_guest_hint;

  /// No description provided for @notifications_empty.
  ///
  /// In bn, this message translates to:
  /// **'এখনো কোনো ঘোষণা নেই'**
  String get notifications_empty;

  /// No description provided for @notifications_announcements.
  ///
  /// In bn, this message translates to:
  /// **'ঘোষণা'**
  String get notifications_announcements;

  /// No description provided for @notifications_live.
  ///
  /// In bn, this message translates to:
  /// **'লাইভ অনুষ্ঠান'**
  String get notifications_live;

  /// No description provided for @reminders_empty.
  ///
  /// In bn, this message translates to:
  /// **'এখনো কোনো রিমাইন্ডার নেই'**
  String get reminders_empty;

  /// No description provided for @reminder_mark_done.
  ///
  /// In bn, this message translates to:
  /// **'সম্পন্ন করুন'**
  String get reminder_mark_done;

  /// No description provided for @reminder_due.
  ///
  /// In bn, this message translates to:
  /// **'এখন'**
  String get reminder_due;

  /// No description provided for @reminder_overdue.
  ///
  /// In bn, this message translates to:
  /// **'মেয়াদ পেরিয়েছে'**
  String get reminder_overdue;

  /// No description provided for @reminder_upcoming.
  ///
  /// In bn, this message translates to:
  /// **'আসছে'**
  String get reminder_upcoming;

  /// No description provided for @contact_title.
  ///
  /// In bn, this message translates to:
  /// **'যোগাযোগ'**
  String get contact_title;

  /// No description provided for @contact_call.
  ///
  /// In bn, this message translates to:
  /// **'কল করুন'**
  String get contact_call;

  /// No description provided for @contact_website.
  ///
  /// In bn, this message translates to:
  /// **'ওয়েবসাইট'**
  String get contact_website;

  /// No description provided for @contact_call_failed.
  ///
  /// In bn, this message translates to:
  /// **'কল করা যায়নি'**
  String get contact_call_failed;

  /// No description provided for @quick_access.
  ///
  /// In bn, this message translates to:
  /// **'দ্রুত প্রবেশ'**
  String get quick_access;

  /// No description provided for @quick_quran_desc.
  ///
  /// In bn, this message translates to:
  /// **'সূরা ও অনুবাদ'**
  String get quick_quran_desc;

  /// No description provided for @quick_duas_desc.
  ///
  /// In bn, this message translates to:
  /// **'দৈনন্দিন দোয়া'**
  String get quick_duas_desc;

  /// No description provided for @quick_amal_desc.
  ///
  /// In bn, this message translates to:
  /// **'মুহাসাবা ডায়েরি'**
  String get quick_amal_desc;

  /// No description provided for @quick_live_desc.
  ///
  /// In bn, this message translates to:
  /// **'সরাসরি অনুষ্ঠান'**
  String get quick_live_desc;

  /// No description provided for @most_used.
  ///
  /// In bn, this message translates to:
  /// **'সর্বাধিক ব্যবহৃত'**
  String get most_used;

  /// No description provided for @most_used_empty.
  ///
  /// In bn, this message translates to:
  /// **'গত ৩০ দিনে সবচেয়ে বেশি লেখা আমলগুলো এখানে দেখা যাবে — আজকের ডায়েরি থেকে শুরু করুন'**
  String get most_used_empty;

  /// No description provided for @most_used_log_today.
  ///
  /// In bn, this message translates to:
  /// **'আজ লিখুন'**
  String get most_used_log_today;

  /// No description provided for @most_used_days.
  ///
  /// In bn, this message translates to:
  /// **'দিন'**
  String get most_used_days;

  /// No description provided for @countdown_to_schedule.
  ///
  /// In bn, this message translates to:
  /// **'সময়সূচি দেখুন'**
  String get countdown_to_schedule;

  /// No description provided for @next_bell_chip.
  ///
  /// In bn, this message translates to:
  /// **'পরবর্তী বেল'**
  String get next_bell_chip;

  /// No description provided for @live_next.
  ///
  /// In bn, this message translates to:
  /// **'পরবর্তী লাইভ'**
  String get live_next;

  /// No description provided for @live_join_hint.
  ///
  /// In bn, this message translates to:
  /// **'দেখতে ট্যাপ করুন'**
  String get live_join_hint;

  /// No description provided for @ilm_courses_desc.
  ///
  /// In bn, this message translates to:
  /// **'শেখার কোর্স ও লেসন'**
  String get ilm_courses_desc;

  /// No description provided for @ilm_quizzes_desc.
  ///
  /// In bn, this message translates to:
  /// **'আত্মমূল্যায়ন কুইজ'**
  String get ilm_quizzes_desc;

  /// No description provided for @goals_title.
  ///
  /// In bn, this message translates to:
  /// **'আমার লক্ষ্য'**
  String get goals_title;

  /// No description provided for @goals_new.
  ///
  /// In bn, this message translates to:
  /// **'নতুন লক্ষ্য'**
  String get goals_new;

  /// No description provided for @goals_amal_picker.
  ///
  /// In bn, this message translates to:
  /// **'আমল নির্বাচন করুন'**
  String get goals_amal_picker;

  /// No description provided for @goals_amal_short.
  ///
  /// In bn, this message translates to:
  /// **'আমল'**
  String get goals_amal_short;

  /// No description provided for @goals_title_label.
  ///
  /// In bn, this message translates to:
  /// **'লক্ষ্যের নাম'**
  String get goals_title_label;

  /// No description provided for @goals_target_label.
  ///
  /// In bn, this message translates to:
  /// **'লক্ষ্য মাত্রা (ঐচ্ছিক)'**
  String get goals_target_label;

  /// No description provided for @goals_note_label.
  ///
  /// In bn, this message translates to:
  /// **'নোট (ঐচ্ছিক)'**
  String get goals_note_label;

  /// No description provided for @goals_submit.
  ///
  /// In bn, this message translates to:
  /// **'প্রস্তাব করুন'**
  String get goals_submit;

  /// No description provided for @goals_signin_needed.
  ///
  /// In bn, this message translates to:
  /// **'লক্ষ্য সংরক্ষণ ও অনুমোদনের জন্য সাইন-ইন দরকার'**
  String get goals_signin_needed;

  /// No description provided for @goals_empty.
  ///
  /// In bn, this message translates to:
  /// **'এখনো কোনো লক্ষ্য নেই — প্রথম লক্ষ্য ঠিক করুন'**
  String get goals_empty;

  /// No description provided for @goals_open_label.
  ///
  /// In bn, this message translates to:
  /// **'খোলা লক্ষ্য'**
  String get goals_open_label;

  /// No description provided for @goal_status_proposed.
  ///
  /// In bn, this message translates to:
  /// **'অপেক্ষমাণ'**
  String get goal_status_proposed;

  /// No description provided for @goal_status_approved.
  ///
  /// In bn, this message translates to:
  /// **'অনুমোদিত'**
  String get goal_status_approved;

  /// No description provided for @goal_status_rejected.
  ///
  /// In bn, this message translates to:
  /// **'বাতিল'**
  String get goal_status_rejected;

  /// No description provided for @goal_status_completed.
  ///
  /// In bn, this message translates to:
  /// **'সম্পন্ন'**
  String get goal_status_completed;

  /// No description provided for @goal_status_withdrawn.
  ///
  /// In bn, this message translates to:
  /// **'প্রত্যাহৃত'**
  String get goal_status_withdrawn;

  /// No description provided for @goals_reject_reason_label.
  ///
  /// In bn, this message translates to:
  /// **'কারণ'**
  String get goals_reject_reason_label;

  /// No description provided for @goals_queue_title.
  ///
  /// In bn, this message translates to:
  /// **'লক্ষ্য অনুমোদনের অপেক্ষায়'**
  String get goals_queue_title;

  /// No description provided for @goals_queue_empty.
  ///
  /// In bn, this message translates to:
  /// **'কোনো অপেক্ষমাণ লক্ষ্য নেই'**
  String get goals_queue_empty;

  /// No description provided for @goals_approve.
  ///
  /// In bn, this message translates to:
  /// **'অনুমোদন'**
  String get goals_approve;

  /// No description provided for @goals_reject.
  ///
  /// In bn, this message translates to:
  /// **'বাতিল'**
  String get goals_reject;

  /// No description provided for @goals_reject_hint.
  ///
  /// In bn, this message translates to:
  /// **'বাতিলের কারণ লিখুন (ঐচ্ছিক)'**
  String get goals_reject_hint;

  /// No description provided for @goals_member_label.
  ///
  /// In bn, this message translates to:
  /// **'সদস্য'**
  String get goals_member_label;

  /// No description provided for @goals_remove.
  ///
  /// In bn, this message translates to:
  /// **'সরান'**
  String get goals_remove;

  /// No description provided for @goals_remove_confirm.
  ///
  /// In bn, this message translates to:
  /// **'লক্ষ্যটি তালিকা থেকে সরানো হবে?'**
  String get goals_remove_confirm;

  /// No description provided for @goals_proposed_toast.
  ///
  /// In bn, this message translates to:
  /// **'লক্ষ্য প্রস্তাবিত — উসরা প্রধানের অনুমোদনের অপেক্ষায়'**
  String get goals_proposed_toast;

  /// No description provided for @goals_approved_toast.
  ///
  /// In bn, this message translates to:
  /// **'অনুমোদিত হয়েছে'**
  String get goals_approved_toast;

  /// No description provided for @goals_rejected_toast.
  ///
  /// In bn, this message translates to:
  /// **'বাতিল হয়েছে'**
  String get goals_rejected_toast;

  /// No description provided for @checklist_title.
  ///
  /// In bn, this message translates to:
  /// **'নিজের তালিকা'**
  String get checklist_title;

  /// No description provided for @checklist_hint.
  ///
  /// In bn, this message translates to:
  /// **'নতুন কাজ লিখুন'**
  String get checklist_hint;

  /// No description provided for @checklist_add.
  ///
  /// In bn, this message translates to:
  /// **'যোগ করুন'**
  String get checklist_add;

  /// No description provided for @checklist_remove.
  ///
  /// In bn, this message translates to:
  /// **'মুছুন'**
  String get checklist_remove;

  /// No description provided for @checklist_remove_confirm.
  ///
  /// In bn, this message translates to:
  /// **'কাজটি মুছে ফেলা হবে?'**
  String get checklist_remove_confirm;

  /// No description provided for @checklist_local_note.
  ///
  /// In bn, this message translates to:
  /// **'শুধু এই ডিভাইসে সংরক্ষিত'**
  String get checklist_local_note;

  /// No description provided for @group_fard.
  ///
  /// In bn, this message translates to:
  /// **'ফরয নামাজ'**
  String get group_fard;

  /// No description provided for @group_salah_sunnah.
  ///
  /// In bn, this message translates to:
  /// **'সালাতের সুন্নত'**
  String get group_salah_sunnah;

  /// No description provided for @group_nafl.
  ///
  /// In bn, this message translates to:
  /// **'নফল নামাজ'**
  String get group_nafl;

  /// No description provided for @tilawat_begin_chip.
  ///
  /// In bn, this message translates to:
  /// **'শুরু'**
  String get tilawat_begin_chip;

  /// No description provided for @tilawat_begin_copy.
  ///
  /// In bn, this message translates to:
  /// **'আজ ৫ মিনিট দিয়ে শুরু করুন — ধীরে ধীরে অভ্যাস হয়ে যাবে ইনশাআল্লাহ'**
  String get tilawat_begin_copy;

  /// No description provided for @tilawat_ramp_day.
  ///
  /// In bn, this message translates to:
  /// **'দিন'**
  String get tilawat_ramp_day;

  /// No description provided for @tilawat_begin_minutes.
  ///
  /// In bn, this message translates to:
  /// **'মিনিট'**
  String get tilawat_begin_minutes;

  /// No description provided for @leaderboard_title.
  ///
  /// In bn, this message translates to:
  /// **'লিডারবোর্ড'**
  String get leaderboard_title;

  /// No description provided for @leaderboard_points.
  ///
  /// In bn, this message translates to:
  /// **'পয়েন্ট'**
  String get leaderboard_points;

  /// No description provided for @leaderboard_window_days.
  ///
  /// In bn, this message translates to:
  /// **'দিনের হিসাব'**
  String get leaderboard_window_days;

  /// No description provided for @leaderboard_band_top10.
  ///
  /// In bn, this message translates to:
  /// **'শীর্ষ ১০%'**
  String get leaderboard_band_top10;

  /// No description provided for @leaderboard_band_top25.
  ///
  /// In bn, this message translates to:
  /// **'শীর্ষ ২৫%'**
  String get leaderboard_band_top25;

  /// No description provided for @leaderboard_band_top50.
  ///
  /// In bn, this message translates to:
  /// **'শীর্ষ ৫০%'**
  String get leaderboard_band_top50;

  /// No description provided for @leaderboard_band_top75.
  ///
  /// In bn, this message translates to:
  /// **'শীর্ষ ৭৫%'**
  String get leaderboard_band_top75;

  /// No description provided for @leaderboard_band_bottom.
  ///
  /// In bn, this message translates to:
  /// **'নিচের ২৫%'**
  String get leaderboard_band_bottom;

  /// No description provided for @offline_banner.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন — দেখানো হচ্ছে সংরক্ষিত তথ্য'**
  String get offline_banner;

  /// No description provided for @last_updated.
  ///
  /// In bn, this message translates to:
  /// **'সর্বশেষ হালনাগাদ'**
  String get last_updated;

  /// No description provided for @more_section_foundation.
  ///
  /// In bn, this message translates to:
  /// **'ফাউন্ডেশন'**
  String get more_section_foundation;

  /// No description provided for @contact_email.
  ///
  /// In bn, this message translates to:
  /// **'ইমেইল'**
  String get contact_email;

  /// No description provided for @more_section_worship.
  ///
  /// In bn, this message translates to:
  /// **'ইবাদত ও টুলস'**
  String get more_section_worship;

  /// No description provided for @more_section_knowledge.
  ///
  /// In bn, this message translates to:
  /// **'জ্ঞান'**
  String get more_section_knowledge;

  /// No description provided for @more_section_support.
  ///
  /// In bn, this message translates to:
  /// **'সহায়তা'**
  String get more_section_support;

  /// No description provided for @more_section_app.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাপ'**
  String get more_section_app;

  /// No description provided for @more_support.
  ///
  /// In bn, this message translates to:
  /// **'লাইভ সাপোর্ট'**
  String get more_support;

  /// No description provided for @support_signin_needed.
  ///
  /// In bn, this message translates to:
  /// **'লাইভ সাপোর্ট ব্যবহার করতে সাইন ইন করুন'**
  String get support_signin_needed;

  /// No description provided for @support_new_thread.
  ///
  /// In bn, this message translates to:
  /// **'নতুন আলাপ শুরু করুন'**
  String get support_new_thread;

  /// No description provided for @support_subject.
  ///
  /// In bn, this message translates to:
  /// **'বিষয়'**
  String get support_subject;

  /// No description provided for @support_subject_hint.
  ///
  /// In bn, this message translates to:
  /// **'সংক্ষেপে বিষয়টি লিখুন'**
  String get support_subject_hint;

  /// No description provided for @support_message.
  ///
  /// In bn, this message translates to:
  /// **'বার্তা'**
  String get support_message;

  /// No description provided for @support_message_hint.
  ///
  /// In bn, this message translates to:
  /// **'আপনার কথা লিখুন…'**
  String get support_message_hint;

  /// No description provided for @support_empty.
  ///
  /// In bn, this message translates to:
  /// **'কোনো আলাপ নেই — প্রয়োজনে নতুন একটি শুরু করুন'**
  String get support_empty;

  /// No description provided for @support_status_open.
  ///
  /// In bn, this message translates to:
  /// **'খোলা'**
  String get support_status_open;

  /// No description provided for @support_status_answered.
  ///
  /// In bn, this message translates to:
  /// **'উত্তর দেওয়া হয়েছে'**
  String get support_status_answered;

  /// No description provided for @support_status_closed.
  ///
  /// In bn, this message translates to:
  /// **'বন্ধ'**
  String get support_status_closed;

  /// No description provided for @support_team.
  ///
  /// In bn, this message translates to:
  /// **'সাপোর্ট টিম'**
  String get support_team;

  /// No description provided for @support_you.
  ///
  /// In bn, this message translates to:
  /// **'আপনি'**
  String get support_you;

  /// No description provided for @support_created_toast.
  ///
  /// In bn, this message translates to:
  /// **'আলাপ শুরু হয়েছে'**
  String get support_created_toast;

  /// No description provided for @support_sent_toast.
  ///
  /// In bn, this message translates to:
  /// **'উত্তর পাঠানো হয়েছে'**
  String get support_sent_toast;

  /// No description provided for @support_closed_toast.
  ///
  /// In bn, this message translates to:
  /// **'এই আলাপ বন্ধ করা হয়েছে — নতুন আলাপ শুরু করুন'**
  String get support_closed_toast;

  /// No description provided for @more_usrah_join.
  ///
  /// In bn, this message translates to:
  /// **'উসরায় যোগ দিন'**
  String get more_usrah_join;

  /// No description provided for @usrah_join_hint.
  ///
  /// In bn, this message translates to:
  /// **'কোনো উসরায় যুক্ত না থাকলে অনুরোধ পাঠান — তারবিয়াত দপ্তর আপনাকে একটি উসরায় যুকত করবে ইনশাআল্লাহ'**
  String get usrah_join_hint;

  /// No description provided for @usrah_join_message_hint.
  ///
  /// In bn, this message translates to:
  /// **'কিছু বলার থাকলে লিখুন (ঐচ্ছিক)'**
  String get usrah_join_message_hint;

  /// No description provided for @usrah_join_send.
  ///
  /// In bn, this message translates to:
  /// **'অনুরোধ পাঠান'**
  String get usrah_join_send;

  /// No description provided for @usrah_join_pending.
  ///
  /// In bn, this message translates to:
  /// **'অনুরোধ পেন্ডিং — অনুমোদনের অপেক্ষায়'**
  String get usrah_join_pending;

  /// No description provided for @usrah_join_rejected.
  ///
  /// In bn, this message translates to:
  /// **'অনুরোধ বাতিল হয়েছে'**
  String get usrah_join_rejected;

  /// No description provided for @usrah_join_reason_label.
  ///
  /// In bn, this message translates to:
  /// **'কারণ'**
  String get usrah_join_reason_label;

  /// No description provided for @usrah_join_in_usrah.
  ///
  /// In bn, this message translates to:
  /// **'আপনি ইতিমধ্যেই একটি উসরায় আছেন'**
  String get usrah_join_in_usrah;

  /// No description provided for @usrah_join_sent_toast.
  ///
  /// In bn, this message translates to:
  /// **'অনুরোধ পাঠানো হয়েছে — অনুমোদন হলে জানানো হবে ইনশাআল্লাহ'**
  String get usrah_join_sent_toast;

  /// No description provided for @usrah_join_signin_needed.
  ///
  /// In bn, this message translates to:
  /// **'উসরায় যোগ হতে সাইন ইন করুন'**
  String get usrah_join_signin_needed;

  /// No description provided for @more_detox.
  ///
  /// In bn, this message translates to:
  /// **'সোশ্যাল মিডিয়া ডিটক্স'**
  String get more_detox;

  /// No description provided for @detox_explain_title.
  ///
  /// In bn, this message translates to:
  /// **'স্ক্রিন-টাইম হিসাব'**
  String get detox_explain_title;

  /// No description provided for @detox_explain_body.
  ///
  /// In bn, this message translates to:
  /// **'সময় আমাদের আমানত। সোশ্যাল মিডিয়ায় কাটা প্রতিটি মিনিট পরকালের পুঁজি থেকে কমিয়ে দেয়। ব্যবহারের অনুমতি দিলে আজকের স্ক্রিন-টাইম ও সর্বাধিক ব্যবহৃত অ্যাপগুলো দেখাব — হিসাব সামনে থাকলে সংশোধন সহজ হয়, ইনশাআল্লাহ।'**
  String get detox_explain_body;

  /// No description provided for @detox_perm_status.
  ///
  /// In bn, this message translates to:
  /// **'ব্যবহারের অনুমতি'**
  String get detox_perm_status;

  /// No description provided for @detox_perm_granted.
  ///
  /// In bn, this message translates to:
  /// **'দেওয়া হয়েছে'**
  String get detox_perm_granted;

  /// No description provided for @detox_perm_not_granted.
  ///
  /// In bn, this message translates to:
  /// **'দেওয়া হয়নি'**
  String get detox_perm_not_granted;

  /// No description provided for @detox_grant.
  ///
  /// In bn, this message translates to:
  /// **'অনুমতি দিন'**
  String get detox_grant;

  /// No description provided for @detox_return_hint.
  ///
  /// In bn, this message translates to:
  /// **'অনুমতি দিয়ে অ্যাপে ফিরে আসুন'**
  String get detox_return_hint;

  /// No description provided for @detox_android_only.
  ///
  /// In bn, this message translates to:
  /// **'এই হিসাবটি শুধু অ্যান্ড্রয়েডে কাজ করে'**
  String get detox_android_only;

  /// No description provided for @detox_today_total.
  ///
  /// In bn, this message translates to:
  /// **'আজকের মোট স্ক্রিন-টাইম'**
  String get detox_today_total;

  /// No description provided for @detox_top_apps.
  ///
  /// In bn, this message translates to:
  /// **'সর্বাধিক ব্যবহৃত অ্যাপ'**
  String get detox_top_apps;

  /// No description provided for @detox_minutes_short.
  ///
  /// In bn, this message translates to:
  /// **'মিনিট'**
  String get detox_minutes_short;

  /// No description provided for @detox_no_usage.
  ///
  /// In bn, this message translates to:
  /// **'আজ এখনো তেমন কিছু নেই'**
  String get detox_no_usage;

  /// No description provided for @detox_reminder.
  ///
  /// In bn, this message translates to:
  /// **'দৈনিক রিমাইন্ডার'**
  String get detox_reminder;

  /// No description provided for @detox_reminder_time.
  ///
  /// In bn, this message translates to:
  /// **'রিমাইন্ডারের সময়'**
  String get detox_reminder_time;

  /// No description provided for @detox_notif_title.
  ///
  /// In bn, this message translates to:
  /// **'স্ক্রিন-টাইম হিসাব'**
  String get detox_notif_title;

  /// No description provided for @detox_notif_body.
  ///
  /// In bn, this message translates to:
  /// **'আজ কতক্ষণ স্ক্রিনে কাটালেন? একবার দেখে নিন।'**
  String get detox_notif_body;

  /// No description provided for @more_groups.
  ///
  /// In bn, this message translates to:
  /// **'আমাদের গ্রুপ'**
  String get more_groups;

  /// No description provided for @group_open_failed.
  ///
  /// In bn, this message translates to:
  /// **'খোলা যায়নি'**
  String get group_open_failed;

  /// No description provided for @dawah_share_card.
  ///
  /// In bn, this message translates to:
  /// **'দাওয়াত কার্ড শেয়ার করুন'**
  String get dawah_share_card;

  /// No description provided for @dawah_card_title.
  ///
  /// In bn, this message translates to:
  /// **'দাওয়াত কার্ড'**
  String get dawah_card_title;

  /// No description provided for @dawah_card_tagline.
  ///
  /// In bn, this message translates to:
  /// **'সুন্নাহর পথে জীবন গড়তে আমার সাথে যুক্ত হন'**
  String get dawah_card_tagline;

  /// No description provided for @dawah_card_preview_note.
  ///
  /// In bn, this message translates to:
  /// **'নিচের কার্ডটাই ছবি হিসেবে শেয়ার হবে'**
  String get dawah_card_preview_note;

  /// No description provided for @dawah_share_now.
  ///
  /// In bn, this message translates to:
  /// **'শেয়ার করুন'**
  String get dawah_share_now;

  /// No description provided for @dawah_card_shared_toast.
  ///
  /// In bn, this message translates to:
  /// **'কার্ড শেয়ার করা হয়েছে — জাযাকুমুল্লাহু খাইরান'**
  String get dawah_card_shared_toast;

  /// No description provided for @assessment_status_pending.
  ///
  /// In bn, this message translates to:
  /// **'নিশ্চয়ন বাকি'**
  String get assessment_status_pending;

  /// No description provided for @assessment_status_confirmed.
  ///
  /// In bn, this message translates to:
  /// **'নিশ্চিত হয়েছে'**
  String get assessment_status_confirmed;

  /// No description provided for @assessment_status_declined.
  ///
  /// In bn, this message translates to:
  /// **'বাতিল করেছেন'**
  String get assessment_status_declined;

  /// No description provided for @assessment_confirm_cta.
  ///
  /// In bn, this message translates to:
  /// **'নিশ্চিত করুন'**
  String get assessment_confirm_cta;

  /// No description provided for @assessment_confirm_title.
  ///
  /// In bn, this message translates to:
  /// **'মূল্যায়ন নিশ্চিত করুন'**
  String get assessment_confirm_title;

  /// No description provided for @assessment_confirm_body.
  ///
  /// In bn, this message translates to:
  /// **'ফলাফল দেখে নিন। আপনার মোবাইল নম্বরে কোড পাঠানো হবে — কোড দিয়ে সই দিলেই ফলাফল চূড়ান্ত হবে।'**
  String get assessment_confirm_body;

  /// No description provided for @assessment_confirmed_toast.
  ///
  /// In bn, this message translates to:
  /// **'আলহামদুলিল্লাহ — মূল্যায়ন নিশ্চিত হয়েছে'**
  String get assessment_confirmed_toast;

  /// No description provided for @assessment_decline_cta.
  ///
  /// In bn, this message translates to:
  /// **'ফলাফল বাতিল করুন'**
  String get assessment_decline_cta;

  /// No description provided for @assessment_decline_title.
  ///
  /// In bn, this message translates to:
  /// **'ফলাফল বাতিল করবেন?'**
  String get assessment_decline_title;

  /// No description provided for @assessment_decline_body.
  ///
  /// In bn, this message translates to:
  /// **'বাতিল করলে মূল্যায়নকারীকে জানানো হবে এবং পুনরায় মূল্যায়নের ব্যবস্থা হবে, ইনশাআল্লাহ।'**
  String get assessment_decline_body;

  /// No description provided for @assessment_decline_reason_hint.
  ///
  /// In bn, this message translates to:
  /// **'কারণ (ঐচ্ছিক)'**
  String get assessment_decline_reason_hint;

  /// No description provided for @assessment_decline_label.
  ///
  /// In bn, this message translates to:
  /// **'বাতিল করুন'**
  String get assessment_decline_label;

  /// No description provided for @assessment_declined_toast.
  ///
  /// In bn, this message translates to:
  /// **'মূল্যায়ন বাতিল করা হয়েছে — মূল্যায়নকারীকে জানানো হয়েছে'**
  String get assessment_declined_toast;

  /// No description provided for @assessment_decision_note_label.
  ///
  /// In bn, this message translates to:
  /// **'আপনার কারণ'**
  String get assessment_decision_note_label;

  /// No description provided for @assessment_result_label.
  ///
  /// In bn, this message translates to:
  /// **'ফলাফল'**
  String get assessment_result_label;

  /// No description provided for @assessment_score_label.
  ///
  /// In bn, this message translates to:
  /// **'স্কোর'**
  String get assessment_score_label;

  /// No description provided for @assessment_result_passed.
  ///
  /// In bn, this message translates to:
  /// **'উত্তীর্ণ'**
  String get assessment_result_passed;

  /// No description provided for @assessment_result_not_yet.
  ///
  /// In bn, this message translates to:
  /// **'আরও উন্নতি প্রয়োজন'**
  String get assessment_result_not_yet;

  /// No description provided for @search_title.
  ///
  /// In bn, this message translates to:
  /// **'অনুসন্ধান'**
  String get search_title;

  /// No description provided for @search_hint.
  ///
  /// In bn, this message translates to:
  /// **'দোয়া, আযকার, নাম খুঁজুন…'**
  String get search_hint;

  /// No description provided for @search_no_results.
  ///
  /// In bn, this message translates to:
  /// **'কিছু পাওয়া যায়নি — অন্য শব্দে চেষ্টা করুন'**
  String get search_no_results;

  /// No description provided for @search_offline_note.
  ///
  /// In bn, this message translates to:
  /// **'অফলাইন — অ্যাপের সংরক্ষিত কন্টেন্ট থেকে ফলাফল'**
  String get search_offline_note;

  /// No description provided for @diary_title.
  ///
  /// In bn, this message translates to:
  /// **'আজকের মুহাসাবা'**
  String get diary_title;

  /// No description provided for @diary_done_of.
  ///
  /// In bn, this message translates to:
  /// **'আজ %total%টির মধ্যে %done%টি সম্পন্ন'**
  String get diary_done_of;

  /// No description provided for @diary_pending.
  ///
  /// In bn, this message translates to:
  /// **'এখন যা বাকি'**
  String get diary_pending;

  /// No description provided for @diary_read_now.
  ///
  /// In bn, this message translates to:
  /// **'পড়ুন'**
  String get diary_read_now;

  /// No description provided for @diary_opens_at.
  ///
  /// In bn, this message translates to:
  /// **'%time% থেকে'**
  String get diary_opens_at;

  /// No description provided for @diary_extras.
  ///
  /// In bn, this message translates to:
  /// **'অতিরিক্ত আমল'**
  String get diary_extras;

  /// No description provided for @diary_extras_sub.
  ///
  /// In bn, this message translates to:
  /// **'কাগজের ডায়েরির বাইরে · %done%/%total% সম্পন্ন'**
  String get diary_extras_sub;

  /// No description provided for @diary_instructions.
  ///
  /// In bn, this message translates to:
  /// **'নির্দেশনা'**
  String get diary_instructions;

  /// No description provided for @diary_instructions_title.
  ///
  /// In bn, this message translates to:
  /// **'মুহাসাবা ডায়েরির নির্দেশনাবলী'**
  String get diary_instructions_title;

  /// No description provided for @diary_privacy.
  ///
  /// In bn, this message translates to:
  /// **'আপনার ডায়েরি দেখতে পান শুধু আপনি আর আপনার উসরা প্রধান।'**
  String get diary_privacy;

  /// No description provided for @diary_standing.
  ///
  /// In bn, this message translates to:
  /// **'আপনার অবস্থান'**
  String get diary_standing;

  /// No description provided for @hero_prayer_pending.
  ///
  /// In bn, this message translates to:
  /// **'বাকি'**
  String get hero_prayer_pending;

  /// No description provided for @app_name.
  ///
  /// In bn, this message translates to:
  /// **'সুন্নাহ লাইফ'**
  String get app_name;

  /// No description provided for @quick_post_salah.
  ///
  /// In bn, this message translates to:
  /// **'সালাত পরবর্তী দোয়া'**
  String get quick_post_salah;

  /// No description provided for @quick_post_salah_desc.
  ///
  /// In bn, this message translates to:
  /// **'ফরজ নামাজের পরের আমল'**
  String get quick_post_salah_desc;

  /// No description provided for @quick_adhkar.
  ///
  /// In bn, this message translates to:
  /// **'সকাল-সন্ধ্যার যিকির'**
  String get quick_adhkar;

  /// No description provided for @quick_adhkar_desc.
  ///
  /// In bn, this message translates to:
  /// **'মাসনূন আযকার'**
  String get quick_adhkar_desc;

  /// No description provided for @quick_muhasaba.
  ///
  /// In bn, this message translates to:
  /// **'মুহাসাবা চেকলিস্ট'**
  String get quick_muhasaba;

  /// No description provided for @quick_muhasaba_desc.
  ///
  /// In bn, this message translates to:
  /// **'আজকের ডায়েরি'**
  String get quick_muhasaba_desc;

  /// No description provided for @quick_tracker.
  ///
  /// In bn, this message translates to:
  /// **'আমল ট্র্যাকার'**
  String get quick_tracker;

  /// No description provided for @quick_tracker_desc.
  ///
  /// In bn, this message translates to:
  /// **'মাসের হিসাব'**
  String get quick_tracker_desc;

  /// No description provided for @forbidden_short.
  ///
  /// In bn, this message translates to:
  /// **'নামাজ পড়া নিষেধ'**
  String get forbidden_short;

  /// No description provided for @adhkar_post_salat.
  ///
  /// In bn, this message translates to:
  /// **'নামাজের পরের আযকার'**
  String get adhkar_post_salat;

  /// No description provided for @journey_joined.
  ///
  /// In bn, this message translates to:
  /// **'যোগদান'**
  String get journey_joined;

  /// No description provided for @journey_farze_ain.
  ///
  /// In bn, this message translates to:
  /// **'ফরযে আইন'**
  String get journey_farze_ain;

  /// No description provided for @journey_months.
  ///
  /// In bn, this message translates to:
  /// **'এই স্তরে %n% মাস'**
  String get journey_months;

  /// No description provided for @journey_reqs_met.
  ///
  /// In bn, this message translates to:
  /// **'শর্ত %done%/%total%'**
  String get journey_reqs_met;

  /// No description provided for @review_latest_title.
  ///
  /// In bn, this message translates to:
  /// **'উসরা প্রধানের সাপ্তাহিক মন্তব্য'**
  String get review_latest_title;

  /// No description provided for @review_next_goals.
  ///
  /// In bn, this message translates to:
  /// **'পরের সপ্তাহের লক্ষ্য'**
  String get review_next_goals;

  /// No description provided for @dawah_joined_count.
  ///
  /// In bn, this message translates to:
  /// **'আপনার দাওয়াতে যোগ দিয়েছেন %n% জন'**
  String get dawah_joined_count;

  /// No description provided for @live_watch_now.
  ///
  /// In bn, this message translates to:
  /// **'লাইভ দেখুন'**
  String get live_watch_now;

  /// No description provided for @live_watch_recording.
  ///
  /// In bn, this message translates to:
  /// **'রেকর্ডিং দেখুন'**
  String get live_watch_recording;

  /// No description provided for @live_none_now.
  ///
  /// In bn, this message translates to:
  /// **'এখন কোনো লাইভ কার্যক্রম নেই'**
  String get live_none_now;

  /// No description provided for @live_none_upcoming.
  ///
  /// In bn, this message translates to:
  /// **'আসন্ন কোনো প্রোগ্রাম নেই'**
  String get live_none_upcoming;

  /// No description provided for @live_none_past.
  ///
  /// In bn, this message translates to:
  /// **'এখনো কোনো রেকর্ডিং নেই'**
  String get live_none_past;

  /// No description provided for @profile_workplace.
  ///
  /// In bn, this message translates to:
  /// **'কর্মস্থল / প্রতিষ্ঠান'**
  String get profile_workplace;

  /// No description provided for @profile_department.
  ///
  /// In bn, this message translates to:
  /// **'বিভাগ / পদবি'**
  String get profile_department;

  /// No description provided for @profile_district.
  ///
  /// In bn, this message translates to:
  /// **'জেলা'**
  String get profile_district;

  /// No description provided for @profile_not_set.
  ///
  /// In bn, this message translates to:
  /// **'যোগ করুন'**
  String get profile_not_set;

  /// No description provided for @profile_saved.
  ///
  /// In bn, this message translates to:
  /// **'সংরক্ষিত হয়েছে'**
  String get profile_saved;

  /// No description provided for @profile_inventory_note.
  ///
  /// In bn, this message translates to:
  /// **'এই তথ্য দাওয়াতুস সুন্নাহর সদস্য-তালিকার জন্য — শুধু আপনার দায়িত্বশীলরা দেখতে পান।'**
  String get profile_inventory_note;

  /// No description provided for @quizres_title.
  ///
  /// In bn, this message translates to:
  /// **'সদস্যদের কুইজ ফলাফল'**
  String get quizres_title;

  /// No description provided for @quizres_took.
  ///
  /// In bn, this message translates to:
  /// **'অংশ নিয়েছেন %done%/%total% জন'**
  String get quizres_took;

  /// No description provided for @quizres_avg.
  ///
  /// In bn, this message translates to:
  /// **'গড় %n%%'**
  String get quizres_avg;

  /// No description provided for @quizres_not_yet.
  ///
  /// In bn, this message translates to:
  /// **'এখনো দেননি'**
  String get quizres_not_yet;

  /// No description provided for @quizres_tries.
  ///
  /// In bn, this message translates to:
  /// **'%n% বার'**
  String get quizres_tries;

  /// No description provided for @quizres_no_members.
  ///
  /// In bn, this message translates to:
  /// **'উসরাহতে এখনো কোনো সদস্য নেই'**
  String get quizres_no_members;

  /// No description provided for @quizres_hint.
  ///
  /// In bn, this message translates to:
  /// **'যাঁরা এখনো দেননি, তাঁদের উৎসাহ দিন — কুইজ ইলম বিভাগে আছে।'**
  String get quizres_hint;

  /// No description provided for @quiz_upcoming.
  ///
  /// In bn, this message translates to:
  /// **'আসন্ন কুইজ'**
  String get quiz_upcoming;

  /// No description provided for @quiz_today.
  ///
  /// In bn, this message translates to:
  /// **'আজ'**
  String get quiz_today;

  /// No description provided for @quiz_tomorrow.
  ///
  /// In bn, this message translates to:
  /// **'আগামীকাল'**
  String get quiz_tomorrow;

  /// No description provided for @quiz_in_days.
  ///
  /// In bn, this message translates to:
  /// **'%n% দিন পর'**
  String get quiz_in_days;

  /// No description provided for @quiz_live_now.
  ///
  /// In bn, this message translates to:
  /// **'এখন চলছে'**
  String get quiz_live_now;

  /// No description provided for @quiz_join_live.
  ///
  /// In bn, this message translates to:
  /// **'লাইভ কুইজে যোগ দিন'**
  String get quiz_join_live;

  /// No description provided for @quiz_practice.
  ///
  /// In bn, this message translates to:
  /// **'আগে অনুশীলন করুন'**
  String get quiz_practice;

  /// No description provided for @guest_nudge_title.
  ///
  /// In bn, this message translates to:
  /// **'আপনার আমলের হিসাব নিরাপদ রাখুন'**
  String get guest_nudge_title;

  /// No description provided for @guest_nudge_backup.
  ///
  /// In bn, this message translates to:
  /// **'ডায়েরি সংরক্ষিত থাকবে — ফোন বদলালেও হারাবে না'**
  String get guest_nudge_backup;

  /// No description provided for @guest_nudge_usrah.
  ///
  /// In bn, this message translates to:
  /// **'উসরায় যুক্ত হয়ে দায়িত্বশীলের পরামর্শ পাবেন'**
  String get guest_nudge_usrah;

  /// No description provided for @guest_nudge_journey.
  ///
  /// In bn, this message translates to:
  /// **'মুহিব্বুস সুন্নাহ থেকে ফরযে আইন — নিজের অগ্রগতি দেখবেন'**
  String get guest_nudge_journey;

  /// No description provided for @guest_nudge_cta.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাকাউন্ট খুলুন'**
  String get guest_nudge_cta;

  /// No description provided for @guest_nudge_later.
  ///
  /// In bn, this message translates to:
  /// **'পরে'**
  String get guest_nudge_later;

  /// No description provided for @notifications_for_you.
  ///
  /// In bn, this message translates to:
  /// **'আপনার জন্য'**
  String get notifications_for_you;

  /// No description provided for @notif_now.
  ///
  /// In bn, this message translates to:
  /// **'এখন'**
  String get notif_now;

  /// No description provided for @notif_next.
  ///
  /// In bn, this message translates to:
  /// **'পরবর্তী'**
  String get notif_next;

  /// No description provided for @notif_left.
  ///
  /// In bn, this message translates to:
  /// **'বাকি'**
  String get notif_left;

  /// No description provided for @notif_hours.
  ///
  /// In bn, this message translates to:
  /// **'ঘণ্টা'**
  String get notif_hours;

  /// No description provided for @notif_minutes.
  ///
  /// In bn, this message translates to:
  /// **'মিনিট'**
  String get notif_minutes;

  /// No description provided for @profile_phone.
  ///
  /// In bn, this message translates to:
  /// **'মোবাইল নম্বর'**
  String get profile_phone;

  /// No description provided for @profile_email.
  ///
  /// In bn, this message translates to:
  /// **'ইমেইল'**
  String get profile_email;

  /// No description provided for @profile_phone_change_title.
  ///
  /// In bn, this message translates to:
  /// **'মোবাইল নম্বর যোগ / পরিবর্তন'**
  String get profile_phone_change_title;

  /// No description provided for @profile_phone_change_hint.
  ///
  /// In bn, this message translates to:
  /// **'নতুন নম্বরে একটি কোড যাবে — কোড মিলিয়ে দিলে এই নম্বরেই আপনি লগইন করবেন।'**
  String get profile_phone_change_hint;

  /// No description provided for @profile_phone_new.
  ///
  /// In bn, this message translates to:
  /// **'নতুন মোবাইল নম্বর'**
  String get profile_phone_new;

  /// No description provided for @profile_phone_send_code.
  ///
  /// In bn, this message translates to:
  /// **'কোড পাঠান'**
  String get profile_phone_send_code;

  /// No description provided for @profile_phone_verify.
  ///
  /// In bn, this message translates to:
  /// **'নিশ্চিত করুন'**
  String get profile_phone_verify;

  /// No description provided for @profile_phone_changed.
  ///
  /// In bn, this message translates to:
  /// **'মোবাইল নম্বর পরিবর্তন হয়েছে'**
  String get profile_phone_changed;

  /// No description provided for @mosque_view_list.
  ///
  /// In bn, this message translates to:
  /// **'তালিকা'**
  String get mosque_view_list;

  /// No description provided for @mosque_view_map.
  ///
  /// In bn, this message translates to:
  /// **'ম্যাপ'**
  String get mosque_view_map;

  /// No description provided for @mosque_directions_btn.
  ///
  /// In bn, this message translates to:
  /// **'পথ দেখুন'**
  String get mosque_directions_btn;

  /// No description provided for @mosque_search_more.
  ///
  /// In bn, this message translates to:
  /// **'আশেপাশের আরও মসজিদ (Google Maps)'**
  String get mosque_search_more;

  /// No description provided for @mosque_north.
  ///
  /// In bn, this message translates to:
  /// **'উ'**
  String get mosque_north;

  /// No description provided for @mosque_you.
  ///
  /// In bn, this message translates to:
  /// **'আপনি'**
  String get mosque_you;

  /// No description provided for @iman_check_title.
  ///
  /// In bn, this message translates to:
  /// **'ঈমানের শাখা — আত্মমূল্যায়ন'**
  String get iman_check_title;

  /// No description provided for @iman_check_entry_hint.
  ///
  /// In bn, this message translates to:
  /// **'৬৯টি শাখায় নিজেকে মিলিয়ে দেখুন — ফলাফল শুধু আপনার ফোনে থাকে'**
  String get iman_check_entry_hint;

  /// No description provided for @iman_check_last.
  ///
  /// In bn, this message translates to:
  /// **'সর্বশেষ ফলাফল: %n%% — আবার মিলিয়ে দেখুন'**
  String get iman_check_last;

  /// No description provided for @iman_check_intro.
  ///
  /// In bn, this message translates to:
  /// **'এটা বিচার নয়, নিজের মুহাসাবা। প্রতিটি শাখায় সৎভাবে নিজের অবস্থা বাছাই করুন।'**
  String get iman_check_intro;

  /// No description provided for @iman_check_have.
  ///
  /// In bn, this message translates to:
  /// **'আছে, আলহামদুলিল্লাহ'**
  String get iman_check_have;

  /// No description provided for @iman_check_trying.
  ///
  /// In bn, this message translates to:
  /// **'চেষ্টা করছি'**
  String get iman_check_trying;

  /// No description provided for @iman_check_not_yet.
  ///
  /// In bn, this message translates to:
  /// **'এখনো নয়'**
  String get iman_check_not_yet;

  /// No description provided for @iman_check_left.
  ///
  /// In bn, this message translates to:
  /// **'আরও %n%টি বাকি'**
  String get iman_check_left;

  /// No description provided for @iman_check_see_result.
  ///
  /// In bn, this message translates to:
  /// **'ফলাফল দেখুন'**
  String get iman_check_see_result;

  /// No description provided for @iman_check_result_caption.
  ///
  /// In bn, this message translates to:
  /// **'ঈমানের শাখাগুলোতে আপনার নিজের মূল্যায়ন'**
  String get iman_check_result_caption;

  /// No description provided for @iman_check_previous.
  ///
  /// In bn, this message translates to:
  /// **'আগেরবার: %n%%'**
  String get iman_check_previous;

  /// No description provided for @iman_check_focus.
  ///
  /// In bn, this message translates to:
  /// **'এখন যেগুলোতে মনোযোগ দিন'**
  String get iman_check_focus;

  /// No description provided for @iman_check_keep_going.
  ///
  /// In bn, this message translates to:
  /// **'চেষ্টা চালিয়ে যান'**
  String get iman_check_keep_going;

  /// No description provided for @iman_check_private.
  ///
  /// In bn, this message translates to:
  /// **'এই উত্তরগুলো কেবল আপনার ফোনে সংরক্ষিত — কেউ দেখতে পান না।'**
  String get iman_check_private;

  /// No description provided for @iman_check_retake.
  ///
  /// In bn, this message translates to:
  /// **'আবার মূল্যায়ন করুন'**
  String get iman_check_retake;

  /// No description provided for @iman_check_appbar.
  ///
  /// In bn, this message translates to:
  /// **'ঈমান আত্মমূল্যায়ন'**
  String get iman_check_appbar;

  /// No description provided for @auth_not_now.
  ///
  /// In bn, this message translates to:
  /// **'এখন নয়'**
  String get auth_not_now;

  /// No description provided for @auth_welcome.
  ///
  /// In bn, this message translates to:
  /// **'সুন্নাহ লাইফে স্বাগতম'**
  String get auth_welcome;

  /// No description provided for @auth_welcome_sub.
  ///
  /// In bn, this message translates to:
  /// **'একটি অ্যাকাউন্ট খুলুন বা আগেরটিতে ঢুকুন — এক মিনিট লাগে'**
  String get auth_welcome_sub;

  /// No description provided for @auth_google_continue.
  ///
  /// In bn, this message translates to:
  /// **'Google দিয়ে চালিয়ে যান'**
  String get auth_google_continue;

  /// No description provided for @auth_google_hint.
  ///
  /// In bn, this message translates to:
  /// **'সবচেয়ে সহজ — কোনো কোড লাগে না'**
  String get auth_google_hint;

  /// No description provided for @auth_or_phone.
  ///
  /// In bn, this message translates to:
  /// **'অথবা মোবাইল নম্বর দিয়ে'**
  String get auth_or_phone;

  /// No description provided for @auth_code_sent_to.
  ///
  /// In bn, this message translates to:
  /// **'%n% নম্বরে ৬ সংখ্যার কোড পাঠানো হয়েছে'**
  String get auth_code_sent_to;

  /// No description provided for @auth_change_number.
  ///
  /// In bn, this message translates to:
  /// **'নম্বর বদলান'**
  String get auth_change_number;

  /// No description provided for @auth_dev_fill.
  ///
  /// In bn, this message translates to:
  /// **'বসিয়ে দিন'**
  String get auth_dev_fill;

  /// No description provided for @auth_resend_in.
  ///
  /// In bn, this message translates to:
  /// **'%n% সেকেন্ড পর আবার পাঠানো যাবে'**
  String get auth_resend_in;

  /// No description provided for @auth_resend.
  ///
  /// In bn, this message translates to:
  /// **'কোড আবার পাঠান'**
  String get auth_resend;

  /// No description provided for @auth_privacy.
  ///
  /// In bn, this message translates to:
  /// **'আপনার তথ্য সুরক্ষিত — বোনদের তথ্য শুধু বোন দায়িত্বশীলরাই দেখতে পান।'**
  String get auth_privacy;

  /// No description provided for @home_muhasaba_title.
  ///
  /// In bn, this message translates to:
  /// **'আজকের মুহাসাবা'**
  String get home_muhasaba_title;

  /// No description provided for @home_muhasaba_pending.
  ///
  /// In bn, this message translates to:
  /// **'বাকি'**
  String get home_muhasaba_pending;

  /// No description provided for @home_muhasaba_on_track.
  ///
  /// In bn, this message translates to:
  /// **'এখন পর্যন্ত যা সময় হয়েছে, সব লেখা হয়েছে — আলহামদুলিল্লাহ'**
  String get home_muhasaba_on_track;

  /// No description provided for @home_muhasaba_all_done.
  ///
  /// In bn, this message translates to:
  /// **'আজকের ডায়েরি সম্পূর্ণ — আলহামদুলিল্লাহ'**
  String get home_muhasaba_all_done;

  /// No description provided for @home_muhasaba_start.
  ///
  /// In bn, this message translates to:
  /// **'আজকের ডায়েরি শুরু করুন'**
  String get home_muhasaba_start;

  /// No description provided for @home_muhasaba_continue.
  ///
  /// In bn, this message translates to:
  /// **'ডায়েরি পূরণ করুন'**
  String get home_muhasaba_continue;

  /// No description provided for @home_pending_morning_adhkar.
  ///
  /// In bn, this message translates to:
  /// **'সকালের আযকার'**
  String get home_pending_morning_adhkar;

  /// No description provided for @home_pending_evening_adhkar.
  ///
  /// In bn, this message translates to:
  /// **'সন্ধ্যার আযকার'**
  String get home_pending_evening_adhkar;

  /// No description provided for @month_paper_grid.
  ///
  /// In bn, this message translates to:
  /// **'পুরো মাসের ডায়েরি (কাগজের মতো)'**
  String get month_paper_grid;

  /// No description provided for @month_legend_none.
  ///
  /// In bn, this message translates to:
  /// **'লেখা হয়নি'**
  String get month_legend_none;

  /// No description provided for @month_legend_some.
  ///
  /// In bn, this message translates to:
  /// **'আংশিক'**
  String get month_legend_some;

  /// No description provided for @month_legend_full.
  ///
  /// In bn, this message translates to:
  /// **'প্রায় সম্পূর্ণ'**
  String get month_legend_full;

  /// No description provided for @weekday_short_0.
  ///
  /// In bn, this message translates to:
  /// **'রবি'**
  String get weekday_short_0;

  /// No description provided for @weekday_short_1.
  ///
  /// In bn, this message translates to:
  /// **'সোম'**
  String get weekday_short_1;

  /// No description provided for @weekday_short_2.
  ///
  /// In bn, this message translates to:
  /// **'মঙ্গল'**
  String get weekday_short_2;

  /// No description provided for @weekday_short_3.
  ///
  /// In bn, this message translates to:
  /// **'বুধ'**
  String get weekday_short_3;

  /// No description provided for @weekday_short_4.
  ///
  /// In bn, this message translates to:
  /// **'বৃহঃ'**
  String get weekday_short_4;

  /// No description provided for @weekday_short_5.
  ///
  /// In bn, this message translates to:
  /// **'শুক্র'**
  String get weekday_short_5;

  /// No description provided for @weekday_short_6.
  ///
  /// In bn, this message translates to:
  /// **'শনি'**
  String get weekday_short_6;

  /// No description provided for @masala_mine.
  ///
  /// In bn, this message translates to:
  /// **'আমার প্রশ্ন ও উত্তর'**
  String get masala_mine;

  /// No description provided for @masala_answered.
  ///
  /// In bn, this message translates to:
  /// **'উত্তর এসেছে'**
  String get masala_answered;

  /// No description provided for @masala_pending.
  ///
  /// In bn, this message translates to:
  /// **'উত্তরের অপেক্ষায়'**
  String get masala_pending;

  /// No description provided for @bell_on_for_waqt.
  ///
  /// In bn, this message translates to:
  /// **'এই ওয়াক্তে অ্যালার্ম'**
  String get bell_on_for_waqt;

  /// No description provided for @courses_ongoing.
  ///
  /// In bn, this message translates to:
  /// **'চলমান কোর্স'**
  String get courses_ongoing;

  /// No description provided for @courses_done.
  ///
  /// In bn, this message translates to:
  /// **'সম্পন্ন কোর্স'**
  String get courses_done;

  /// No description provided for @courses_more.
  ///
  /// In bn, this message translates to:
  /// **'আরও কোর্স'**
  String get courses_more;

  /// No description provided for @courses_all.
  ///
  /// In bn, this message translates to:
  /// **'সব কোর্স'**
  String get courses_all;

  /// No description provided for @quiz_past.
  ///
  /// In bn, this message translates to:
  /// **'আগের লাইভ কুইজ'**
  String get quiz_past;

  /// No description provided for @quiz_take_it.
  ///
  /// In bn, this message translates to:
  /// **'কুইজটি দিন'**
  String get quiz_take_it;

  /// No description provided for @dawah_tab_mine.
  ///
  /// In bn, this message translates to:
  /// **'আমার পথ'**
  String get dawah_tab_mine;

  /// No description provided for @notifications_foundation.
  ///
  /// In bn, this message translates to:
  /// **'ফাউন্ডেশনের ঘোষণা'**
  String get notifications_foundation;

  /// No description provided for @goal_reminder_set.
  ///
  /// In bn, this message translates to:
  /// **'রিমাইন্ডার দিন'**
  String get goal_reminder_set;

  /// No description provided for @goal_reminder_pick.
  ///
  /// In bn, this message translates to:
  /// **'প্রতিদিন কখন মনে করিয়ে দেব?'**
  String get goal_reminder_pick;

  /// No description provided for @goal_reminder_daily.
  ///
  /// In bn, this message translates to:
  /// **'প্রতিদিন %time%'**
  String get goal_reminder_daily;

  /// No description provided for @goal_reminder_change.
  ///
  /// In bn, this message translates to:
  /// **'বদলান'**
  String get goal_reminder_change;

  /// No description provided for @goal_reminder_off.
  ///
  /// In bn, this message translates to:
  /// **'রিমাইন্ডার বন্ধ'**
  String get goal_reminder_off;

  /// No description provided for @goal_reminder_body.
  ///
  /// In bn, this message translates to:
  /// **'আজ লক্ষ্যটি পূরণ হয়েছে? ডায়েরিতে লিখে রাখুন।'**
  String get goal_reminder_body;

  /// No description provided for @prayer_forbidden_title.
  ///
  /// In bn, this message translates to:
  /// **'নামাজ পড়া নিষেধ'**
  String get prayer_forbidden_title;

  /// No description provided for @forbidden_short_sunrise.
  ///
  /// In bn, this message translates to:
  /// **'সূর্যোদয়'**
  String get forbidden_short_sunrise;

  /// No description provided for @forbidden_short_zawal.
  ///
  /// In bn, this message translates to:
  /// **'যাওয়াল'**
  String get forbidden_short_zawal;

  /// No description provided for @forbidden_short_sunset.
  ///
  /// In bn, this message translates to:
  /// **'সূর্যাস্ত'**
  String get forbidden_short_sunset;

  /// No description provided for @madu_active_ago.
  ///
  /// In bn, this message translates to:
  /// **'%t% সক্রিয়'**
  String get madu_active_ago;

  /// No description provided for @review_this_week.
  ///
  /// In bn, this message translates to:
  /// **'এই সপ্তাহ'**
  String get review_this_week;

  /// No description provided for @review_last_week.
  ///
  /// In bn, this message translates to:
  /// **'গত সপ্তাহ'**
  String get review_last_week;

  /// No description provided for @delete_account_entry.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাকাউন্ট মুছে ফেলুন'**
  String get delete_account_entry;

  /// No description provided for @delete_account_title.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাকাউন্ট মুছে ফেলবেন?'**
  String get delete_account_title;

  /// No description provided for @delete_account_goes.
  ///
  /// In bn, this message translates to:
  /// **'যা মুছে যাবে:'**
  String get delete_account_goes;

  /// No description provided for @delete_account_goes_1.
  ///
  /// In bn, this message translates to:
  /// **'আপনার মুহাসাবা ডায়েরি, লক্ষ্য, রিভিউ ও মূল্যায়ন'**
  String get delete_account_goes_1;

  /// No description provided for @delete_account_goes_2.
  ///
  /// In bn, this message translates to:
  /// **'আপনার প্রশ্ন, মতামত ও সাপোর্ট বার্তা'**
  String get delete_account_goes_2;

  /// No description provided for @delete_account_goes_3.
  ///
  /// In bn, this message translates to:
  /// **'নাম, ফোন নম্বর, ইমেইল, সদস্য কোড ও গুগল লগইন'**
  String get delete_account_goes_3;

  /// No description provided for @delete_account_stays.
  ///
  /// In bn, this message translates to:
  /// **'যা থাকবে (নাম ছাড়া):'**
  String get delete_account_stays;

  /// No description provided for @delete_account_stays_1.
  ///
  /// In bn, this message translates to:
  /// **'অন্যদের জন্য আপনি যা লিখেছেন, যেমন তাদের দেওয়া রিভিউ বা ঘোষণা — সেখানে লেখা থাকবে “মুছে ফেলা অ্যাকাউন্ট”'**
  String get delete_account_stays_1;

  /// No description provided for @delete_account_final.
  ///
  /// In bn, this message translates to:
  /// **'এটি ফেরানো যাবে না।'**
  String get delete_account_final;

  /// No description provided for @delete_account_confirm_tick.
  ///
  /// In bn, this message translates to:
  /// **'আমি বুঝেছি, আমার অ্যাকাউন্ট মুছে ফেলতে চাই'**
  String get delete_account_confirm_tick;

  /// No description provided for @delete_account_button.
  ///
  /// In bn, this message translates to:
  /// **'স্থায়ীভাবে মুছে ফেলুন'**
  String get delete_account_button;

  /// No description provided for @delete_account_done.
  ///
  /// In bn, this message translates to:
  /// **'আপনার অ্যাকাউন্ট মুছে ফেলা হয়েছে'**
  String get delete_account_done;

  /// No description provided for @delete_account_failed.
  ///
  /// In bn, this message translates to:
  /// **'মুছতে পারা যায়নি — ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন'**
  String get delete_account_failed;

  /// No description provided for @privacy_policy.
  ///
  /// In bn, this message translates to:
  /// **'গোপনীয়তা নীতি'**
  String get privacy_policy;

  /// No description provided for @privacy_policy_sub.
  ///
  /// In bn, this message translates to:
  /// **'কোন তথ্য রাখা হয়, কারা দেখেন, কীভাবে মুছবেন'**
  String get privacy_policy_sub;

  /// No description provided for @goals_load_failed.
  ///
  /// In bn, this message translates to:
  /// **'লক্ষ্যগুলো আনা যায়নি — ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন'**
  String get goals_load_failed;

  /// No description provided for @exercise_title.
  ///
  /// In bn, this message translates to:
  /// **'শরীরচর্চা'**
  String get exercise_title;

  /// No description provided for @exercise_today.
  ///
  /// In bn, this message translates to:
  /// **'আজকের শরীরচর্চা'**
  String get exercise_today;

  /// No description provided for @exercise_min.
  ///
  /// In bn, this message translates to:
  /// **'মিনিট'**
  String get exercise_min;

  /// No description provided for @exercise_goal_done.
  ///
  /// In bn, this message translates to:
  /// **'আজকের লক্ষ্য পূরণ হয়েছে — আলহামদুলিল্লাহ'**
  String get exercise_goal_done;

  /// No description provided for @exercise_more.
  ///
  /// In bn, this message translates to:
  /// **'লক্ষ্য পূরণে আর'**
  String get exercise_more;

  /// No description provided for @exercise_add.
  ///
  /// In bn, this message translates to:
  /// **'সেশন যোগ করুন'**
  String get exercise_add;

  /// No description provided for @exercise_add_button.
  ///
  /// In bn, this message translates to:
  /// **'ডায়েরিতে যোগ করুন'**
  String get exercise_add_button;

  /// No description provided for @exercise_saved.
  ///
  /// In bn, this message translates to:
  /// **'ডায়েরিতে যোগ হয়েছে'**
  String get exercise_saved;

  /// No description provided for @exercise_less.
  ///
  /// In bn, this message translates to:
  /// **'৫ মিনিট কমান'**
  String get exercise_less;

  /// No description provided for @exercise_more_btn.
  ///
  /// In bn, this message translates to:
  /// **'৫ মিনিট বাড়ান'**
  String get exercise_more_btn;

  /// No description provided for @exercise_sessions_today.
  ///
  /// In bn, this message translates to:
  /// **'আজকের সেশন'**
  String get exercise_sessions_today;

  /// No description provided for @exercise_undo.
  ///
  /// In bn, this message translates to:
  /// **'সেশনটি বাদ দিন'**
  String get exercise_undo;

  /// No description provided for @exercise_week.
  ///
  /// In bn, this message translates to:
  /// **'গত ৭ দিন'**
  String get exercise_week;

  /// No description provided for @exercise_week_total.
  ///
  /// In bn, this message translates to:
  /// **'এই ৭ দিনে মোট'**
  String get exercise_week_total;

  /// No description provided for @exercise_week_note.
  ///
  /// In bn, this message translates to:
  /// **'বিশ্ব স্বাস্থ্য সংস্থার পরামর্শ: সপ্তাহে অন্তত ১৫০ মিনিট মাঝারি শরীরচর্চা।'**
  String get exercise_week_note;

  /// No description provided for @exercise_hadith.
  ///
  /// In bn, this message translates to:
  /// **'“শক্তিশালী মুমিন আল্লাহর কাছে দুর্বল মুমিনের চেয়ে উত্তম ও প্রিয়।” — সহীহ মুসলিম ২৬৬৪'**
  String get exercise_hadith;

  /// No description provided for @exercise_type_walk.
  ///
  /// In bn, this message translates to:
  /// **'হাঁটা'**
  String get exercise_type_walk;

  /// No description provided for @exercise_type_run.
  ///
  /// In bn, this message translates to:
  /// **'দৌড়'**
  String get exercise_type_run;

  /// No description provided for @exercise_type_bike.
  ///
  /// In bn, this message translates to:
  /// **'সাইকেল'**
  String get exercise_type_bike;

  /// No description provided for @exercise_type_workout.
  ///
  /// In bn, this message translates to:
  /// **'ব্যায়াম'**
  String get exercise_type_workout;

  /// No description provided for @exercise_type_sport.
  ///
  /// In bn, this message translates to:
  /// **'খেলাধুলা'**
  String get exercise_type_sport;

  /// No description provided for @exercise_type_swim.
  ///
  /// In bn, this message translates to:
  /// **'সাঁতার'**
  String get exercise_type_swim;

  /// No description provided for @exercise_type_other.
  ///
  /// In bn, this message translates to:
  /// **'অন্যান্য'**
  String get exercise_type_other;

  /// No description provided for @sun_now_running.
  ///
  /// In bn, this message translates to:
  /// **'এখন চলছে'**
  String get sun_now_running;

  /// No description provided for @sun_now.
  ///
  /// In bn, this message translates to:
  /// **'এখন'**
  String get sun_now;

  /// No description provided for @sun_next.
  ///
  /// In bn, this message translates to:
  /// **'পরবর্তী'**
  String get sun_next;

  /// No description provided for @sun_after_sunrise.
  ///
  /// In bn, this message translates to:
  /// **'সূর্যোদয়ের পর'**
  String get sun_after_sunrise;

  /// No description provided for @sun_wait_dhuhr.
  ///
  /// In bn, this message translates to:
  /// **'যোহরের অপেক্ষা'**
  String get sun_wait_dhuhr;

  /// No description provided for @sun_wait_jumuah.
  ///
  /// In bn, this message translates to:
  /// **'জুমার অপেক্ষা'**
  String get sun_wait_jumuah;

  /// No description provided for @sun_running.
  ///
  /// In bn, this message translates to:
  /// **'চলমান'**
  String get sun_running;

  /// No description provided for @sun_ishraq_duha_time.
  ///
  /// In bn, this message translates to:
  /// **'ইশরাক ও চাশতের সময়'**
  String get sun_ishraq_duha_time;

  /// No description provided for @sun_hours.
  ///
  /// In bn, this message translates to:
  /// **'ঘণ্টা'**
  String get sun_hours;

  /// No description provided for @sun_minutes.
  ///
  /// In bn, this message translates to:
  /// **'মিনিট'**
  String get sun_minutes;

  /// No description provided for @sun_left.
  ///
  /// In bn, this message translates to:
  /// **'বাকি'**
  String get sun_left;

  /// No description provided for @sun_noon.
  ///
  /// In bn, this message translates to:
  /// **'মধ্যাহ্ন'**
  String get sun_noon;

  /// No description provided for @sun_forbidden_now.
  ///
  /// In bn, this message translates to:
  /// **'এখন নামাজ পড়া নিষেধ'**
  String get sun_forbidden_now;

  /// No description provided for @sun_until_fmt.
  ///
  /// In bn, this message translates to:
  /// **'%t পর্যন্ত'**
  String get sun_until_fmt;

  /// No description provided for @jumuah.
  ///
  /// In bn, this message translates to:
  /// **'জুমা'**
  String get jumuah;

  /// No description provided for @sched_from_fmt.
  ///
  /// In bn, this message translates to:
  /// **'%t থেকে'**
  String get sched_from_fmt;

  /// No description provided for @sched_ramadan.
  ///
  /// In bn, this message translates to:
  /// **'রমজান'**
  String get sched_ramadan;

  /// No description provided for @sched_sehri_end.
  ///
  /// In bn, this message translates to:
  /// **'সাহরির শেষ'**
  String get sched_sehri_end;

  /// No description provided for @sched_iftar.
  ///
  /// In bn, this message translates to:
  /// **'ইফতার'**
  String get sched_iftar;

  /// No description provided for @hijri_suffix.
  ///
  /// In bn, this message translates to:
  /// **'হিজরি'**
  String get hijri_suffix;

  /// No description provided for @most_used_days_fmt.
  ///
  /// In bn, this message translates to:
  /// **'৩০ দিনে %n দিন'**
  String get most_used_days_fmt;

  /// No description provided for @most_used_done.
  ///
  /// In bn, this message translates to:
  /// **'আজ হয়েছে'**
  String get most_used_done;

  /// No description provided for @live_today.
  ///
  /// In bn, this message translates to:
  /// **'আজ'**
  String get live_today;

  /// No description provided for @live_tomorrow.
  ///
  /// In bn, this message translates to:
  /// **'আগামীকাল'**
  String get live_tomorrow;

  /// No description provided for @live_in_days_fmt.
  ///
  /// In bn, this message translates to:
  /// **'%n দিন পর'**
  String get live_in_days_fmt;

  /// No description provided for @live_badge.
  ///
  /// In bn, this message translates to:
  /// **'লাইভ'**
  String get live_badge;

  /// No description provided for @guest_nudge_sub.
  ///
  /// In bn, this message translates to:
  /// **'অ্যাকাউন্ট খুললে যা পাবেন'**
  String get guest_nudge_sub;

  /// No description provided for @article_cat_dawah.
  ///
  /// In bn, this message translates to:
  /// **'দাওয়াহ'**
  String get article_cat_dawah;

  /// No description provided for @article_cat_sunnah.
  ///
  /// In bn, this message translates to:
  /// **'সুন্নাহ'**
  String get article_cat_sunnah;

  /// No description provided for @article_cat_tarbiyah.
  ///
  /// In bn, this message translates to:
  /// **'তারবিয়াহ'**
  String get article_cat_tarbiyah;

  /// No description provided for @article_read_min.
  ///
  /// In bn, this message translates to:
  /// **'মিনিট পড়া'**
  String get article_read_min;

  /// No description provided for @article_read.
  ///
  /// In bn, this message translates to:
  /// **'পড়ুন'**
  String get article_read;

  /// No description provided for @chip_habit.
  ///
  /// In bn, this message translates to:
  /// **'অভ্যাস চ্যালেঞ্জ'**
  String get chip_habit;

  /// No description provided for @chip_self_test.
  ///
  /// In bn, this message translates to:
  /// **'সেলফ-টেস্ট'**
  String get chip_self_test;

  /// No description provided for @chip_goals.
  ///
  /// In bn, this message translates to:
  /// **'লক্ষ্য'**
  String get chip_goals;

  /// No description provided for @chip_usrah_q.
  ///
  /// In bn, this message translates to:
  /// **'প্রশ্নোত্তর'**
  String get chip_usrah_q;

  /// No description provided for @exercise_week_empty.
  ///
  /// In bn, this message translates to:
  /// **'এই সপ্তাহে এখনো কিছু লেখা হয়নি — উপরে আজকের শরীরচর্চা যোগ করুন'**
  String get exercise_week_empty;

  /// No description provided for @self_test_quizzes.
  ///
  /// In bn, this message translates to:
  /// **'নিজেকে যাচাই করুন'**
  String get self_test_quizzes;

  /// No description provided for @live_none_all.
  ///
  /// In bn, this message translates to:
  /// **'এখন কোনো লাইভ প্রোগ্রাম নেই। নতুন প্রোগ্রাম ঘোষণা হলে এখানে দেখা যাবে, ইনশাআল্লাহ।'**
  String get live_none_all;

  /// No description provided for @about_faq_sub.
  ///
  /// In bn, this message translates to:
  /// **'নামাজ, আমল ও অ্যাপ নিয়ে সাধারণ প্রশ্নের উত্তর'**
  String get about_faq_sub;

  /// No description provided for @autosilent_grant_first.
  ///
  /// In bn, this message translates to:
  /// **'আগে উপরের অনুমতিটি দিন'**
  String get autosilent_grant_first;

  /// No description provided for @dawah_assess_empty.
  ///
  /// In bn, this message translates to:
  /// **'এখনো কোনো মূল্যায়ন হয়নি। দায়িত্বশীল আপনার মূল্যায়ন করলে ফল এখানে দেখা যাবে।'**
  String get dawah_assess_empty;

  /// No description provided for @dawah_req_fallback_note.
  ///
  /// In bn, this message translates to:
  /// **'সর্বশেষ চেকলিস্ট আনা যায়নি — আগের সারসংক্ষেপ দেখানো হচ্ছে'**
  String get dawah_req_fallback_note;

  /// No description provided for @habit_mark_today.
  ///
  /// In bn, this message translates to:
  /// **'আজ করেছি'**
  String get habit_mark_today;

  /// No description provided for @search_try.
  ///
  /// In bn, this message translates to:
  /// **'যা খুঁজতে পারেন'**
  String get search_try;
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
