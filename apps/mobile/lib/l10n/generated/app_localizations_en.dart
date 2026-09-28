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
}
