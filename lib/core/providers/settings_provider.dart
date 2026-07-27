import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    return const Locale('ar');
  }

  void setLocale(Locale locale) {
    state = locale;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(() {
  return LocaleNotifier();
});

enum AppCurrency {
  sar('SAR', 'currency_SAR'),
  usd('USD', 'currency_USD'),
  yer('YER', 'currency_YER'),
  aed('AED', 'currency_AED'),
  jod('JOD', 'currency_JOD'),
  iqd('IQD', 'currency_IQD'),
  syp('SYP', 'currency_SYP'),
  lbp('LBP', 'currency_LBP'),
  kwd('KWD', 'currency_KWD'),
  egp('EGP', 'currency_EGP'),
  dzd('DZD', 'currency_DZD'),
  lyd('LYD', 'currency_LYD'),
  mad('MAD', 'currency_MAD'),
  bhd('BHD', 'currency_BHD'),
  qar('QAR', 'currency_QAR'),
  omr('OMR', 'currency_OMR');

  final String code;
  final String translationKey;
  const AppCurrency(this.code, this.translationKey);
}

class CurrencyNotifier extends Notifier<AppCurrency> {
  @override
  AppCurrency build() {
    return AppCurrency.sar;
  }

  void setCurrency(AppCurrency currency) {
    state = currency;
  }
}

final currencyProvider = NotifierProvider<CurrencyNotifier, AppCurrency>(() {
  return CurrencyNotifier();
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ThemeMode.system;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}

final themeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});
