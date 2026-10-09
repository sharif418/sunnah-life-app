// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get retry => 'Retry';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get done => 'Done';

  @override
  String get search => 'Search';

  @override
  String get share => 'Share';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get see_all => 'See all';

  @override
  String get loading => 'Loading…';

  @override
  String get empty_generic => 'Nothing here yet';

  @override
  String get error_generic => 'Something went wrong';

  @override
  String get offline => 'Offline — changes are saved and will sync later';

  @override
  String get offline_short => 'Offline';

  @override
  String get online => 'Online';

  @override
  String get guest => 'Guest';

  @override
  String get version => 'Version';

  @override
  String get tab_home => 'Home';

  @override
  String get tab_amal => 'Amal';

  @override
  String get tab_dawah => 'Da\'wah';

  @override
  String get tab_ilm => 'Ilm';

  @override
  String get tab_more => 'More';

  @override
  String get onb_title => 'Welcome to Sunnah Life';

  @override
  String get onb_step1_title => 'Choose your language';

  @override
  String get onb_step2_title => 'About you';

  @override
  String get onb_name => 'Name';

  @override
  String get onb_name_hint => 'e.g. Abdullah';

  @override
  String get onb_gender => 'Gender';

  @override
  String get onb_male => 'Brother (Male)';

  @override
  String get onb_female => 'Sister (Female)';

  @override
  String get onb_female_privacy =>
      'Our pledge to sisters: your name, amal and identity are visible only to female supervisors and female usrah heads. Male supervisors and admins can never see female member data — enforced in the database itself.';

  @override
  String get onb_step3_title => 'Location & madhhab';

  @override
  String get onb_city => 'City';

  @override
  String get onb_city_search => 'Type a city name…';

  @override
  String get onb_madhhab => 'Madhhab (Asr)';

  @override
  String get onb_method => 'Calculation method';

  @override
  String get onb_custom_location => 'Custom latitude/longitude';

  @override
  String get onb_lat => 'Latitude';

  @override
  String get onb_lng => 'Longitude';

  @override
  String get onb_start => 'Start as guest';

  @override
  String get onb_signin => 'Sign in';

  @override
  String get auth_title => 'Sign in with phone';

  @override
  String get auth_phone => 'Phone number';

  @override
  String get auth_phone_hint => '01XXXXXXXXX';

  @override
  String get auth_request_otp => 'Send code';

  @override
  String get auth_otp => 'Verification code';

  @override
  String get auth_verify => 'Verify';

  @override
  String get auth_dev_code => 'Dev code';

  @override
  String get auth_signout => 'Sign out';

  @override
  String get auth_guest_note =>
      'As a guest your amal stays on this phone only. Sign in and everything carries over.';

  @override
  String get auth_invalid_phone => 'Enter a valid phone number';

  @override
  String get auth_google => 'Sign in with Google';

  @override
  String get auth_apple => 'Sign in with Apple';

  @override
  String get auth_or => 'or';

  @override
  String get auth_social_error => 'Sign-in failed — try again';

  @override
  String get complete_profile_title => 'Complete your profile';

  @override
  String get complete_profile_note =>
      'Add your name and gender to activate the account. Gender cannot be changed once set.';

  @override
  String get prayer_next => 'Next prayer';

  @override
  String get prayer_remaining => 'remaining';

  @override
  String get prayer_schedule => 'Today\'s schedule';

  @override
  String get prayer_current => 'Current';

  @override
  String get prayer_forbidden_times => 'Forbidden times — no prayer';

  @override
  String get prayer_forbidden_sunrise => 'While the sun rises/sets';

  @override
  String get prayer_forbidden_zawal => 'Zawal — sun at zenith';

  @override
  String get prayer_forbidden_sunset => 'While the sun sets';

  @override
  String get prayer_bell_hint => 'Tap the bell to be notified';

  @override
  String get prayer_bell_on => 'Bell on';

  @override
  String get prayer_prompt_title => 'Did you pray?';

  @override
  String get prayer_prompt_done_jamaat => 'Prayed in jamaat';

  @override
  String get prayer_post_salat =>
      'Log your prayer — we asked 20 minutes after the waqt began';

  @override
  String get amal_today => 'Today';

  @override
  String get amal_month => 'Month grid';

  @override
  String get amal_jamaat => 'Jamaat';

  @override
  String get amal_alone => 'Alone';

  @override
  String get amal_qaza => 'Qaza';

  @override
  String get amal_locked => 'Locked';

  @override
  String get amal_locked_msg =>
      'This day is locked — days close after the next day\'s Ishraq.';

  @override
  String get amal_unlock_request => 'Request unlock';

  @override
  String get amal_unlock_requested => 'Unlock request sent to your usrah head';

  @override
  String get amal_streak => 'Streak';

  @override
  String get amal_days => 'days';

  @override
  String get amal_sync_pending => 'changes pending sync';

  @override
  String get amal_synced => 'All synced';

  @override
  String get amal_completion => 'Completion';

  @override
  String get amal_habit_builder => 'Habit builder';

  @override
  String get amal_habit_builder_desc =>
      'One amal every day for 7 days — keep the streak';

  @override
  String get amal_self_test => 'Iman & Taqwa self-test';

  @override
  String get amal_no_defs =>
      'Amal catalog is empty — sign in for the full list';

  @override
  String get amal_target_reached => 'Target reached';

  @override
  String get amal_locked_icon => '🔒 Locked';

  @override
  String get dawah_member_code => 'My member code';

  @override
  String get dawah_referral => 'Referral link';

  @override
  String get dawah_madu => 'My madu';

  @override
  String get dawah_invited => 'Total invited';

  @override
  String get dawah_usrah => 'My usrah';

  @override
  String get dawah_usrah_head => 'Usrah head';

  @override
  String get dawah_members => 'Members';

  @override
  String get dawah_announcements => 'Announcements';

  @override
  String get dawah_reviews => 'Weekly review history';

  @override
  String get dawah_my_level => 'My level';

  @override
  String get dawah_months_in_level => 'Months in level';

  @override
  String get dawah_requirements => 'Requirements';

  @override
  String get dawah_next_level => 'Next level';

  @override
  String get dawah_assessments => 'Assessment history';

  @override
  String get dawah_level_none_next => 'Grow as a daee — share your member code';

  @override
  String get ilm_quran => 'Quran';

  @override
  String get ilm_adhkar => 'Adhkar';

  @override
  String get ilm_duas => 'Du\'a library';

  @override
  String get ilm_names99 => '99 Names of Allah';

  @override
  String get ilm_baby_names => 'Islamic baby names';

  @override
  String get ilm_iman_branches => '70 branches of Iman';

  @override
  String get ilm_sunnahs => 'Sunnahs & forgotten sunnahs';

  @override
  String get ilm_articles => 'Articles';

  @override
  String get quran_reader => 'Read Quran';

  @override
  String get quran_translation_toggle => 'Bengali translation';

  @override
  String get quran_bookmark => 'Bookmark';

  @override
  String get quran_resume => 'Resume last read';

  @override
  String get quran_tilawat_logged => 'Tilawat added to your diary';

  @override
  String get quran_goto_ayah => 'Go to ayah';

  @override
  String get quran_goto_ayah_hint => 'Enter ayah number';

  @override
  String get quran_invalid_ayah => 'That ayah number is not valid';

  @override
  String get quran_reciter => 'Choose reciter';

  @override
  String get quran_play_ayah => 'Play ayah';

  @override
  String get quran_stop_audio => 'Stop audio';

  @override
  String get quran_audio_error =>
      'Could not play the audio — check your connection';

  @override
  String get adhkar_morning => 'Morning adhkar';

  @override
  String get adhkar_evening => 'Evening adhkar';

  @override
  String get adhkar_complete => 'Set complete — diary ticked';

  @override
  String get adhkar_tap_count => 'Tap to count';

  @override
  String get names_boy => 'Boy';

  @override
  String get names_girl => 'Girl';

  @override
  String get quiz_start => 'Start';

  @override
  String get quiz_result => 'Result';

  @override
  String get quiz_correct => 'Correct!';

  @override
  String get quiz_wrong => 'Wrong';

  @override
  String get quiz_retry => 'Try again';

  @override
  String get more_zakat => 'Zakat calculator';

  @override
  String get more_qibla => 'Qibla compass';

  @override
  String get more_mosque => 'My mosque';

  @override
  String get more_masala => 'Ask a masala';

  @override
  String get more_live => 'Live programs';

  @override
  String get more_faq => 'FAQ';

  @override
  String get more_about => 'About';

  @override
  String get more_feedback => 'Feedback';

  @override
  String get more_profile => 'Profile';

  @override
  String get zakat_gold => 'Gold (grams)';

  @override
  String get zakat_silver => 'Silver (grams)';

  @override
  String get zakat_cash => 'Cash & bank';

  @override
  String get zakat_investments => 'Business & investments';

  @override
  String get zakat_debts => 'Debts (deducted)';

  @override
  String get zakat_nisab => 'Nisab (85g gold)';

  @override
  String get zakat_payable => 'Zakat payable';

  @override
  String get zakat_below_nisab => 'Below nisab — zakat is not due';

  @override
  String get zakat_donate => 'Donate';

  @override
  String get qibla_distance => 'Distance from Kaaba';

  @override
  String get qibla_note =>
      'Hold the phone flat, align north, then face the arrow';

  @override
  String get masala_question => 'Your question';

  @override
  String get masala_your_name => 'Your name';

  @override
  String get masala_sent =>
      'Question sent — you will be notified of the answer';

  @override
  String get feedback_sent => 'Thanks! Feedback sent';

  @override
  String get live_now => 'Live now';

  @override
  String get live_upcoming => 'Upcoming';

  @override
  String get live_past => 'Past';

  @override
  String get live_notify => 'Remind me';

  @override
  String get profile_theme => 'Theme';

  @override
  String get profile_theme_light => 'Light';

  @override
  String get profile_theme_dark => 'Dark';

  @override
  String get profile_theme_system => 'System';

  @override
  String get profile_language => 'Language';

  @override
  String get profile_category => 'Category';

  @override
  String get profile_category_general => 'General';

  @override
  String get profile_category_hafez => 'Hafez';

  @override
  String get profile_category_alim => 'Alim';

  @override
  String get profile_female_privacy_title => 'Sisters\' privacy guarantee';

  @override
  String get app_about =>
      'Sunnah Life — from the Dawatus Sunnah department of As-Sunnah Foundation. Prayer, amal, ilm and tarbiyah in one app.';

  @override
  String get today_vs => 'Today';

  @override
  String get today_progress => 'Today\'s progress';

  @override
  String get month_prev => 'Previous month';

  @override
  String get month_next => 'Next month';

  @override
  String get day_detail => 'Day detail';

  @override
  String get habit_pick => 'Pick an amal';

  @override
  String get tilawat_session => 'Recitation session';

  @override
  String get tilawat_minutes => 'minutes read';

  @override
  String get tilawat_pages => 'Log as pages';

  @override
  String get dawah_gate_title => 'Da\'wah hub';

  @override
  String get dawah_signin_needed =>
      'Sign in to use the Da\'wah hub — for daees, usrah heads and invigilators.';

  @override
  String get dawah_role_needed =>
      'This section is for daees and supervisors. Your account does not have the role yet.';

  @override
  String get quran_surahs => 'Surahs';

  @override
  String get quran_ayahs => 'ayahs';

  @override
  String get quran_bismillah => 'Bismillah';

  @override
  String get more_share_app => 'Share app';

  @override
  String get more_share_text =>
      'Sunnah Life — prayer times, amal diary, Quran and tarbiyah in one app. https://sunnahlife.app';

  @override
  String get send => 'Send';

  @override
  String get not_available_offline =>
      'This section needs internet — please connect';

  @override
  String get categories => 'Categories';

  @override
  String get exact_alarm_title => 'Exact prayer alarms';

  @override
  String get exact_alarm_desc =>
      'Allow alarms to ring exactly on time even when the phone dozes.';

  @override
  String get exact_alarm_grant => 'Grant';

  @override
  String get hijri_adjust => 'Hijri adjust (days)';

  @override
  String get prayer_please_login => 'Will be saved to your account';

  @override
  String get all_set => 'All set';

  @override
  String get app_title => 'Sunnah Life';

  @override
  String get boot_failed => 'Failed to start';

  @override
  String get org_footer => 'As-Sunnah Foundation · Dawatus Sunnah';

  @override
  String get onb_org => 'As-Sunnah Foundation — Dawatus Sunnah';

  @override
  String get onb_bismillah_start => 'Bismillah — let\'s begin';

  @override
  String get onb_bd_defaults =>
      'Defaults for Bangladesh: Karachi method, Hanafi Asr. Everything is computed on your phone — works offline.';

  @override
  String get lang_desc_bn => 'The main language of Bangladesh';

  @override
  String get lang_desc_en => 'English';

  @override
  String get lang_desc_ar => 'Arabic — fully right-to-left';

  @override
  String get country_bd => 'Bangladesh';

  @override
  String get country_abroad => 'Abroad';

  @override
  String get country_intl => 'International';

  @override
  String get city_picker_title => 'Choose your city';

  @override
  String get city_no_match =>
      'No city matched — check the spelling or pick from the main list';

  @override
  String get waqt_fajr => 'Fajr';

  @override
  String get waqt_sunrise => 'Sunrise';

  @override
  String get waqt_ishraq => 'Ishraq';

  @override
  String get waqt_duha => 'Duha';

  @override
  String get waqt_dhuhr => 'Dhuhr';

  @override
  String get waqt_asr => 'Asr';

  @override
  String get waqt_maghrib => 'Maghrib';

  @override
  String get waqt_sunset => 'Sunset';

  @override
  String get waqt_isha => 'Isha';

  @override
  String get waqt_tahajjud => 'Tahajjud';

  @override
  String get month_1 => 'January';

  @override
  String get month_2 => 'February';

  @override
  String get month_3 => 'March';

  @override
  String get month_4 => 'April';

  @override
  String get month_5 => 'May';

  @override
  String get month_6 => 'June';

  @override
  String get month_7 => 'July';

  @override
  String get month_8 => 'August';

  @override
  String get month_9 => 'September';

  @override
  String get month_10 => 'October';

  @override
  String get month_11 => 'November';

  @override
  String get month_12 => 'December';

  @override
  String get prayer_offline_chip =>
      'All times are computed offline on your phone';

  @override
  String get prayer_bell_enable => 'Turn the bell on';

  @override
  String get prayer_bell_disable => 'Turn the bell off';

  @override
  String get role_user => 'Member';

  @override
  String get role_daee => 'Da\'ee';

  @override
  String get role_usrah_head => 'Usrah head';

  @override
  String get role_invigilator => 'Invigilator';

  @override
  String get role_full_admin => 'Admin';

  @override
  String get level_none => 'Beginning stage';

  @override
  String get level_muhibbus_sunnah => 'Muhibbus Sunnah';

  @override
  String get level_farze_ain_1 => 'Farze Ain — category 1';

  @override
  String get level_farze_ain_2 => 'Farze Ain — category 2';

  @override
  String get madhhab_hanafi => 'Hanafi';

  @override
  String get madhhab_shafii => 'Shafi\'i';

  @override
  String get method_karachi => 'Karachi (18°/18°)';

  @override
  String get method_mwl => 'Muslim World League';

  @override
  String get method_isna => 'ISNA (North America)';

  @override
  String get method_egypt => 'Egyptian';

  @override
  String get method_makkah => 'Umm al-Qura (Makkah)';

  @override
  String get method_dubai => 'Dubai';

  @override
  String get cat_salah => 'Salah';

  @override
  String get cat_quran => 'Qur\'an';

  @override
  String get cat_dhikr => 'Dhikr & Dua';

  @override
  String get cat_akhlaq => 'Akhlaq';

  @override
  String get cat_dawat => 'Da\'wah';

  @override
  String get cat_lifestyle => 'Lifestyle';

  @override
  String get cat_sunnah => 'Weekly & monthly sunnahs';

  @override
  String get cat_personal => 'Personal goals';

  @override
  String get target_label => 'Target';

  @override
  String get amal_done => 'Done';

  @override
  String get amal_not_done => 'Not done';

  @override
  String get amal_auto_logged => 'Logged automatically';

  @override
  String get amal_unlock_reason => 'Requested from the mobile app';

  @override
  String get cadence_weekly_fri => 'Fridays';

  @override
  String get cadence_weekly_mon_thu => 'Mondays & Thursdays';

  @override
  String get cadence_ayyam_beez => 'Ayyam al-Beez (13–15)';

  @override
  String get tilawat_target_pages => 'pages';

  @override
  String get tilawat_target_general => 'Tilawat: 1 page';

  @override
  String get tilawat_target_hafez => 'Tilawat: 1 juz';

  @override
  String get tilawat_target_alim => 'Tilawat: 10 pages';

  @override
  String get dawah_tab_usrah => 'Usrah';

  @override
  String get dawah_tab_reviews => 'Reviews';

  @override
  String get dawah_share_message =>
      'Assalamu alaikum. Join me on the Sunnah Life app:';

  @override
  String get dawah_no_usrah =>
      'You are not in an usrah yet — once an admin adds you it shows up here';

  @override
  String get dawah_no_reviews => 'No weekly reviews yet';

  @override
  String get dawah_week => 'Week';

  @override
  String get review_status_overdue => 'Overdue';

  @override
  String get review_status_pending => 'Pending';

  @override
  String get badge_new => 'New';

  @override
  String get quran_juz => 'Juz';

  @override
  String get sunnah_cat_all => 'All';

  @override
  String get sunnah_cat_daily => 'Daily sunnahs';

  @override
  String get sunnah_cat_forgotten => 'Forgotten sunnahs';

  @override
  String get sunnah_cat_salah => 'Salah sunnahs';

  @override
  String get iman_branch_heart => 'Iman of the heart';

  @override
  String get iman_branch_tongue => 'Iman of the tongue';

  @override
  String get iman_branch_body => 'Iman of the body';

  @override
  String get quiz_minutes => 'min';

  @override
  String get quiz_questions => 'questions';

  @override
  String get quiz_great => 'Alhamdulillah — excellent!';

  @override
  String get quiz_needs_more => 'A little more study is needed — try again';

  @override
  String get unit_km => 'km';

  @override
  String get feedback_hint => 'Write your feedback…';

  @override
  String get live_sisters_only => 'Sisters-only session';

  @override
  String get live_host => 'Host';

  @override
  String get live_will_remind => 'In sha Allah you will be reminded';

  @override
  String get qibla_north => 'North';

  @override
  String get qibla_dial_hint =>
      'Turn the dial until N points north — the arrow then shows the qibla';

  @override
  String get qibla_dial => 'Dial';

  @override
  String get masala_note =>
      'Send your religious question — the mufti will answer, in sha Allah.';

  @override
  String get masala_phone => 'Mobile (optional)';

  @override
  String get masala_offline => 'Cannot be sent offline — internet required';

  @override
  String get profile_app_section => 'App';

  @override
  String get hijri_increase => 'Increase Hijri adjustment';

  @override
  String get hijri_decrease => 'Decrease Hijri adjustment';

  @override
  String get gender_admin_only => 'only an admin can change it';

  @override
  String get increase => 'Increase';

  @override
  String get decrease => 'Decrease';

  @override
  String get onb_setup => 'setup';

  @override
  String get compass_n => 'North';

  @override
  String get compass_ne => 'Northeast';

  @override
  String get compass_e => 'East';

  @override
  String get compass_se => 'Southeast';

  @override
  String get compass_s => 'South';

  @override
  String get compass_sw => 'Southwest';

  @override
  String get compass_w => 'West';

  @override
  String get compass_nw => 'Northwest';

  @override
  String get zakat_percent_note => '2.5% of wealth';

  @override
  String get zakat_net => 'net';

  @override
  String get zakat_donation_link => 'Donation link';

  @override
  String get live_programs_count => 'programs';

  @override
  String get ilm_courses => 'Courses';

  @override
  String get ilm_quizzes => 'Quizzes';

  @override
  String get ilm_live_quiz => 'Live quiz';

  @override
  String get course_lessons_unit => 'lessons';

  @override
  String get course_enrolled_unit => 'enrolled';

  @override
  String get course_start => 'Start the course';

  @override
  String get course_continue => 'Continue';

  @override
  String get course_enroll => 'Enroll in the course';

  @override
  String get course_enrolled => 'Enrolled';

  @override
  String get course_enrolling => 'Enrolling…';

  @override
  String get course_signin_to_enroll => 'Sign in to enroll in courses';

  @override
  String get course_progress_of => 'lessons completed';

  @override
  String get courses_empty_title => 'Courses coming soon, insha\'Allah';

  @override
  String get courses_empty_hint =>
      'As-Sunnah Foundation study circles and courses will be added here.';

  @override
  String get courses_load_failed => 'Could not load courses';

  @override
  String get lesson_complete => 'Lesson completed';

  @override
  String get lesson_unmark => 'Remove from completed';

  @override
  String get lesson_next => 'Next lesson';

  @override
  String get quiz_play => 'Play the quiz';

  @override
  String get quiz_live_eligible => 'Live-quiz eligible';

  @override
  String get quiz_best => 'Best';

  @override
  String get quiz_last => 'Latest';

  @override
  String get quiz_question_of => 'Question';

  @override
  String get quiz_choose_option => 'Choose an answer';

  @override
  String get quiz_correct_was => 'The correct answer was';

  @override
  String get quiz_explanation => 'Explanation';

  @override
  String get quiz_next_question => 'Next question';

  @override
  String get quiz_finish => 'See the result';

  @override
  String get quiz_result_saved => 'Score saved to your account';

  @override
  String get quiz_result_local => 'Sign in to save your scores';

  @override
  String get quiz_play_again => 'Play again';

  @override
  String get quiz_back_to_list => 'Back to the list';

  @override
  String get quizzes_empty_title => 'Quizzes coming soon, insha\'Allah';

  @override
  String get quizzes_empty_hint =>
      'Qur\'an-Sunnah, aqeedah and fiqh quizzes will be added here.';

  @override
  String get quizzes_load_failed => 'Could not load quizzes';

  @override
  String get live_quiz_desc =>
      'Join your usrah\'s room and play together — questions arrive one by one and everyone\'s score climbs the leaderboard. When your usrah head starts a quiz, the question appears on your screen, insha\'Allah.';

  @override
  String get live_quiz_enter => 'Enter the quiz room';

  @override
  String get live_quiz_joining => 'Joining…';

  @override
  String get live_quiz_connected => 'Connected';

  @override
  String get live_quiz_disconnected => 'Disconnected';

  @override
  String get live_quiz_signin_hint =>
      'Sign in as an usrah member to join the live quiz your usrah head runs.';

  @override
  String get live_quiz_for_usrah => 'Live quiz — for your usrah';

  @override
  String get live_quiz_host_controls => 'Usrah head — quiz controls';

  @override
  String get live_quiz_start => 'Start the quiz';

  @override
  String get live_quiz_next => 'Next question';

  @override
  String get live_quiz_reveal_now => 'Reveal now';

  @override
  String get live_quiz_end => 'End the quiz';

  @override
  String get live_quiz_leave => 'Leave the room';

  @override
  String get live_quiz_lobby_host =>
      'Pick a quiz and start — your usrah members are joining.';

  @override
  String get live_quiz_lobby_player =>
      'When the usrah head starts the quiz, questions appear here…';

  @override
  String get live_quiz_answered => 'Answer submitted — please wait…';

  @override
  String get live_quiz_host_hint =>
      'Auto-reveal when everyone has answered — press “Reveal now” to see it sooner';

  @override
  String get live_quiz_reveal_title => 'Result';

  @override
  String get live_quiz_final => 'Quiz over — final scores';

  @override
  String get live_quiz_leaderboard => 'Leaderboard';

  @override
  String get live_quiz_players => 'Members';

  @override
  String get live_quiz_connect_failed => 'Could not reach the quiz server';

  @override
  String get live_quiz_secs => 's';

  @override
  String get live_quiz_people => 'answered';

  @override
  String get usrah_q_title => 'Usrah Q&A';

  @override
  String get usrah_q_hint =>
      'Sign in as a da\'ee to ask questions inside your usrah and read the head\'s answers.';

  @override
  String get usrah_q_ask_hint => 'Write your question…';

  @override
  String get usrah_q_send => 'Send question';

  @override
  String get usrah_q_sending => 'Sending…';

  @override
  String get usrah_q_sent =>
      'Question sent — the head\'s answer will appear here';

  @override
  String get usrah_q_empty => 'No questions yet — ask the first one';

  @override
  String get usrah_q_answered_by => 'Answered by';

  @override
  String get usrah_q_awaiting => 'Awaiting the usrah head\'s answer';

  @override
  String get usrah_q_answer_hint => 'Write the answer…';

  @override
  String get usrah_q_answer_submit => 'Publish the answer';

  @override
  String get usrah_q_answered => 'Answer published';

  @override
  String get usrah_q_cat_general => 'General';

  @override
  String get usrah_q_cat_aqeedah => 'Aqeedah';

  @override
  String get usrah_q_cat_salah => 'Salah';

  @override
  String get usrah_q_cat_quran => 'Qur\'an';

  @override
  String get usrah_q_cat_muamalah => 'Transactions';

  @override
  String get usrah_q_cat_tarbiyah => 'Tarbiyah';

  @override
  String get dawah_req_title => 'Level requirements';

  @override
  String get dawah_req_progress_unit => 'met';

  @override
  String get dawah_req_invigilator_check => 'Invigilator verification';

  @override
  String get dawah_req_all_met =>
      'Masha\'Allah — every requirement is met! Awaiting the level promotion.';

  @override
  String get dawah_req_auto_hint =>
      'Once every requirement is met, the nightly evaluation promotes the level automatically, insha\'Allah.';

  @override
  String get dawah_req_load_failed => 'Could not load the checklist';

  @override
  String get dawah_req_live_action => 'Live checklist';

  @override
  String get bell_minutes_title => 'Bell timing';

  @override
  String get bell_minutes_before => 'Minutes before waqt';

  @override
  String get bell_minutes_after => 'Minutes after prayer';

  @override
  String get bell_minutes_reset => 'Reset';

  @override
  String get bell_minutes_done => 'Done';

  @override
  String get sync_sheet_title => 'Sync status';

  @override
  String get sync_now => 'Sync now';

  @override
  String get sync_last_synced => 'Last synced';

  @override
  String get sync_never => 'Never synced';

  @override
  String get sync_failed_entries => 'Failed entries';

  @override
  String get sync_failed_short => 'failed';

  @override
  String get sync_dead_discard => 'Discard';

  @override
  String get sync_error_unexpected => 'Unexpected error — try again';

  @override
  String get gps_find_city => 'Find with GPS';

  @override
  String get gps_find_city_hint => 'Detect your nearest district automatically';

  @override
  String get gps_locating => 'Getting your location…';

  @override
  String get gps_your_location => 'Your location';

  @override
  String get gps_approx => 'approximate';

  @override
  String get gps_approx_note => 'far from the nearest listed city';

  @override
  String get gps_tap_confirm => 'Tap to confirm';

  @override
  String get gps_permission_denied =>
      'Permission not granted — pick a city from the list';

  @override
  String get gps_permission_denied_forever =>
      'Permission is off — allow it from settings';

  @override
  String get gps_open_settings => 'Open settings';

  @override
  String get gps_service_off => 'Phone location is off';

  @override
  String get gps_open_location_settings => 'Turn on location';

  @override
  String get gps_unavailable => 'Couldn\'t get a location — try again';

  @override
  String get unit_m => 'm';

  @override
  String get qibla_compass_heading => 'Current heading';

  @override
  String get qibla_calibration_title => 'Calibrate the compass';

  @override
  String get qibla_calibration_hint =>
      'Wave the phone in a figure-8 pattern a few times, then check again';

  @override
  String get qibla_compass_unavailable =>
      'No compass found on this phone — use the manual dial below';

  @override
  String get mosques_near_me => 'Near me';

  @override
  String get mosques_from_city => 'From this city';

  @override
  String get mosques_from_location => 'From your location';

  @override
  String get mosques_use_city => 'Use city';

  @override
  String get mosque_direction => 'direction';

  @override
  String get more_autosilent => 'Auto-silent';

  @override
  String get autosilent_explain_title => 'Silent during jama\'at';

  @override
  String get autosilent_explain_body =>
      'At the start of each prayer time the phone goes silent (priority-only) and returns to normal after the set minutes. Android\'s Do Not Disturb access is required for this.';

  @override
  String get autosilent_dnd_status => 'Permission status';

  @override
  String get autosilent_granted => 'Access granted';

  @override
  String get autosilent_not_granted => 'Access not granted';

  @override
  String get autosilent_grant => 'Grant access';

  @override
  String get autosilent_recheck => 'Check again';

  @override
  String get autosilent_return_hint =>
      'Return to the app after granting — the status updates by itself';

  @override
  String get autosilent_master => 'Auto-silent on';

  @override
  String get autosilent_minutes_label => 'Silent duration';

  @override
  String get autosilent_minutes_suffix => 'min silent';

  @override
  String get autosilent_waqts_title => 'Which prayer times';

  @override
  String get autosilent_reboot_note =>
      'After a phone restart, opening the app once re-arms the schedule.';

  @override
  String get more_donate => 'Donate';

  @override
  String get donation_open_failed => 'Could not open the link';

  @override
  String get referral_by => 'Referred by';

  @override
  String get header_notifications => 'Notifications';

  @override
  String get header_reminders => 'Reminders';

  @override
  String get notifications_guest_hint =>
      'Sign in to see usrah announcements, weekly reviews and live reminders here.';

  @override
  String get notifications_empty => 'No announcements yet';

  @override
  String get notifications_announcements => 'Announcements';

  @override
  String get notifications_live => 'Live programs';

  @override
  String get reminders_empty => 'No reminders yet';

  @override
  String get reminder_mark_done => 'Mark done';

  @override
  String get reminder_due => 'Due';

  @override
  String get reminder_overdue => 'Overdue';

  @override
  String get reminder_upcoming => 'Upcoming';

  @override
  String get contact_title => 'Contact us';

  @override
  String get contact_call => 'Call';

  @override
  String get contact_website => 'Website';

  @override
  String get contact_call_failed => 'Could not place the call';

  @override
  String get quick_access => 'Quick access';

  @override
  String get quick_quran_desc => 'Surahs & translation';

  @override
  String get quick_duas_desc => 'Everyday duas';

  @override
  String get quick_amal_desc => 'Muhasaba diary';

  @override
  String get quick_live_desc => 'Live programs';

  @override
  String get most_used => 'Most used';

  @override
  String get most_used_empty =>
      'Your most-logged amals of the last 30 days appear here — start from today\'s diary';

  @override
  String get most_used_log_today => 'Log today';

  @override
  String get most_used_days => 'days';

  @override
  String get countdown_to_schedule => 'View schedule';

  @override
  String get next_bell_chip => 'Next bell';

  @override
  String get live_next => 'Next live';

  @override
  String get live_join_hint => 'Tap to watch';

  @override
  String get ilm_courses_desc => 'Courses & lessons';

  @override
  String get ilm_quizzes_desc => 'Self-assessment quizzes';

  @override
  String get goals_title => 'My Goals';

  @override
  String get goals_new => 'New goal';

  @override
  String get goals_amal_picker => 'Choose an amal';

  @override
  String get goals_amal_short => 'Amal';

  @override
  String get goals_title_label => 'Goal title';

  @override
  String get goals_target_label => 'Target (optional)';

  @override
  String get goals_note_label => 'Note (optional)';

  @override
  String get goals_submit => 'Propose';

  @override
  String get goals_signin_needed => 'Sign in to set and track goals';

  @override
  String get goals_empty => 'No goals yet — set your first one';

  @override
  String get goals_open_label => 'Open goals';

  @override
  String get goal_status_proposed => 'Pending review';

  @override
  String get goal_status_approved => 'Approved';

  @override
  String get goal_status_rejected => 'Rejected';

  @override
  String get goal_status_completed => 'Completed';

  @override
  String get goal_status_withdrawn => 'Withdrawn';

  @override
  String get goals_reject_reason_label => 'Reason';

  @override
  String get goals_queue_title => 'Goal approvals';

  @override
  String get goals_queue_empty => 'No pending goals';

  @override
  String get goals_approve => 'Approve';

  @override
  String get goals_reject => 'Reject';

  @override
  String get goals_reject_hint => 'Reject reason (optional)';

  @override
  String get goals_member_label => 'Member';

  @override
  String get goals_remove => 'Remove';

  @override
  String get goals_remove_confirm => 'Remove this goal from your list?';

  @override
  String get goals_proposed_toast =>
      'Proposed — awaiting your usrah head\'s approval';

  @override
  String get goals_approved_toast => 'Approved';

  @override
  String get goals_rejected_toast => 'Rejected';

  @override
  String get checklist_title => 'My checklist';

  @override
  String get checklist_hint => 'Add a task';

  @override
  String get checklist_add => 'Add';

  @override
  String get checklist_remove => 'Delete';

  @override
  String get checklist_remove_confirm => 'Delete this item?';

  @override
  String get checklist_local_note => 'Stays on this device only';

  @override
  String get group_fard => 'Fard prayers';

  @override
  String get group_salah_sunnah => 'Sunnah of salah';

  @override
  String get group_nafl => 'Nafl prayers';

  @override
  String get tilawat_begin_chip => 'Start';

  @override
  String get tilawat_begin_copy =>
      'Start with 5 minutes today — it will become a habit, in shaa Allah';

  @override
  String get tilawat_ramp_day => 'Day';

  @override
  String get tilawat_begin_minutes => 'minutes';

  @override
  String get leaderboard_title => 'Leaderboard';

  @override
  String get leaderboard_points => 'points';

  @override
  String get leaderboard_window_days => 'days window';

  @override
  String get leaderboard_band_top10 => 'Top 10%';

  @override
  String get leaderboard_band_top25 => 'Top 25%';

  @override
  String get leaderboard_band_top50 => 'Top 50%';

  @override
  String get leaderboard_band_top75 => 'Top 75%';

  @override
  String get leaderboard_band_bottom => 'Bottom 25%';

  @override
  String get offline_banner => 'Offline — showing saved data';

  @override
  String get last_updated => 'Last updated';

  @override
  String get more_section_foundation => 'Foundation';

  @override
  String get contact_email => 'Email';

  @override
  String get more_section_worship => 'Worship & tools';

  @override
  String get more_section_knowledge => 'Knowledge';

  @override
  String get more_section_support => 'Support';

  @override
  String get more_section_app => 'App';

  @override
  String get more_support => 'Live support';

  @override
  String get support_signin_needed => 'Sign in to use live support';

  @override
  String get support_new_thread => 'Start a conversation';

  @override
  String get support_subject => 'Subject';

  @override
  String get support_subject_hint => 'Briefly state the subject';

  @override
  String get support_message => 'Message';

  @override
  String get support_message_hint => 'Write your message…';

  @override
  String get support_empty =>
      'No conversations yet — start one if you need help';

  @override
  String get support_status_open => 'Open';

  @override
  String get support_status_answered => 'Answered';

  @override
  String get support_status_closed => 'Closed';

  @override
  String get support_team => 'Support team';

  @override
  String get support_you => 'You';

  @override
  String get support_created_toast => 'Conversation started';

  @override
  String get support_sent_toast => 'Reply sent';

  @override
  String get support_closed_toast =>
      'This conversation is closed — please start a new one';

  @override
  String get more_usrah_join => 'Join an usrah';

  @override
  String get usrah_join_hint =>
      'Not in an usrah yet? Send a request — the tarbiyah office will assign you one, in shaa Allah';

  @override
  String get usrah_join_message_hint => 'Anything to add? (optional)';

  @override
  String get usrah_join_send => 'Send request';

  @override
  String get usrah_join_pending => 'Request pending — awaiting approval';

  @override
  String get usrah_join_rejected => 'Request rejected';

  @override
  String get usrah_join_reason_label => 'Reason';

  @override
  String get usrah_join_in_usrah => 'You are already in an usrah';

  @override
  String get usrah_join_sent_toast =>
      'Request sent — you\'ll be notified once approved, in shaa Allah';

  @override
  String get usrah_join_signin_needed => 'Sign in to join an usrah';

  @override
  String get more_detox => 'Social media detox';

  @override
  String get detox_explain_title => 'Screen-time awareness';

  @override
  String get detox_explain_body =>
      'Time is a trust. Every minute spent on social media is subtracted from the capital of the Hereafter. Grant usage access to see today\'s screen time and most-used apps — the reckoning is easier when it is in front of you, in shaa Allah.';

  @override
  String get detox_perm_status => 'Usage access';

  @override
  String get detox_perm_granted => 'Granted';

  @override
  String get detox_perm_not_granted => 'Not granted';

  @override
  String get detox_grant => 'Grant access';

  @override
  String get detox_return_hint => 'Grant, then return to the app';

  @override
  String get detox_android_only => 'This tracking works on Android only';

  @override
  String get detox_today_total => 'Today\'s total screen time';

  @override
  String get detox_top_apps => 'Most-used apps';

  @override
  String get detox_minutes_short => 'min';

  @override
  String get detox_no_usage => 'Nothing notable yet today';

  @override
  String get detox_reminder => 'Daily reminder';

  @override
  String get detox_reminder_time => 'Reminder time';

  @override
  String get detox_notif_title => 'Screen-time check';

  @override
  String get detox_notif_body =>
      'How long was today on the screen? Take a look.';

  @override
  String get more_groups => 'Our groups';

  @override
  String get group_open_failed => 'Could not open';

  @override
  String get dawah_share_card => 'Share Da\'wah card';

  @override
  String get dawah_card_title => 'Da\'wah card';

  @override
  String get dawah_card_tagline => 'Join me in building life upon the Sunnah';

  @override
  String get dawah_card_preview_note => 'The card below is shared as an image';

  @override
  String get dawah_share_now => 'Share';

  @override
  String get dawah_card_shared_toast => 'Card shared — Jazakumullahu khairan';

  @override
  String get assessment_status_pending => 'Awaiting confirmation';

  @override
  String get assessment_status_confirmed => 'Confirmed';

  @override
  String get assessment_status_declined => 'Declined';

  @override
  String get assessment_confirm_cta => 'Confirm';

  @override
  String get assessment_confirm_title => 'Confirm the assessment';

  @override
  String get assessment_confirm_body =>
      'Review your result. A code is sent to your own phone — signing with it makes the result final.';

  @override
  String get assessment_confirmed_toast =>
      'Alhamdulillah — assessment confirmed';

  @override
  String get assessment_decline_cta => 'Decline the result';

  @override
  String get assessment_decline_title => 'Decline the result?';

  @override
  String get assessment_decline_body =>
      'Declining notifies your assessor so a new assessment can be arranged, insha\'Allah.';

  @override
  String get assessment_decline_reason_hint => 'Reason (optional)';

  @override
  String get assessment_decline_label => 'Decline';

  @override
  String get assessment_declined_toast =>
      'Assessment declined — your assessor has been notified';

  @override
  String get assessment_decision_note_label => 'Your reason';

  @override
  String get assessment_result_label => 'Result';

  @override
  String get assessment_score_label => 'Score';

  @override
  String get assessment_result_passed => 'Passed';

  @override
  String get assessment_result_not_yet => 'Needs improvement';

  @override
  String get search_title => 'Search';

  @override
  String get search_hint => 'Search duas, adhkar, names or articles…';

  @override
  String get search_no_results => 'Nothing found — try another word';

  @override
  String get search_offline_note =>
      'Offline — results from the app\'s saved content';

  @override
  String get diary_title => 'Today\'s muhasaba';

  @override
  String get diary_done_of => '%done% of %total% done today';

  @override
  String get diary_pending => 'Due now';

  @override
  String get diary_read_now => 'Read';

  @override
  String get diary_opens_at => 'from %time%';

  @override
  String get diary_extras => 'More amal';

  @override
  String get diary_extras_sub => 'Beyond the paper diary · %done%/%total% done';

  @override
  String get diary_instructions => 'Instructions';

  @override
  String get diary_instructions_title => 'Muhasaba diary instructions';

  @override
  String get diary_privacy =>
      'Only you and your usrah head can see your diary.';

  @override
  String get diary_standing => 'Your standing';

  @override
  String get hero_prayer_pending => 'due';

  @override
  String get app_name => 'Sunnah Life';

  @override
  String get quick_post_salah => 'After-salah duas';

  @override
  String get quick_post_salah_desc => 'After each fard salah';

  @override
  String get quick_adhkar => 'Morning & evening adhkar';

  @override
  String get quick_adhkar_desc => 'Masnun adhkar';

  @override
  String get quick_muhasaba => 'Muhasaba checklist';

  @override
  String get quick_muhasaba_desc => 'Today\'s diary';

  @override
  String get quick_tracker => 'Amal tracker';

  @override
  String get quick_tracker_desc => 'This month';

  @override
  String get forbidden_short => 'No salah at these times';

  @override
  String get adhkar_post_salat => 'After-salah adhkar';

  @override
  String get journey_joined => 'Joined';

  @override
  String get journey_farze_ain => 'Farze Ain';

  @override
  String get journey_months => '%n% months at this level';

  @override
  String get journey_reqs_met => '%done%/%total% met';

  @override
  String get review_latest_title => 'Your usrah head\'s weekly comment';

  @override
  String get review_next_goals => 'Next week\'s goals';

  @override
  String get dawah_joined_count => '%n% joined through your invitation';

  @override
  String get live_watch_now => 'Watch live';

  @override
  String get live_watch_recording => 'Watch recording';

  @override
  String get live_none_now => 'Nothing is live right now';

  @override
  String get live_none_upcoming => 'No upcoming programs';

  @override
  String get live_none_past => 'No recordings yet';

  @override
  String get profile_workplace => 'Workplace';

  @override
  String get profile_department => 'Department / role';

  @override
  String get profile_district => 'District';

  @override
  String get profile_not_set => 'Add';

  @override
  String get profile_saved => 'Saved';

  @override
  String get profile_inventory_note =>
      'For the Dawatus Sunnah member register — only your own supervisors see it.';

  @override
  String get quizres_title => 'Members\' quiz results';

  @override
  String get quizres_took => '%done% of %total% took it';

  @override
  String get quizres_avg => 'average %n%%';

  @override
  String get quizres_not_yet => 'Not yet';

  @override
  String get quizres_tries => 'tried %n%×';

  @override
  String get quizres_no_members => 'No members in the usrah yet';

  @override
  String get quizres_hint =>
      'Encourage those who haven\'t yet — quizzes are in the Ilm section.';

  @override
  String get quiz_upcoming => 'Upcoming quizzes';

  @override
  String get quiz_today => 'Today';

  @override
  String get quiz_tomorrow => 'Tomorrow';

  @override
  String get quiz_in_days => 'in %n% days';

  @override
  String get quiz_live_now => 'Live now';

  @override
  String get quiz_join_live => 'Join the live quiz';

  @override
  String get quiz_practice => 'Practise first';

  @override
  String get guest_nudge_title => 'Keep your diary safe';

  @override
  String get guest_nudge_backup =>
      'Your diary is backed up — even if you change phones';

  @override
  String get guest_nudge_usrah =>
      'Join an usrah and get your mentor\'s guidance';

  @override
  String get guest_nudge_journey =>
      'See your progress from Muhibbus Sunnah to Farze Ain';

  @override
  String get guest_nudge_cta => 'Create an account';

  @override
  String get guest_nudge_later => 'Later';

  @override
  String get notifications_for_you => 'For you';

  @override
  String get notif_now => 'Now';

  @override
  String get notif_next => 'Next';

  @override
  String get notif_left => 'left';

  @override
  String get notif_hours => 'h';

  @override
  String get notif_minutes => 'min';

  @override
  String get profile_phone => 'Mobile number';

  @override
  String get profile_email => 'E-mail';

  @override
  String get profile_phone_change_title => 'Add / change mobile number';

  @override
  String get profile_phone_change_hint =>
      'A code goes to the new number — once confirmed you sign in with it.';

  @override
  String get profile_phone_new => 'New mobile number';

  @override
  String get profile_phone_send_code => 'Send code';

  @override
  String get profile_phone_verify => 'Confirm';

  @override
  String get profile_phone_changed => 'Mobile number changed';

  @override
  String get mosque_view_list => 'List';

  @override
  String get mosque_view_map => 'Map';

  @override
  String get mosque_directions_btn => 'Directions';

  @override
  String get mosque_search_more => 'More mosques nearby (Google Maps)';

  @override
  String get mosque_north => 'N';

  @override
  String get mosque_you => 'You';

  @override
  String get iman_check_title => 'Branches of iman — self-review';

  @override
  String get iman_check_entry_hint =>
      'Measure yourself against 69 branches — the result stays on your phone';

  @override
  String get iman_check_last => 'Last result: %n%% — review again';

  @override
  String get iman_check_intro =>
      'Not a verdict — a muhasaba. Choose honestly for each branch.';

  @override
  String get iman_check_have => 'I have it, alhamdulillah';

  @override
  String get iman_check_trying => 'Working on it';

  @override
  String get iman_check_not_yet => 'Not yet';

  @override
  String get iman_check_left => '%n% left';

  @override
  String get iman_check_see_result => 'See the result';

  @override
  String get iman_check_result_caption =>
      'Your own review across the branches of iman';

  @override
  String get iman_check_previous => 'Last time: %n%%';

  @override
  String get iman_check_focus => 'Focus on these next';

  @override
  String get iman_check_keep_going => 'Keep going';

  @override
  String get iman_check_private =>
      'These answers are stored only on your phone — no one else sees them.';

  @override
  String get iman_check_retake => 'Review again';

  @override
  String get iman_check_appbar => 'Iman self-review';

  @override
  String get auth_not_now => 'Not now';

  @override
  String get auth_welcome => 'Welcome to Sunnah Life';

  @override
  String get auth_welcome_sub =>
      'Create an account or sign in — it takes a minute';

  @override
  String get auth_google_continue => 'Continue with Google';

  @override
  String get auth_google_hint => 'The easiest way — no code needed';

  @override
  String get auth_or_phone => 'or with your mobile number';

  @override
  String get auth_code_sent_to => 'A 6-digit code was sent to %n%';

  @override
  String get auth_change_number => 'Change number';

  @override
  String get auth_dev_fill => 'Fill in';

  @override
  String get auth_resend_in => 'Resend in %n% s';

  @override
  String get auth_resend => 'Resend code';

  @override
  String get auth_privacy =>
      'Your data is protected — sisters\' data is seen only by sister supervisors.';

  @override
  String get home_muhasaba_title => 'Today\'s muhasaba';

  @override
  String get home_muhasaba_pending => 'Left';

  @override
  String get home_muhasaba_on_track =>
      'Everything due so far is written — alhamdulillah';

  @override
  String get home_muhasaba_all_done =>
      'Today\'s diary is complete — alhamdulillah';

  @override
  String get home_muhasaba_start => 'Start today\'s diary';

  @override
  String get home_muhasaba_continue => 'Continue the diary';

  @override
  String get home_pending_morning_adhkar => 'morning adhkar';

  @override
  String get home_pending_evening_adhkar => 'evening adhkar';

  @override
  String get month_paper_grid => 'The whole month (paper layout)';

  @override
  String get month_legend_none => 'Not written';

  @override
  String get month_legend_some => 'Partly';

  @override
  String get month_legend_full => 'Nearly all';

  @override
  String get weekday_short_0 => 'Sun';

  @override
  String get weekday_short_1 => 'Mon';

  @override
  String get weekday_short_2 => 'Tue';

  @override
  String get weekday_short_3 => 'Wed';

  @override
  String get weekday_short_4 => 'Thu';

  @override
  String get weekday_short_5 => 'Fri';

  @override
  String get weekday_short_6 => 'Sat';

  @override
  String get masala_mine => 'My questions & answers';

  @override
  String get masala_answered => 'Answered';

  @override
  String get masala_pending => 'Awaiting answer';

  @override
  String get bell_on_for_waqt => 'Alarm for this prayer';

  @override
  String get courses_ongoing => 'In progress';

  @override
  String get courses_done => 'Completed';

  @override
  String get courses_more => 'More courses';

  @override
  String get courses_all => 'All courses';

  @override
  String get quiz_past => 'Past live quizzes';

  @override
  String get quiz_take_it => 'Take this quiz';

  @override
  String get dawah_tab_mine => 'My path';

  @override
  String get notifications_foundation => 'From the Foundation';

  @override
  String get goal_reminder_set => 'Set a reminder';

  @override
  String get goal_reminder_pick => 'Remind me daily at';

  @override
  String get goal_reminder_daily => 'Daily at %time%';

  @override
  String get goal_reminder_change => 'Change';

  @override
  String get goal_reminder_off => 'Turn off';

  @override
  String get goal_reminder_body =>
      'Did you meet it today? Note it in the diary.';

  @override
  String get prayer_forbidden_title => 'No prayer at these times';

  @override
  String get forbidden_short_sunrise => 'Sunrise';

  @override
  String get forbidden_short_zawal => 'Zawal';

  @override
  String get forbidden_short_sunset => 'Sunset';

  @override
  String get madu_active_ago => 'active %t%';

  @override
  String get review_this_week => 'This week';

  @override
  String get review_last_week => 'Last week';

  @override
  String get delete_account_entry => 'Delete account';

  @override
  String get delete_account_title => 'Delete your account?';

  @override
  String get delete_account_goes => 'What is deleted:';

  @override
  String get delete_account_goes_1 =>
      'Your diary, goals, reviews and assessments';

  @override
  String get delete_account_goes_2 =>
      'Your questions, feedback and support messages';

  @override
  String get delete_account_goes_3 =>
      'Your name, phone, email, member code and Google sign-in';

  @override
  String get delete_account_stays => 'What stays (without your name):';

  @override
  String get delete_account_stays_1 =>
      'What you wrote for others, such as reviews or announcements — shown as “deleted account”';

  @override
  String get delete_account_final => 'This cannot be undone.';

  @override
  String get delete_account_confirm_tick =>
      'I understand and want to delete my account';

  @override
  String get delete_account_button => 'Delete permanently';

  @override
  String get delete_account_done => 'Your account has been deleted';

  @override
  String get delete_account_failed =>
      'Could not delete — check your connection and try again';

  @override
  String get privacy_policy => 'Privacy policy';

  @override
  String get privacy_policy_sub =>
      'What we keep, who sees it, how to delete it';

  @override
  String get goals_load_failed =>
      'Couldn\'t load your goals — check the connection and try again';

  @override
  String get exercise_title => 'Exercise';

  @override
  String get exercise_today => 'Today\'s exercise';

  @override
  String get exercise_min => 'min';

  @override
  String get exercise_goal_done => 'Today\'s goal reached — alhamdulillah';

  @override
  String get exercise_more => 'To go:';

  @override
  String get exercise_add => 'Log a session';

  @override
  String get exercise_add_button => 'Add to the diary';

  @override
  String get exercise_saved => 'added to the diary';

  @override
  String get exercise_less => '5 minutes less';

  @override
  String get exercise_more_btn => '5 minutes more';

  @override
  String get exercise_sessions_today => 'Today\'s sessions';

  @override
  String get exercise_undo => 'Remove this session';

  @override
  String get exercise_week => 'Last 7 days';

  @override
  String get exercise_week_total => 'These 7 days';

  @override
  String get exercise_week_note =>
      'WHO advice: at least 150 minutes of moderate activity a week.';

  @override
  String get exercise_hadith =>
      '“The strong believer is better and more beloved to Allah than the weak believer.” — Sahih Muslim 2664';

  @override
  String get exercise_type_walk => 'Walking';

  @override
  String get exercise_type_run => 'Running';

  @override
  String get exercise_type_bike => 'Cycling';

  @override
  String get exercise_type_workout => 'Workout';

  @override
  String get exercise_type_sport => 'Sport';

  @override
  String get exercise_type_swim => 'Swimming';

  @override
  String get exercise_type_other => 'Other';

  @override
  String get sun_now_running => 'Now';

  @override
  String get sun_now => 'Now';

  @override
  String get sun_next => 'Next';

  @override
  String get sun_after_sunrise => 'After sunrise';

  @override
  String get sun_wait_dhuhr => 'Until Dhuhr';

  @override
  String get sun_wait_jumuah => 'Until Jumu\'ah';

  @override
  String get sun_running => 'In progress';

  @override
  String get sun_ishraq_duha_time => 'Ishraq and Duha time';

  @override
  String get sun_hours => 'h';

  @override
  String get sun_minutes => 'min';

  @override
  String get sun_left => 'left';

  @override
  String get sun_noon => 'Midday';

  @override
  String get sun_forbidden_now => 'No prayer now';

  @override
  String get sun_until_fmt => 'until %t';

  @override
  String get jumuah => 'Jumu\'ah';

  @override
  String get sched_from_fmt => 'from %t';

  @override
  String get sched_ramadan => 'Ramadan';

  @override
  String get sched_sehri_end => 'Sehri ends';

  @override
  String get sched_iftar => 'Iftar';

  @override
  String get hijri_suffix => 'AH';

  @override
  String get most_used_days_fmt => '%n of 30 days';

  @override
  String get most_used_done => 'Done today';

  @override
  String get live_today => 'Today';

  @override
  String get live_tomorrow => 'Tomorrow';

  @override
  String get live_in_days_fmt => 'in %n days';

  @override
  String get live_badge => 'LIVE';

  @override
  String get guest_nudge_sub => 'What an account gives you';

  @override
  String get article_cat_dawah => 'Dawah';

  @override
  String get article_cat_sunnah => 'Sunnah';

  @override
  String get article_cat_tarbiyah => 'Tarbiyah';

  @override
  String get article_read_min => 'min read';

  @override
  String get article_read => 'Read';

  @override
  String get chip_habit => 'Habit';

  @override
  String get chip_self_test => 'Self-test';

  @override
  String get chip_goals => 'Goals';

  @override
  String get chip_usrah_q => 'Q&A';

  @override
  String get exercise_week_empty =>
      'Nothing logged this week yet — add today\'s exercise above';

  @override
  String get self_test_quizzes => 'Test yourself';

  @override
  String get live_none_all =>
      'No live programs right now. New ones will appear here.';

  @override
  String get about_faq_sub => 'Answers to common questions';

  @override
  String get autosilent_grant_first => 'Give the permission above first';

  @override
  String get dawah_assess_empty =>
      'No assessments yet. Results appear here once you are assessed.';

  @override
  String get dawah_req_fallback_note =>
      'Couldn\'t load the latest checklist — showing the summary';

  @override
  String get habit_mark_today => 'Done today';

  @override
  String get search_try => 'Try searching';

  @override
  String get prayer_prompt_sub =>
      'In congregation, alone or qaza — one tap saves it to today\'s diary';

  @override
  String get prayer_prompt_saved =>
      'Saved to the diary — tap another to change';

  @override
  String get faq_group_salat => 'Prayer';

  @override
  String get faq_group_amal => 'Deeds & diary';

  @override
  String get faq_group_dawah => 'Dawah & tarbiyah';

  @override
  String get faq_group_ilm => 'Learning & questions';

  @override
  String get faq_group_app => 'Using the app';

  @override
  String get faq_group_other => 'Other';

  @override
  String get faq_more_title => 'Still have a question?';

  @override
  String get faq_more_body =>
      'Ask the scholars about a religious matter; write to support about the app.';

  @override
  String get faq_ask_masala => 'Ask a scholar';

  @override
  String get faq_ask_support => 'Support';

  @override
  String get ilm_group_learn => 'Learn and test';

  @override
  String get ilm_group_quran => 'Qur\'an, dhikr and duas';

  @override
  String get ilm_group_know => 'Know';

  @override
  String get adhkar_hint => 'Tap to count · press and hold to take one back';

  @override
  String get adhkar_reset => 'Start over';

  @override
  String get adhkar_reset_title => 'Clear this set\'s counts?';

  @override
  String get adhkar_reset_body =>
      'Today\'s counts start from zero. The diary tick stays.';

  @override
  String get adhkar_done_of => 'done';

  @override
  String get adhkar_minutes_fmt => 'about %n min';

  @override
  String get adhkar_ticked_today => 'Ticked in today\'s diary';

  @override
  String get adhkar_diary_ticked => 'Alhamdulillah — ticked in today\'s diary';

  @override
  String get dhikr_virtue => 'Virtue';

  @override
  String get adhkar_set_complete => 'Set complete — masha\'Allah';

  @override
  String get article_back_to_list => 'Back to articles';

  @override
  String get search_hit_label => 'Search result';

  @override
  String get live_quiz_no_usrah_hint =>
      'Live quizzes are played within an usrah. You are not in one yet — ask to join. Meanwhile, play the practice quizzes in Ilm.';

  @override
  String get adhkar_tab_morning => 'Morning';

  @override
  String get adhkar_tab_evening => 'Evening';

  @override
  String get adhkar_tab_post_salat => 'After salah';

  @override
  String get quran_tab_surah => 'Surah';

  @override
  String get quran_tab_para => 'Para';

  @override
  String get quran_tab_bookmarks => 'Bookmarks';

  @override
  String get quran_search_hint => 'Surah name, meaning or number';

  @override
  String get quran_continue => 'Continue reading';

  @override
  String get quran_ayah => 'Ayah';

  @override
  String get quran_para_starts_fmt => '%s · from ayah %a';

  @override
  String get quran_bookmarks_empty =>
      'No bookmarks yet. Tap an ayah to bookmark it — it will be kept here.';

  @override
  String get quran_bookmarked => 'Bookmarked';

  @override
  String get quran_bookmark_removed => 'Bookmark removed';

  @override
  String get quran_bookmark_remove => 'Remove bookmark';

  @override
  String get quran_text_size => 'Text size';

  @override
  String get quran_arabic_size => 'Arabic';

  @override
  String get quran_translation_size => 'Translation';

  @override
  String get quran_play_from_here => 'Play from here';

  @override
  String get quran_play_surah => 'Play the surah';

  @override
  String get quran_prev_ayah => 'Previous ayah';

  @override
  String get quran_next_ayah => 'Next ayah';

  @override
  String get quran_pause => 'Pause';

  @override
  String get quran_resume_audio => 'Resume';

  @override
  String get quran_surah_end => 'End of the surah';

  @override
  String get quran_next_surah => 'Next surah';

  @override
  String get dua_favourites => 'Favourites';

  @override
  String get dua_favourite => 'Add to favourites';

  @override
  String get dua_favourites_empty =>
      'No favourite duas yet. Tap ♥ beside a dua to keep it here.';

  @override
  String get name_prev => 'Previous';

  @override
  String get name_next => 'Next';

  @override
  String get names_shortlist => 'Shortlist';

  @override
  String get names_shortlist_add => 'Add to shortlist';

  @override
  String get names_shortlisted => 'In the shortlist';

  @override
  String get iman_check_cta_title => 'Check your own iman';

  @override
  String get iman_check_cta_body =>
      'Measure yourself branch by branch — the result stays on your phone';

  @override
  String get quiz_leave_title => 'Leave the quiz?';

  @override
  String get quiz_leave_body => 'Your answers so far will be lost.';

  @override
  String get quiz_keep_playing => 'Keep playing';

  @override
  String get quiz_leave => 'Leave';

  @override
  String get quiz_review_title => 'Your %n wrong answers — review';

  @override
  String get quiz_result_offline => 'Offline — the score could not be sent';

  @override
  String get ilm_continue => 'Continue';

  @override
  String get ilm_course_progress_fmt => '%d of %t lessons done';

  @override
  String get live_quiz_you_right => 'Your answer is right';

  @override
  String get live_quiz_you_wrong => 'Your answer was not right';

  @override
  String get live_quiz_you_skipped => 'You did not answer this one';

  @override
  String get sunnah_mark_done => 'Practised today';

  @override
  String get sunnah_done_today => 'Done today';

  @override
  String get sunnah_today_count => '%n sunnahs practised today — alhamdulillah';

  @override
  String get sunnah_today_hint => 'Tick the sunnahs you practised today';

  @override
  String get ilm_desc_courses => 'Learn step by step — lessons and progress';

  @override
  String get ilm_desc_quizzes => 'Test yourself and learn from mistakes';

  @override
  String get ilm_desc_live_quiz => 'A quiz together with your usrah';

  @override
  String get ilm_desc_quran => 'Arabic, Bengali translation and recitation';

  @override
  String get ilm_desc_adhkar =>
      'Morning, evening and after-salah dhikr with counters';

  @override
  String get ilm_desc_duas => 'Everyday sunnah duas with sources';

  @override
  String get ilm_desc_sunnahs =>
      'Daily and forgotten sunnahs — tick what you practise';

  @override
  String get ilm_desc_names99 => 'With meanings and virtues';

  @override
  String get ilm_desc_islamic_names => 'Meaningful names for boys and girls';

  @override
  String get ilm_desc_iman_branches => 'The 70 branches — and a self-check';

  @override
  String get ilm_desc_articles => 'Writing on tarbiyah, dawah and sunnah';
}
