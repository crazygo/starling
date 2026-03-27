import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

abstract class AppLocalizations {
  const AppLocalizations(this.localeName);

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  String get exploreTitle;
  String get tabBallads;
  String get tabVoyage;
  String get tabSettings;
  String get settingsTitle;
  String get settingsSubtitle;
  String get cultureSettings;
  String get chineseCulture;
  String get chineseCultureSubtitle;
  String get westernCulture;
  String get westernCultureSubtitle;
  String get searchHint;
  String get gyroOn;
  String get gyroOff;
  String get languageSettings;
  String get languageAuto;
  String get languageAutoSubtitle;
  String get languageChinese;
  String get languageChineseSubtitle;
  String get languageEnglish;
  String get languageEnglishSubtitle;
  String get viewStyleSettings;
  String get viewStyleDome;
  String get viewStyleDomeSubtitle;
  String get viewStyleClassic;
  String get viewStyleClassicSubtitle;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(
      lookupAppLocalizations(locale),
    );
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'en':
      return const AppLocalizationsEn();
    case 'zh':
      return const AppLocalizationsZh();
  }
  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale".',
  );
}

class AppLocalizationsEn extends AppLocalizations {
  const AppLocalizationsEn() : super('en');

  @override
  String get exploreTitle => 'Starling Bard';

  @override
  String get tabBallads => 'Ballads';

  @override
  String get tabVoyage => 'Voyage';

  @override
  String get tabSettings => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle => 'App Preferences';

  @override
  String get cultureSettings => 'Culture Settings';

  @override
  String get chineseCulture => 'Chinese Culture';

  @override
  String get chineseCultureSubtitle => 'Chinese star names and asterisms';

  @override
  String get westernCulture => 'Western Culture';

  @override
  String get westernCultureSubtitle => 'Western star names and constellations';

  @override
  String get searchHint => 'Search stars…';

  @override
  String get gyroOn => 'Gyro On';

  @override
  String get gyroOff => 'Gyro';

  @override
  String get languageSettings => 'Language';

  @override
  String get languageAuto => 'Auto';

  @override
  String get languageAutoSubtitle => 'Follow system language';

  @override
  String get languageChinese => 'Chinese';

  @override
  String get languageChineseSubtitle => 'Simplified Chinese';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageEnglishSubtitle => 'English';

  @override
  String get viewStyleSettings => 'View Style';

  @override
  String get viewStyleDome => 'Dome';

  @override
  String get viewStyleDomeSubtitle =>
      'Immersive sky dome with orientation framing';

  @override
  String get viewStyleClassic => 'Classic';

  @override
  String get viewStyleClassicSubtitle => 'Flat rectangular chart';
}

class AppLocalizationsZh extends AppLocalizations {
  const AppLocalizationsZh() : super('zh');

  @override
  String get exploreTitle => '星仔';

  @override
  String get tabBallads => '吟游';

  @override
  String get tabVoyage => '巡天';

  @override
  String get tabSettings => '设置';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSubtitle => '应用偏好';

  @override
  String get cultureSettings => '文化设置';

  @override
  String get chineseCulture => '中国文化';

  @override
  String get chineseCultureSubtitle => '中国星名与星官';

  @override
  String get westernCulture => '西方文化';

  @override
  String get westernCultureSubtitle => '西方星名与星座';

  @override
  String get searchHint => '搜索星体…';

  @override
  String get gyroOn => '陀螺仪开';

  @override
  String get gyroOff => '陀螺仪';

  @override
  String get languageSettings => '语言';

  @override
  String get languageAuto => '自动';

  @override
  String get languageAutoSubtitle => '跟随系统语言';

  @override
  String get languageChinese => '中文';

  @override
  String get languageChineseSubtitle => '简体中文';

  @override
  String get languageEnglish => '英文';

  @override
  String get languageEnglishSubtitle => 'English';

  @override
  String get viewStyleSettings => '视图样式';

  @override
  String get viewStyleDome => '穹顶';

  @override
  String get viewStyleDomeSubtitle => '带方向参照的沉浸式天空视图';

  @override
  String get viewStyleClassic => '传统';

  @override
  String get viewStyleClassicSubtitle => '平面矩形星图';
}
