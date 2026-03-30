import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

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
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @exploreTitle.
  ///
  /// In zh, this message translates to:
  /// **'星仔'**
  String get exploreTitle;

  /// No description provided for @tabBallads.
  ///
  /// In zh, this message translates to:
  /// **'吟游'**
  String get tabBallads;

  /// No description provided for @tabVoyage.
  ///
  /// In zh, this message translates to:
  /// **'巡天'**
  String get tabVoyage;

  /// No description provided for @tabSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get tabSettings;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'应用偏好'**
  String get settingsSubtitle;

  /// No description provided for @cultureSettings.
  ///
  /// In zh, this message translates to:
  /// **'文化设置'**
  String get cultureSettings;

  /// No description provided for @chineseAncientCulture.
  ///
  /// In zh, this message translates to:
  /// **'中国古代（步天歌）'**
  String get chineseAncientCulture;

  /// No description provided for @chineseAncientCultureSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'步天歌星官体系与中文星名'**
  String get chineseAncientCultureSubtitle;

  /// No description provided for @chineseModernCulture.
  ///
  /// In zh, this message translates to:
  /// **'中国现代'**
  String get chineseModernCulture;

  /// No description provided for @chineseModernCultureSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'现代88星座连线与中文命名'**
  String get chineseModernCultureSubtitle;

  /// No description provided for @westernCulture.
  ///
  /// In zh, this message translates to:
  /// **'西方文化'**
  String get westernCulture;

  /// No description provided for @westernCultureSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'西方星名与星座'**
  String get westernCultureSubtitle;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索星体…'**
  String get searchHint;

  /// No description provided for @gyroOn.
  ///
  /// In zh, this message translates to:
  /// **'陀螺仪开'**
  String get gyroOn;

  /// No description provided for @gyroOff.
  ///
  /// In zh, this message translates to:
  /// **'陀螺仪'**
  String get gyroOff;

  /// 设置应用内文本语言
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get languageSettings;

  /// No description provided for @languageAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get languageAuto;

  /// No description provided for @languageAutoSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统语言'**
  String get languageAutoSubtitle;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageChineseSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageChineseSubtitle;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'英文'**
  String get languageEnglish;

  /// No description provided for @languageEnglishSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglishSubtitle;

  /// No description provided for @viewStyleSettings.
  ///
  /// In zh, this message translates to:
  /// **'视图样式'**
  String get viewStyleSettings;

  /// No description provided for @viewStyleDome.
  ///
  /// In zh, this message translates to:
  /// **'穹顶'**
  String get viewStyleDome;

  /// No description provided for @viewStyleDomeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'带方向参照的沉浸式天空视图'**
  String get viewStyleDomeSubtitle;

  /// No description provided for @viewStyleClassic.
  ///
  /// In zh, this message translates to:
  /// **'传统'**
  String get viewStyleClassic;

  /// No description provided for @viewStyleClassicSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'平面矩形星图'**
  String get viewStyleClassicSubtitle;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
