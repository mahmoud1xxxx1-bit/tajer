import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final localeString = prefs.getString('app_locale');
    if (localeString != null && localeString.isNotEmpty) {
      return Locale(localeString);
    }
    
    // Auto-detect device language on first launch
    final deviceLang = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    if (deviceLang == 'en') {
      return const Locale('en');
    }
    
    return const Locale('ar');
  }

  void setLocale(Locale locale) {
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString('app_locale', locale.languageCode);
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
    final prefs = ref.watch(sharedPreferencesProvider);
    final currencyString = prefs.getString('app_currency');
    if (currencyString != null) {
      try {
        return AppCurrency.values.firstWhere((e) => e.name == currencyString);
      } catch (e) {
        return AppCurrency.sar;
      }
    }
    return AppCurrency.sar;
  }

  void setCurrency(AppCurrency currency) {
    state = currency;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString('app_currency', currency.name);
  }
}

final currencyProvider = NotifierProvider<CurrencyNotifier, AppCurrency>(() {
  return CurrencyNotifier();
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final themeString = prefs.getString('app_theme');
    if (themeString == 'light') return ThemeMode.light;
    if (themeString == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    if (mode == ThemeMode.light) {
      prefs.setString('app_theme', 'light');
    } else if (mode == ThemeMode.dark) {
      prefs.setString('app_theme', 'dark');
    } else {
      prefs.setString('app_theme', 'system');
    }
  }
}

final themeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});
