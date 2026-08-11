import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
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
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ§Ø¬Ø±'**
  String get appTitle;

  /// No description provided for @loginTitle.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„'**
  String get loginTitle;

  /// No description provided for @products.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…Ù†ØªØ¬Ø§Øª'**
  String get products;

  /// No description provided for @customers.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¹Ù…Ù„Ø§Ø¡'**
  String get customers;

  /// No description provided for @orders.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø·Ù„Ø¨Ø§Øª'**
  String get orders;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª'**
  String get settings;

  /// No description provided for @dashboard.
  ///
  /// In ar, this message translates to:
  /// **'Ù„ÙˆØ­Ø© Ø§Ù„ØªØ­ÙƒÙ…'**
  String get dashboard;

  /// No description provided for @adminPanel.
  ///
  /// In ar, this message translates to:
  /// **'Ù„ÙˆØ­Ø© Ø§Ù„Ø¥Ø¯Ø§Ø±Ø© Ø§Ù„Ø¹Ù„ÙŠØ§'**
  String get adminPanel;

  /// No description provided for @expenses.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…ØµØ±ÙˆÙØ§Øª'**
  String get expenses;

  /// No description provided for @suppliers.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…ÙˆØ±Ø¯ÙŠÙ†'**
  String get suppliers;

  /// No description provided for @categories.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„ØªØµÙ†ÙŠÙØ§Øª'**
  String get categories;

  /// No description provided for @inventoryLog.
  ///
  /// In ar, this message translates to:
  /// **'Ø³Ø¬Ù„ Ø§Ù„Ù…Ø®Ø²ÙˆÙ†'**
  String get inventoryLog;

  /// No description provided for @reports.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„ØªÙ‚Ø§Ø±ÙŠØ±'**
  String get reports;

  /// No description provided for @totalSales.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ø¨ÙŠØ¹Ø§Øª'**
  String get totalSales;

  /// No description provided for @ordersCount.
  ///
  /// In ar, this message translates to:
  /// **'Ø¹Ø¯Ø¯ Ø§Ù„Ø·Ù„Ø¨Ø§Øª'**
  String get ordersCount;

  /// No description provided for @quickActions.
  ///
  /// In ar, this message translates to:
  /// **'Ø£ÙˆØ§Ù…Ø± Ø³Ø±ÙŠØ¹Ø©'**
  String get quickActions;

  /// No description provided for @managementAndInventory.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¥Ø¯Ø§Ø±Ø© ÙˆØ§Ù„Ù…Ø®Ø²ÙˆÙ†'**
  String get managementAndInventory;

  /// No description provided for @add.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¶Ø§ÙØ©'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ¹Ø¯ÙŠÙ„'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø°Ù'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'Ø­ÙØ¸'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ù„ØºØ§Ø¡'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ£ÙƒÙŠØ¯'**
  String get confirm;

  /// No description provided for @update.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ­Ø¯ÙŠØ«'**
  String get update;

  /// No description provided for @name.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø§Ø³Ù…'**
  String get name;

  /// No description provided for @price.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø³Ø¹Ø±'**
  String get price;

  /// No description provided for @quantity.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„ÙƒÙ…ÙŠØ©'**
  String get quantity;

  /// No description provided for @barcode.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¨Ø§Ø±ÙƒÙˆØ¯'**
  String get barcode;

  /// No description provided for @category.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„ØªØµÙ†ÙŠÙ'**
  String get category;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'Ø±Ù‚Ù… Ø§Ù„Ù‡Ø§ØªÙ'**
  String get phone;

  /// No description provided for @email.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¨Ø±ÙŠØ¯ Ø§Ù„Ø¥Ù„ÙƒØªØ±ÙˆÙ†ÙŠ'**
  String get email;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'ÙƒÙ„Ù…Ø© Ø§Ù„Ù…Ø±ÙˆØ±'**
  String get password;

  /// No description provided for @notes.
  ///
  /// In ar, this message translates to:
  /// **'Ù…Ù„Ø§Ø­Ø¸Ø§Øª'**
  String get notes;

  /// No description provided for @date.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„ØªØ§Ø±ÙŠØ®'**
  String get date;

  /// No description provided for @scanBarcode.
  ///
  /// In ar, this message translates to:
  /// **'Ù…Ø³Ø­ Ø§Ù„Ø¨Ø§Ø±ÙƒÙˆØ¯'**
  String get scanBarcode;

  /// No description provided for @searchByBarcode.
  ///
  /// In ar, this message translates to:
  /// **'Ø¨Ø­Ø« Ø¨Ø§Ù„Ø¨Ø§Ø±ÙƒÙˆØ¯'**
  String get searchByBarcode;

  /// No description provided for @productName.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø³Ù… Ø§Ù„Ù…Ù†ØªØ¬'**
  String get productName;

  /// No description provided for @availableQuantity.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„ÙƒÙ…ÙŠØ© Ø§Ù„Ù…ØªØ§Ø­Ø©'**
  String get availableQuantity;

  /// No description provided for @noCategory.
  ///
  /// In ar, this message translates to:
  /// **'Ø¨Ø¯ÙˆÙ† ØªØµÙ†ÙŠÙ'**
  String get noCategory;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø®Ø±ÙˆØ¬'**
  String get logout;

  /// No description provided for @upgradeAccount.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ±Ù‚ÙŠØ© Ø§Ù„Ø­Ø³Ø§Ø¨ (Ø±Ø¨Ø· Ø¨Ù€ Google)'**
  String get upgradeAccount;

  /// No description provided for @subscriptions.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø§Ø´ØªØ±Ø§ÙƒØ§Øª ÙˆØ§Ù„Ø¨Ø§Ù‚Ø§Øª'**
  String get subscriptions;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'Ù„ØºØ© Ø§Ù„ØªØ·Ø¨ÙŠÙ‚'**
  String get language;

  /// No description provided for @currency.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¹Ù…Ù„Ø© Ø§Ù„Ø£Ø³Ø§Ø³ÙŠØ©'**
  String get currency;

  /// No description provided for @theme.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…Ø¸Ù‡Ø±'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ„Ù‚Ø§Ø¦ÙŠ'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ar, this message translates to:
  /// **'ÙØ§ØªØ­'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ar, this message translates to:
  /// **'Ø¯Ø§ÙƒÙ†'**
  String get themeDark;

  /// No description provided for @error.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø¯Ø« Ø®Ø·Ø£'**
  String get error;

  /// No description provided for @success.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ø¨Ù†Ø¬Ø§Ø­'**
  String get success;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'Ø¬Ø§Ø±ÙŠ Ø§Ù„ØªØ­Ù…ÙŠÙ„...'**
  String get loading;

  /// No description provided for @requiredField.
  ///
  /// In ar, this message translates to:
  /// **'Ù…Ø·Ù„ÙˆØ¨'**
  String get requiredField;

  /// No description provided for @currency_SAR.
  ///
  /// In ar, this message translates to:
  /// **'Ø±ÙŠØ§Ù„ Ø³Ø¹ÙˆØ¯ÙŠ'**
  String get currency_SAR;

  /// No description provided for @currency_USD.
  ///
  /// In ar, this message translates to:
  /// **'Ø¯ÙˆÙ„Ø§Ø± Ø£Ù…Ø±ÙŠÙƒÙŠ'**
  String get currency_USD;

  /// No description provided for @currency_YER.
  ///
  /// In ar, this message translates to:
  /// **'Ø±ÙŠØ§Ù„ ÙŠÙ…Ù†ÙŠ'**
  String get currency_YER;

  /// No description provided for @currency_AED.
  ///
  /// In ar, this message translates to:
  /// **'Ø¯Ø±Ù‡Ù… Ø¥Ù…Ø§Ø±Ø§ØªÙŠ'**
  String get currency_AED;

  /// No description provided for @currency_JOD.
  ///
  /// In ar, this message translates to:
  /// **'Ø¯ÙŠÙ†Ø§Ø± Ø£Ø±Ø¯Ù†ÙŠ'**
  String get currency_JOD;

  /// No description provided for @currency_IQD.
  ///
  /// In ar, this message translates to:
  /// **'Ø¯ÙŠÙ†Ø§Ø± Ø¹Ø±Ø§Ù‚ÙŠ'**
  String get currency_IQD;

  /// No description provided for @currency_SYP.
  ///
  /// In ar, this message translates to:
  /// **'Ù„ÙŠØ±Ø© Ø³ÙˆØ±ÙŠØ©'**
  String get currency_SYP;

  /// No description provided for @currency_LBP.
  ///
  /// In ar, this message translates to:
  /// **'Ù„ÙŠØ±Ø© Ù„Ø¨Ù†Ø§Ù†ÙŠØ©'**
  String get currency_LBP;

  /// No description provided for @currency_KWD.
  ///
  /// In ar, this message translates to:
  /// **'Ø¯ÙŠÙ†Ø§Ø± ÙƒÙˆÙŠØªÙŠ'**
  String get currency_KWD;

  /// No description provided for @currency_EGP.
  ///
  /// In ar, this message translates to:
  /// **'Ø¬Ù†ÙŠÙ‡ Ù…ØµØ±ÙŠ'**
  String get currency_EGP;

  /// No description provided for @currency_DZD.
  ///
  /// In ar, this message translates to:
  /// **'Ø¯ÙŠÙ†Ø§Ø± Ø¬Ø²Ø§Ø¦Ø±ÙŠ'**
  String get currency_DZD;

  /// No description provided for @currency_LYD.
  ///
  /// In ar, this message translates to:
  /// **'Ø¯ÙŠÙ†Ø§Ø± Ù„ÙŠØ¨ÙŠ'**
  String get currency_LYD;

  /// No description provided for @currency_MAD.
  ///
  /// In ar, this message translates to:
  /// **'Ø¯Ø±Ù‡Ù… Ù…ØºØ±Ø¨ÙŠ'**
  String get currency_MAD;

  /// No description provided for @currency_BHD.
  ///
  /// In ar, this message translates to:
  /// **'Ø¯ÙŠÙ†Ø§Ø± Ø¨Ø­Ø±ÙŠÙ†ÙŠ'**
  String get currency_BHD;

  /// No description provided for @currency_QAR.
  ///
  /// In ar, this message translates to:
  /// **'Ø±ÙŠØ§Ù„ Ù‚Ø·Ø±ÙŠ'**
  String get currency_QAR;

  /// No description provided for @currency_OMR.
  ///
  /// In ar, this message translates to:
  /// **'Ø±ÙŠØ§Ù„ Ø¹Ù…Ø§Ù†ÙŠ'**
  String get currency_OMR;

  /// No description provided for @text1.
  ///
  /// In ar, this message translates to:
  /// **'ÙˆØµÙ„Øª Ù„Ù„Ø­Ø¯ Ø§Ù„Ø£Ù‚ØµÙ‰!'**
  String get text1;

  /// No description provided for @text2.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø³Ø§Ø¨Ùƒ Ø§Ù„Ø­Ø§Ù„ÙŠ Ù‡Ùˆ Ø­Ø³Ø§Ø¨ Ø¶ÙŠÙ ØªØ¬Ø±ÙŠØ¨ÙŠ. Ù„Ù‚Ø¯ ÙˆØµÙ„Øª Ù„Ù„Ø­Ø¯ Ø§Ù„Ø£Ù‚ØµÙ‰ Ø§Ù„Ù…Ø³Ù…ÙˆØ­ Ø¨Ù‡ Ù„Ù„Ø¥Ø¶Ø§ÙØ§Øª.\n\nÙŠØ±Ø¬Ù‰ Ø±Ø¨Ø· Ø­Ø³Ø§Ø¨Ùƒ Ø¨Ù€ Google Ù„Ù„Ø§Ø³ØªÙ…Ø±Ø§Ø± ÙÙŠ Ø§Ø³ØªØ®Ø¯Ø§Ù… Ø§Ù„ØªØ·Ø¨ÙŠÙ‚ Ù…Ø¬Ø§Ù†Ø§Ù‹ ÙˆØ¨Ø¯ÙˆÙ† Ù‚ÙŠÙˆØ¯ØŒ ÙˆØ­ÙØ¸ Ø¨ÙŠØ§Ù†Ø§ØªÙƒ Ù…Ù† Ø§Ù„Ø¶ÙŠØ§Ø¹.'**
  String get text2;

  /// No description provided for @text3.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§Ø­Ù‚Ø§Ù‹'**
  String get text3;

  /// No description provided for @text4.
  ///
  /// In ar, this message translates to:
  /// **'Ø±Ø¨Ø· Ø¨Ø­Ø³Ø§Ø¨ Google'**
  String get text4;

  /// No description provided for @text5.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… ØªØ±Ù‚ÙŠØ© Ø§Ù„Ø­Ø³Ø§Ø¨ Ø¨Ù†Ø¬Ø§Ø­! ÙŠÙ…ÙƒÙ†Ùƒ Ø§Ù„Ø¢Ù† Ø§Ù„Ø§Ø³ØªÙ…Ø±Ø§Ø± Ø¨Ù„Ø§ Ù‚ÙŠÙˆØ¯.'**
  String get text5;

  /// No description provided for @text6.
  ///
  /// In ar, this message translates to:
  /// **'ÙØ§ØªÙˆØ±Ø© Ù…Ø¨ÙŠØ¹Ø§Øª'**
  String get text6;

  /// No description provided for @text7.
  ///
  /// In ar, this message translates to:
  /// **'Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ø¹Ù…ÙŠÙ„:'**
  String get text7;

  /// No description provided for @text8.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ§Ø±ÙŠØ® Ø§Ù„Ø·Ù„Ø¨:'**
  String get text8;

  /// No description provided for @text9.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…Ù†ØªØ¬'**
  String get text9;

  /// No description provided for @text10.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„ÙƒÙ…ÙŠØ©'**
  String get text10;

  /// No description provided for @text11.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø³Ø¹Ø±'**
  String get text11;

  /// No description provided for @text12.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ'**
  String get text12;

  /// No description provided for @text13.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ø³ØªØ­Ù‚:'**
  String get text13;

  /// No description provided for @text14.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…Ø¨Ù„Øº Ø§Ù„Ù…Ø¯ÙÙˆØ¹:'**
  String get text14;

  /// No description provided for @text15.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…ØªØ¨Ù‚ÙŠ (Ø¢Ø¬Ù„):'**
  String get text15;

  /// No description provided for @text16.
  ///
  /// In ar, this message translates to:
  /// **'Ø´ÙƒØ±Ø§Ù‹ Ù„ØªØ¹Ø§Ù…Ù„ÙƒÙ… Ù…Ø¹Ù†Ø§!'**
  String get text16;

  /// No description provided for @text17.
  ///
  /// In ar, this message translates to:
  /// **'ÙƒØ´Ù Ø­Ø³Ø§Ø¨ Ø¹Ù…ÙŠÙ„'**
  String get text17;

  /// No description provided for @text18.
  ///
  /// In ar, this message translates to:
  /// **'Ø³Ø¬Ù„ Ø§Ù„Ø·Ù„Ø¨Ø§Øª:'**
  String get text18;

  /// No description provided for @text19.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ§Ø±ÙŠØ® Ø§Ù„Ø·Ù„Ø¨'**
  String get text19;

  /// No description provided for @text20.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…Ø¯ÙÙˆØ¹'**
  String get text20;

  /// No description provided for @text21.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…ØªØ¨Ù‚ÙŠ'**
  String get text21;

  /// No description provided for @text22.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø­Ø§Ù„Ø©'**
  String get text22;

  /// No description provided for @text23.
  ///
  /// In ar, this message translates to:
  /// **'cancelled\' ? \'Ù…Ù„ØºÙŠ'**
  String get text23;

  /// No description provided for @text24.
  ///
  /// In ar, this message translates to:
  /// **'Ù…Ø¹ØªÙ…Ø¯'**
  String get text24;

  /// No description provided for @text25.
  ///
  /// In ar, this message translates to:
  /// **'Ù…Ø³Ø­ Ø§Ù„Ø¨Ø§Ø±ÙƒÙˆØ¯'**
  String get text25;

  /// No description provided for @text26.
  ///
  /// In ar, this message translates to:
  /// **'ÙØ´Ù„ ÙÙŠ ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„ Ø§Ù„Ù…Ø¬Ù‡ÙˆÙ„'**
  String get text26;

  /// No description provided for @text27.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ‡ÙŠØ¦Ø© Ù…Ø³Ø§Ø­Ø© Ø§Ù„Ø¹Ù…Ù„ Ø§Ù„Ø®Ø§ØµØ© Ø¨Ùƒ...'**
  String get text27;

  /// No description provided for @text28.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¹Ø§Ø¯Ø© Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø©'**
  String get text28;

  /// No description provided for @text29.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…Ø³ØªØ®Ø¯Ù… ØºÙŠØ± Ù…Ø³Ø¬Ù„ Ø§Ù„Ø¯Ø®ÙˆÙ„'**
  String get text29;

  /// No description provided for @text30.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ø¥Ù„ØºØ§Ø¡ ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„'**
  String get text30;

  /// No description provided for @text31.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ø±Ø¨Ø· Ø§Ù„Ø­Ø³Ø§Ø¨ Ø¨Ù†Ø¬Ø§Ø­!'**
  String get text31;

  /// No description provided for @text32.
  ///
  /// In ar, this message translates to:
  /// **'ÙŠØ±Ø¬Ù‰ Ø¥Ø¯Ø®Ø§Ù„ Ø±Ù‚Ù… Ø§Ù„Ù‡Ø§ØªÙ'**
  String get text32;

  /// No description provided for @text33.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥ÙƒÙ…Ø§Ù„ Ø§Ù„ØªØ³Ø¬ÙŠÙ„'**
  String get text33;

  /// No description provided for @text34.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø­Ù…Ø§ÙŠØ© Ø¨ÙŠØ§Ù†Ø§ØªÙƒ Ù…Ù† Ø§Ù„Ø¶ÙŠØ§Ø¹ØŒ ÙŠØ±Ø¬Ù‰ Ø±Ø¨Ø· Ø­Ø³Ø§Ø¨Ùƒ Ø¨Ù€ Google ÙˆØ¥Ø¯Ø®Ø§Ù„ Ø±Ù‚Ù… Ù„Ù„ØªÙˆØ§ØµÙ„.'**
  String get text34;

  /// No description provided for @text35.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø±Ø¨Ø· Ø¨Ø­Ø³Ø§Ø¨ Google'**
  String get text35;

  /// No description provided for @text36.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ø±Ø¨Ø· Ø§Ù„Ø­Ø³Ø§Ø¨ Ø¨Ù†Ø¬Ø§Ø­'**
  String get text36;

  /// No description provided for @text37.
  ///
  /// In ar, this message translates to:
  /// **'Ø±Ù‚Ù… Ø§Ù„Ù‡Ø§ØªÙ (Ø§Ù„ÙˆØ§ØªØ³Ø§Ø¨)'**
  String get text37;

  /// No description provided for @text38.
  ///
  /// In ar, this message translates to:
  /// **'Ø­ÙØ¸ ÙˆØ§Ù„Ù…ØªØ§Ø¨Ø¹Ø©'**
  String get text38;

  /// No description provided for @text39.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¯Ø§Ø±Ø© Ø§Ù„ØªØµÙ†ÙŠÙØ§Øª'**
  String get text39;

  /// No description provided for @text40.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ÙŠÙˆØ¬Ø¯ ØªØµÙ†ÙŠÙØ§Øª Ø­Ø§Ù„ÙŠØ§Ù‹'**
  String get text40;

  /// No description provided for @text41.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¶Ø§ÙØ© ØªØµÙ†ÙŠÙ Ø¬Ø¯ÙŠØ¯'**
  String get text41;

  /// No description provided for @text42.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø³Ù… Ø§Ù„ØªØµÙ†ÙŠÙ'**
  String get text42;

  /// No description provided for @text43.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ù„ØºØ§Ø¡'**
  String get text43;

  /// No description provided for @text44.
  ///
  /// In ar, this message translates to:
  /// **'Ø­ÙØ¸'**
  String get text44;

  /// No description provided for @text45.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ¹Ø¯ÙŠÙ„ Ø§Ù„ØªØµÙ†ÙŠÙ'**
  String get text45;

  /// No description provided for @text46.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ­Ø¯ÙŠØ«'**
  String get text46;

  /// No description provided for @text47.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…Ø³ØªØ®Ø¯Ù… ØºÙŠØ± Ù…Ø³Ø¬Ù„'**
  String get text47;

  /// No description provided for @text48.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ¹Ø¯ÙŠÙ„ Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ø¹Ù…ÙŠÙ„'**
  String get text48;

  /// No description provided for @text49.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¶Ø§ÙØ© Ø¹Ù…ÙŠÙ„ Ø¬Ø¯ÙŠØ¯'**
  String get text49;

  /// No description provided for @text50.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø³Ù… Ø§Ù„Ø¹Ù…ÙŠÙ„'**
  String get text50;

  /// No description provided for @text51.
  ///
  /// In ar, this message translates to:
  /// **'Ù…Ø·Ù„ÙˆØ¨'**
  String get text51;

  /// No description provided for @text52.
  ///
  /// In ar, this message translates to:
  /// **'Ø±Ù‚Ù… Ø§Ù„Ù‡Ø§ØªÙ'**
  String get text52;

  /// No description provided for @text53.
  ///
  /// In ar, this message translates to:
  /// **'Ø­ÙØ¸ Ø§Ù„ØªØ¹Ø¯ÙŠÙ„Ø§Øª'**
  String get text53;

  /// No description provided for @text54.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¶Ø§ÙØ© Ø§Ù„Ø¹Ù…ÙŠÙ„'**
  String get text54;

  /// No description provided for @text55.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¯Ø§Ø±Ø© Ø§Ù„Ø¹Ù…Ù„Ø§Ø¡'**
  String get text55;

  /// No description provided for @text56.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ø¹Ù…Ù„Ø§Ø¡ Ø¨Ø¹Ø¯.\nØ§Ø¶ØºØ· Ø¹Ù„Ù‰ + Ù„Ø¥Ø¶Ø§ÙØ© Ø¹Ù…ÙŠÙ„ Ø¬Ø¯ÙŠØ¯.'**
  String get text56;

  /// No description provided for @text57.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø°Ù Ø§Ù„Ø¹Ù…ÙŠÙ„'**
  String get text57;

  /// No description provided for @text58.
  ///
  /// In ar, this message translates to:
  /// **'Ù‡Ù„ Ø£Ù†Øª Ù…ØªØ£ÙƒØ¯ Ù…Ù† Ø­Ø°Ù Ù‡Ø°Ø§ Ø§Ù„Ø¹Ù…ÙŠÙ„ØŸ'**
  String get text58;

  /// No description provided for @text59.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø°Ù'**
  String get text59;

  /// No description provided for @text60.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ¹Ø¯ÙŠÙ„'**
  String get text60;

  /// No description provided for @text61.
  ///
  /// In ar, this message translates to:
  /// **'Ø·Ø¨Ø§Ø¹Ø© ÙƒØ´Ù Ø­Ø³Ø§Ø¨'**
  String get text61;

  /// No description provided for @text62.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¶Ø§ÙØ© Ø¹Ù…ÙŠÙ„'**
  String get text62;

  /// No description provided for @text63.
  ///
  /// In ar, this message translates to:
  /// **'Ø¹Ø±Ø¶'**
  String get text63;

  /// No description provided for @text64.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…ØµØ±ÙˆÙØ§Øª'**
  String get text64;

  /// No description provided for @text65.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ù…ØµØ±ÙˆÙØ§Øª Ø­Ø§Ù„ÙŠØ§Ù‹'**
  String get text65;

  /// No description provided for @text66.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…ØµØ±ÙˆÙØ§Øª'**
  String get text66;

  /// No description provided for @text67.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¶Ø§ÙØ© Ù…ØµØ±ÙˆÙ Ø¬Ø¯ÙŠØ¯'**
  String get text67;

  /// No description provided for @text68.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¨ÙŠØ§Ù† (Ù…Ø«Ø§Ù„: Ø¥ÙŠØ¬Ø§Ø± Ø§Ù„Ù…Ø­Ù„)'**
  String get text68;

  /// No description provided for @text69.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…Ø¨Ù„Øº'**
  String get text69;

  /// No description provided for @text70.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„ØªØµÙ†ÙŠÙ (Ø§Ø®ØªÙŠØ§Ø±ÙŠ)'**
  String get text70;

  /// No description provided for @text71.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø±Ø¬Ø§Ø¡ Ø¥Ø¯Ø®Ø§Ù„ Ø§Ù„Ø¨ÙŠØ§Ù† (Ø§Ø³Ù… Ø§Ù„Ù…ØµØ±ÙˆÙ)'**
  String get text71;

  /// No description provided for @text72.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø±Ø¬Ø§Ø¡ Ø¥Ø¯Ø®Ø§Ù„ Ù…Ø¨Ù„Øº ØµØ­ÙŠØ­ Ø£ÙƒØ¨Ø± Ù…Ù† Ø§Ù„ØµÙØ±'**
  String get text72;

  /// No description provided for @text73.
  ///
  /// In ar, this message translates to:
  /// **'Ø³Ø¬Ù„ Ø­Ø±ÙƒØ© Ø§Ù„Ù…Ø®Ø²ÙˆÙ†'**
  String get text73;

  /// No description provided for @text74.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ø­Ø±ÙƒØ§Øª Ù…Ø³Ø¬Ù„Ø© Ø­Ø§Ù„ÙŠØ§Ù‹'**
  String get text74;

  /// No description provided for @text75.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…Ù†ØªØ¬ ØºÙŠØ± Ù…ÙˆØ¬ÙˆØ¯'**
  String get text75;

  /// No description provided for @text76.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„ÙƒÙ…ÙŠØ© ØºÙŠØ± ÙƒØ§ÙÙŠØ© ÙÙŠ Ø§Ù„Ù…Ø®Ø²ÙˆÙ†'**
  String get text76;

  /// No description provided for @text77.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¹Ù…ÙŠÙ„ ØºÙŠØ± Ù…ÙˆØ¬ÙˆØ¯'**
  String get text77;

  /// No description provided for @text78.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„ÙƒÙ…ÙŠØ© ØºÙŠØ± ÙƒØ§ÙÙŠØ© Ù„Ø¥Ø¹Ø§Ø¯Ø© ØªÙØ¹ÙŠÙ„ Ø§Ù„Ø·Ù„Ø¨'**
  String get text78;

  /// No description provided for @text79.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ù… ÙŠØªÙ… Ø§Ù„Ø¹Ø«ÙˆØ± Ø¹Ù„Ù‰ Ù…Ù†ØªØ¬ Ø¨Ù‡Ø°Ø§ Ø§Ù„Ø¨Ø§Ø±ÙƒÙˆØ¯'**
  String get text79;

  /// No description provided for @text80.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„ÙƒÙ…ÙŠØ© Ø§Ù„Ù…Ø·Ù„ÙˆØ¨Ø© ØºÙŠØ± Ù…ØªÙˆÙØ±Ø© ÙÙŠ Ø§Ù„Ù…Ø®Ø²ÙˆÙ†'**
  String get text80;

  /// No description provided for @text81.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…Ø¨Ù„Øº Ø§Ù„Ù…Ø¯ÙÙˆØ¹ Ù„Ø§ ÙŠÙ…ÙƒÙ† Ø£Ù† ÙŠÙƒÙˆÙ† Ø£ÙƒØ¨Ø± Ù…Ù† Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ'**
  String get text81;

  /// No description provided for @text82.
  ///
  /// In ar, this message translates to:
  /// **'Ø·Ù„Ø¨ Ù…Ø¨ÙŠØ¹Ø§Øª Ø¬Ø¯ÙŠØ¯'**
  String get text82;

  /// No description provided for @text83.
  ///
  /// In ar, this message translates to:
  /// **'Ø¨ÙŠØ¹ Ø¢Ø¬Ù„ (Ø¯ÙŠÙ†)'**
  String get text83;

  /// No description provided for @text84.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø·Ù„Ø¨ ÙƒØ¯ÙŠÙ† Ø¹Ù„Ù‰ Ø§Ù„Ø¹Ù…ÙŠÙ„'**
  String get text84;

  /// No description provided for @text85.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…Ø¨Ù„Øº Ø§Ù„Ù…Ø¯ÙÙˆØ¹ Ù…Ù‚Ø¯Ù…Ø§Ù‹ (Ø§Ø®ØªÙŠØ§Ø±ÙŠ)'**
  String get text85;

  /// No description provided for @text86.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø·Ù„Ø¨Ø§Øª Ø¨Ø¹Ø¯.\nØ§Ø¶ØºØ· Ø¹Ù„Ù‰ + Ù„Ø¥Ù†Ø´Ø§Ø¡ Ø·Ù„Ø¨ Ø¬Ø¯ÙŠØ¯.'**
  String get text86;

  /// No description provided for @text87.
  ///
  /// In ar, this message translates to:
  /// **'Ù‡Ù„ Ø£Ù†Øª Ù…ØªØ£ÙƒØ¯ Ù…Ù† Ø­Ø°Ù Ù‡Ø°Ø§ Ø§Ù„Ø·Ù„Ø¨ØŸ Ø³ÙŠØªÙ… Ø§Ø³ØªØ±Ø¬Ø§Ø¹ ÙƒÙ…ÙŠØ© Ø§Ù„Ù…Ù†ØªØ¬ Ù„Ù„Ù…Ø®Ø²ÙˆÙ†.'**
  String get text87;

  /// No description provided for @text88.
  ///
  /// In ar, this message translates to:
  /// **'Ù‚ÙŠØ¯ Ø§Ù„Ø§Ù†ØªØ¸Ø§Ø± ðŸŸ¡'**
  String get text88;

  /// No description provided for @text89.
  ///
  /// In ar, this message translates to:
  /// **'Ù‚ÙŠØ¯ Ø§Ù„ØªØ¬Ù‡ÙŠØ² ðŸ”µ'**
  String get text89;

  /// No description provided for @text90.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ø§Ù„Ø´Ø­Ù† ðŸŸ '**
  String get text90;

  /// No description provided for @text91.
  ///
  /// In ar, this message translates to:
  /// **'Ù…ÙƒØªÙ…Ù„ ðŸŸ¢'**
  String get text91;

  /// No description provided for @text92.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ø·Ù„Ø¨ ðŸ”´'**
  String get text92;

  /// No description provided for @text93.
  ///
  /// In ar, this message translates to:
  /// **'Ø·Ø¨Ø§Ø¹Ø© Ø§Ù„ÙØ§ØªÙˆØ±Ø© PDF'**
  String get text93;

  /// No description provided for @text94.
  ///
  /// In ar, this message translates to:
  /// **'Ø·Ù„Ø¨ Ø¬Ø¯ÙŠØ¯'**
  String get text94;

  /// No description provided for @text95.
  ///
  /// In ar, this message translates to:
  /// **'Ù‚ÙŠØ¯ Ø§Ù„ØªØ¬Ù‡ÙŠØ²'**
  String get text95;

  /// No description provided for @text96.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ø§Ù„Ø´Ø­Ù†'**
  String get text96;

  /// No description provided for @text97.
  ///
  /// In ar, this message translates to:
  /// **'Ù…ÙƒØªÙ…Ù„'**
  String get text97;

  /// No description provided for @text98.
  ///
  /// In ar, this message translates to:
  /// **'Ù…Ù„ØºÙŠ'**
  String get text98;

  /// No description provided for @text99.
  ///
  /// In ar, this message translates to:
  /// **'Ù‚ÙŠØ¯ Ø§Ù„Ø§Ù†ØªØ¸Ø§Ø±'**
  String get text99;

  /// No description provided for @text100.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ¹Ø¯ÙŠÙ„ ÙŠØ¯ÙˆÙŠ'**
  String get text100;

  /// No description provided for @text101.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¶Ø§ÙØ© Ù…Ù†ØªØ¬'**
  String get text101;

  /// No description provided for @text102.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ØªÙˆØ¬Ø¯ Ù…Ù†ØªØ¬Ø§Øª Ø¨Ø¹Ø¯.\nØ§Ø¶ØºØ· Ø¹Ù„Ù‰ + Ù„Ø¥Ø¶Ø§ÙØ© Ù…Ù†ØªØ¬ Ø¬Ø¯ÙŠØ¯.'**
  String get text102;

  /// No description provided for @text103.
  ///
  /// In ar, this message translates to:
  /// **'Ù‡Ù„ Ø£Ù†Øª Ù…ØªØ£ÙƒØ¯ Ù…Ù† Ø­Ø°Ù Ù‡Ø°Ø§ Ø§Ù„Ù…Ù†ØªØ¬ØŸ'**
  String get text103;

  /// No description provided for @text104.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„ØªÙ‚Ø§Ø±ÙŠØ± ÙˆØ§Ù„Ø£Ø±Ø¨Ø§Ø­'**
  String get text104;

  /// No description provided for @text105.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ø¨ÙŠØ¹Ø§Øª'**
  String get text105;

  /// No description provided for @text106.
  ///
  /// In ar, this message translates to:
  /// **'ØµØ§ÙÙŠ Ø§Ù„Ø±Ø¨Ø­'**
  String get text106;

  /// No description provided for @text107.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ø¯ÙŠÙˆÙ† (Ø§Ù„Ø¢Ø¬Ù„)'**
  String get text107;

  /// No description provided for @text108.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…Ø¨ÙŠØ¹Ø§Øª Ø§Ù„ÙŠÙˆÙ…ÙŠØ©'**
  String get text108;

  /// No description provided for @text109.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ØªÙˆØ¬Ø¯ Ù…Ø¨ÙŠØ¹Ø§Øª Ø¨Ø¹Ø¯'**
  String get text109;

  /// No description provided for @text110.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø£ÙƒØ«Ø± Ù…Ø¨ÙŠØ¹Ø§Ù‹'**
  String get text110;

  /// No description provided for @text111.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¹Ø±Ø¨ÙŠØ©'**
  String get text111;

  /// No description provided for @text112.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ±Ù‚ÙŠØ© Ø§Ù„Ø­Ø³Ø§Ø¨'**
  String get text112;

  /// No description provided for @text113.
  ///
  /// In ar, this message translates to:
  /// **'Ø¨Ø§Ù‚Ø© ØªØ§Ø¬Ù€Ù€Ù€Ø± Ø¨Ø±Ùˆ ðŸš€'**
  String get text113;

  /// No description provided for @text114.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø³ØªÙ…ØªØ¹ Ø¨Ø¥Ø¶Ø§ÙØ© Ù…Ù†ØªØ¬Ø§Øª ÙˆØ¹Ù…Ù„Ø§Ø¡ Ù„Ø§ Ù…Ø­Ø¯ÙˆØ¯ÙŠÙ†ØŒ Ù…Ø¹ Ø¯Ø¹Ù… ÙÙ†ÙŠ Ù…ØªÙ‚Ø¯Ù… ÙˆØ¥Ø­ØµØ§Ø¦ÙŠØ§Øª Ù…ÙØµÙ„Ø©.'**
  String get text114;

  /// No description provided for @text115.
  ///
  /// In ar, this message translates to:
  /// **'ÙŠØ¬Ø¨ Ø¹Ù„ÙŠÙƒ Ø±Ø¨Ø· Ø­Ø³Ø§Ø¨Ùƒ Ø¨Ù€ Google Ø£ÙˆÙ„Ø§Ù‹ Ù„ØªØªÙ…ÙƒÙ† Ù…Ù† Ø§Ù„Ø§Ø´ØªØ±Ø§Ùƒ ÙÙŠ Ø§Ù„Ø¨Ø§Ù‚Ø©.'**
  String get text115;

  /// No description provided for @text116.
  ///
  /// In ar, this message translates to:
  /// **'Ø±Ø¨Ø· Ø§Ù„Ø­Ø³Ø§Ø¨ Ø§Ù„Ø¢Ù†'**
  String get text116;

  /// No description provided for @text117.
  ///
  /// In ar, this message translates to:
  /// **'Ø¹Ù…Ù„ÙŠØ© Ø´Ø±Ø§Ø¡ Ø§Ù„Ø¨Ø§Ù‚Ø§Øª ÙˆØ¯ÙØ¹ Ø§Ù„Ø§Ø´ØªØ±Ø§ÙƒØ§Øª (10 Ø¯ÙˆÙ„Ø§Ø±/Ø´Ù‡Ø±ÙŠØ§Ù‹) Ù…ØªØ§Ø­Ø© ÙÙ‚Ø· Ø¹Ø¨Ø± ØªØ·Ø¨ÙŠÙ‚ Ø§Ù„Ø£Ù†Ø¯Ø±ÙˆÙŠØ¯ Ù…Ù† Ù…ØªØ¬Ø± Google PlayØŒ ÙˆÙ„Ø§ ÙŠÙ…ÙƒÙ† Ø§Ù„Ø¯ÙØ¹ Ø¹Ø¨Ø± Ù…ØªØµÙØ­ Ø§Ù„ÙˆÙŠØ¨.'**
  String get text117;

  /// No description provided for @text118.
  ///
  /// In ar, this message translates to:
  /// **'ÙŠØ±Ø¬Ù‰ ØªØ­Ù…ÙŠÙ„ Ø§Ù„ØªØ·Ø¨ÙŠÙ‚ Ø¹Ù„Ù‰ Ù‡Ø§ØªÙÙƒ Ù„Ø¥ØªÙ…Ø§Ù… Ø¹Ù…Ù„ÙŠØ© Ø§Ù„ØªØ±Ù‚ÙŠØ© ÙˆØ§Ù„Ø¯ÙØ¹.'**
  String get text118;

  /// No description provided for @text119.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ø§Ø´ØªØ±Ø§ÙƒØ§Øª Ù…ØªØ§Ø­Ø© Ø­Ø§Ù„ÙŠØ§Ù‹. Ø§Ù„Ø±Ø¬Ø§Ø¡ Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø© Ù„Ø§Ø­Ù‚Ø§Ù‹.'**
  String get text119;

  /// No description provided for @text120.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø´ØªØ±Ùƒ Ø§Ù„Ø¢Ù†'**
  String get text120;

  /// No description provided for @text121.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø³ØªØ¹Ø§Ø¯Ø© Ø§Ù„Ù…Ø´ØªØ±ÙŠØ§Øª Ø§Ù„Ø³Ø§Ø¨Ù‚Ø©'**
  String get text121;

  /// No description provided for @text122.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¯Ø§Ø±Ø© Ø§Ù„Ù…ÙˆØ±Ø¯ÙŠÙ†'**
  String get text122;

  /// No description provided for @text123.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ù…ÙˆØ±Ø¯ÙŠÙ† Ø­Ø§Ù„ÙŠØ§Ù‹'**
  String get text123;

  /// No description provided for @text124.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ø±Ù‚Ù… Ù‡Ø§ØªÙ'**
  String get text124;

  /// No description provided for @text125.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¯ÙŠÙˆÙ† Ø§Ù„Ù…Ø³ØªØ­Ù‚Ø©'**
  String get text125;

  /// No description provided for @text126.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¶Ø§ÙØ© Ù…ÙˆØ±Ø¯ Ø¬Ø¯ÙŠØ¯'**
  String get text126;

  /// No description provided for @text127.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø³Ù… Ø§Ù„Ù…ÙˆØ±Ø¯'**
  String get text127;

  /// No description provided for @text128.
  ///
  /// In ar, this message translates to:
  /// **'Ø±Ù‚Ù… Ø§Ù„Ø¬ÙˆØ§Ù„'**
  String get text128;

  /// No description provided for @text129.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø±ØµÙŠØ¯ Ø§Ù„Ø§ÙØªØªØ§Ø­ÙŠ (Ø§Ù„Ø¯ÙŠÙˆÙ†)'**
  String get text129;

  /// No description provided for @text130.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ¹Ø¯ÙŠÙ„ Ø§Ù„Ù…ÙˆØ±Ø¯'**
  String get text130;

  /// No description provided for @text131.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ­Ø¯ÙŠØ« Ø§Ù„Ø¯ÙŠÙˆÙ†'**
  String get text131;

  /// No description provided for @permCanManageProducts.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¶Ø§ÙØ© ÙˆØªØ¹Ø¯ÙŠÙ„ Ø§Ù„Ù…Ù†ØªØ¬Ø§Øª'**
  String get permCanManageProducts;

  /// No description provided for @permCanViewCost.
  ///
  /// In ar, this message translates to:
  /// **'Ø±Ø¤ÙŠØ© Ø³Ø¹Ø± Ø§Ù„ØªÙƒÙ„ÙØ© ÙˆØ§Ù„Ø£Ø±Ø¨Ø§Ø­'**
  String get permCanViewCost;

  /// No description provided for @permCanManageInventory.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¯Ø§Ø±Ø© ÙˆØ¬Ø±Ø¯ Ø§Ù„Ù…Ø®Ø²ÙˆÙ†'**
  String get permCanManageInventory;

  /// No description provided for @permCanCreateOrders.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ù†Ø´Ø§Ø¡ ÙÙˆØ§ØªÙŠØ± ÙˆØ·Ù„Ø¨Ø§Øª Ø¬Ø¯ÙŠØ¯Ø©'**
  String get permCanCreateOrders;

  /// No description provided for @permCanCancelOrders.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ¹Ø¯ÙŠÙ„ Ø£Ùˆ Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ø·Ù„Ø¨Ø§Øª'**
  String get permCanCancelOrders;

  /// No description provided for @permCanSellOnCredit.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¨ÙŠØ¹ Ø¨Ø§Ù„Ø¢Ø¬Ù„ / Ø§Ù„Ø¯ÙŠÙ†'**
  String get permCanSellOnCredit;

  /// No description provided for @permCanManageCustomers.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¶Ø§ÙØ© ÙˆØªØ¹Ø¯ÙŠÙ„ Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ø¹Ù…Ù„Ø§Ø¡'**
  String get permCanManageCustomers;

  /// No description provided for @permCanReceivePayments.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ³Ø¯ÙŠØ¯ Ø§Ù„Ø¯ÙŠÙˆÙ† ÙˆØ§Ø³ØªÙ„Ø§Ù… Ø§Ù„Ù…Ø¨Ø§Ù„Øº'**
  String get permCanReceivePayments;

  /// No description provided for @permCanManageExpenses.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ³Ø¬ÙŠÙ„ ÙˆÙ…ØªØ§Ø¨Ø¹Ø© Ø§Ù„Ù…ØµØ±ÙˆÙØ§Øª'**
  String get permCanManageExpenses;

  /// No description provided for @employeePermissions.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…ÙˆØ¸ÙÙŠÙ† ÙˆØ§Ù„ØµÙ„Ø§Ø­ÙŠØ§Øª (Pro)'**
  String get employeePermissions;

  /// No description provided for @permissionSettings.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø§Ù„ØµÙ„Ø§Ø­ÙŠØ§Øª'**
  String get permissionSettings;

  /// No description provided for @credit.
  ///
  /// In ar, this message translates to:
  /// **'Ø¢Ø¬Ù„'**
  String get credit;

  /// No description provided for @customer.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¹Ù…ÙŠÙ„'**
  String get customer;

  /// No description provided for @walkInCustomer.
  ///
  /// In ar, this message translates to:
  /// **'Ø¹Ù…ÙŠÙ„ Ù†Ù‚Ø¯ÙŠ (Ø¨Ø¯ÙˆÙ† Ø­Ø³Ø§Ø¨)'**
  String get walkInCustomer;

  /// No description provided for @cancelled.
  ///
  /// In ar, this message translates to:
  /// **'Ù…Ù„ØºÙŠ'**
  String get cancelled;

  /// No description provided for @settingsAccountEmployees.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø­Ø³Ø§Ø¨ ÙˆØ§Ù„Ù…ÙˆØ¸ÙÙŠÙ†'**
  String get settingsAccountEmployees;

  /// No description provided for @settingsPersonalMerchantAccount.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø³Ø§Ø¨ Ø§Ù„ØªØ§Ø¬Ø± (Ø§Ù„Ø¥Ø¯Ø§Ø±Ø©)'**
  String get settingsPersonalMerchantAccount;

  /// No description provided for @settingsUnknown.
  ///
  /// In ar, this message translates to:
  /// **'ØºÙŠØ± Ù…Ø¹Ø±ÙˆÙ'**
  String get settingsUnknown;

  /// No description provided for @settingsEmployeesPermissions.
  ///
  /// In ar, this message translates to:
  /// **'(Pro) Ø§Ù„Ù…ÙˆØ¸ÙÙŠÙ† ÙˆØ§Ù„ØµÙ„Ø§Ø­ÙŠØ§Øª'**
  String get settingsEmployeesPermissions;

  /// No description provided for @settingsCentralizedAuditLog.
  ///
  /// In ar, this message translates to:
  /// **'Ø³Ø¬Ù„ Ø­Ø±ÙƒØ§Øª Ø§Ù„Ù†Ø¸Ø§Ù… (Ø§Ù„Ù…Ø±Ø§Ù‚Ø¨Ø©)'**
  String get settingsCentralizedAuditLog;

  /// No description provided for @settingsMonitorActions.
  ///
  /// In ar, this message translates to:
  /// **'Ù…Ø±Ø§Ù‚Ø¨Ø© Ø¬Ù…ÙŠØ¹ Ø­Ø±ÙƒØ§Øª Ø§Ù„Ù…ÙˆØ¸ÙÙŠÙ† ÙˆØ§Ù„Ù…Ø¨ÙŠØ¹Ø§Øª'**
  String get settingsMonitorActions;

  /// No description provided for @settingsStoreSettings.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø§Ù„Ù…ØªØ¬Ø±'**
  String get settingsStoreSettings;

  /// No description provided for @settingsBackupSecurity.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù†Ø³Ø® Ø§Ù„Ø§Ø­ØªÙŠØ§Ø·ÙŠ ÙˆØ§Ù„Ø£Ù…Ø§Ù†'**
  String get settingsBackupSecurity;

  /// No description provided for @settingsThermalPrinter.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø§Ù„Ø·Ø§Ø¨Ø¹Ø© Ø§Ù„Ø­Ø±Ø§Ø±ÙŠØ©'**
  String get settingsThermalPrinter;

  /// No description provided for @settingsStoreBranding.
  ///
  /// In ar, this message translates to:
  /// **'Ù‡ÙˆÙŠØ© Ø§Ù„Ù…ØªØ¬Ø± (Ø§Ù„Ø´Ø¹Ø§Ø± ÙˆØ§Ù„ÙÙˆØ§ØªÙŠØ±)'**
  String get settingsStoreBranding;

  /// No description provided for @settingsSystemPreferences.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙØ¶ÙŠÙ„Ø§Øª Ø§Ù„Ù†Ø¸Ø§Ù…'**
  String get settingsSystemPreferences;

  /// No description provided for @settingsSupportRating.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¯Ø¹Ù… ÙˆØ§Ù„ØªÙ‚ÙŠÙŠÙ…'**
  String get settingsSupportRating;

  /// No description provided for @settingsAppUserGuide.
  ///
  /// In ar, this message translates to:
  /// **'Ø¯Ù„ÙŠÙ„ Ø§Ø³ØªØ®Ø¯Ø§Ù… Ø§Ù„ØªØ·Ø¨ÙŠÙ‚ (Ø´Ø±Ø­ ÙÙŠØ¯ÙŠÙˆ)'**
  String get settingsAppUserGuide;

  /// No description provided for @settingsHowToSetup.
  ///
  /// In ar, this message translates to:
  /// **'ÙƒÙŠÙÙŠØ© ØªØ¬Ù‡ÙŠØ² Ù…ØªØ¬Ø±Ùƒ ÙˆØ¥Ø¶Ø§ÙØ© Ø§Ù„Ù…Ù†ØªØ¬Ø§Øª'**
  String get settingsHowToSetup;

  /// No description provided for @settingsFollowTikTok.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ§Ø¨Ø¹Ù†Ø§ Ø¹Ù„Ù‰ ØªÙŠÙƒ ØªÙˆÙƒ'**
  String get settingsFollowTikTok;

  /// No description provided for @settingsSuggestionsUpdates.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ù„Ø§Ù‚ØªØ±Ø§Ø­Ø§Øª ÙˆØ§Ù„ØªØ­Ø¯ÙŠØ«Ø§Øª Ø§Ù„Ø¬Ø¯ÙŠØ¯Ø©'**
  String get settingsSuggestionsUpdates;

  /// No description provided for @settingsCouldNotOpenLink.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ¹Ø°Ø± ÙØªØ­ Ø§Ù„Ø±Ø§Ø¨Ø·'**
  String get settingsCouldNotOpenLink;

  /// No description provided for @settingsEmailSupport.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¯Ø¹Ù… Ø§Ù„ÙÙ†ÙŠ Ø¹Ø¨Ø± Ø§Ù„Ø¨Ø±ÙŠØ¯ Ø§Ù„Ø¥Ù„ÙƒØªØ±ÙˆÙ†ÙŠ'**
  String get settingsEmailSupport;

  /// No description provided for @settingsTechnicalIssues.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø­Ù„ Ø§Ù„Ù…Ø´ÙƒÙ„Ø§Øª Ø§Ù„ØªÙ‚Ù†ÙŠØ© ÙˆØ§Ù„Ø§Ø³ØªÙØ³Ø§Ø±Ø§Øª'**
  String get settingsTechnicalIssues;

  /// No description provided for @settingsCouldNotOpenEmail.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ¹Ø°Ø± ÙØªØ­ ØªØ·Ø¨ÙŠÙ‚ Ø§Ù„Ø¨Ø±ÙŠØ¯ Ø§Ù„Ø¥Ù„ÙƒØªØ±ÙˆÙ†ÙŠ'**
  String get settingsCouldNotOpenEmail;

  /// No description provided for @settingsRatePlayStore.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ‚ÙŠÙŠÙ… Ø§Ù„ØªØ·Ø¨ÙŠÙ‚ Ø¹Ù„Ù‰ Ù…ØªØ¬Ø± Ø¨Ù„Ø§ÙŠ'**
  String get settingsRatePlayStore;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **'Ø³ÙŠØ§Ø³Ø© Ø§Ù„Ø®ØµÙˆØµÙŠØ©'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsCouldNotOpenBrowser.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ¹Ø°Ø± ÙØªØ­ Ø§Ù„Ù…ØªØµÙØ­. ØªØ£ÙƒØ¯ Ù…Ù† ÙˆØ¬ÙˆØ¯ Ù…ØªØµÙØ­ ÙÙŠ Ø¬Ù‡Ø§Ø²Ùƒ.'**
  String get settingsCouldNotOpenBrowser;

  /// No description provided for @settingsAppVersion.
  ///
  /// In ar, this message translates to:
  /// **'Ø¨Ø³Ø·Ù‡ - Ù†Ù‚Ø·Ø© Ø¨ÙŠØ¹ v1.0.42\nØµÙÙ†Ø¹ Ø¨Ø­Ø¨ ðŸ’›'**
  String get settingsAppVersion;

  /// No description provided for @empPermViewCostProfits.
  ///
  /// In ar, this message translates to:
  /// **'Ø±Ø¤ÙŠØ© Ø§Ù„ØªÙƒÙ„ÙØ© ÙˆØ§Ù„Ø£Ø±Ø¨Ø§Ø­'**
  String get empPermViewCostProfits;

  /// No description provided for @empPermManageInventory.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¯Ø§Ø±Ø© ÙˆØªØªØ¨Ø¹ Ø§Ù„Ù…Ø®Ø²ÙˆÙ†'**
  String get empPermManageInventory;

  /// No description provided for @empPermCreateInvoices.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ù†Ø´Ø§Ø¡ ÙÙˆØ§ØªÙŠØ± ÙˆØ·Ù„Ø¨Ø§Øª Ø¬Ø¯ÙŠØ¯Ø©'**
  String get empPermCreateInvoices;

  /// No description provided for @empPermEditCancelOrders.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ¹Ø¯ÙŠÙ„ Ø£Ùˆ Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ø·Ù„Ø¨Ø§Øª'**
  String get empPermEditCancelOrders;

  /// No description provided for @empPermSellCredit.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¨ÙŠØ¹ Ø¨Ø§Ù„Ø¢Ø¬Ù„ (Ø§Ù„Ø¯ÙŠÙˆÙ†)'**
  String get empPermSellCredit;

  /// No description provided for @empPermAddEditCustomer.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¶Ø§ÙØ© ÙˆØªØ¹Ø¯ÙŠÙ„ Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ø¹Ù…Ù„Ø§Ø¡'**
  String get empPermAddEditCustomer;

  /// No description provided for @empPermSettleDebts.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ³ÙˆÙŠØ© Ø§Ù„Ø¯ÙŠÙˆÙ† ÙˆØ§Ø³ØªÙ„Ø§Ù… Ø§Ù„Ø¯ÙØ¹Ø§Øª'**
  String get empPermSettleDebts;

  /// No description provided for @empPermRecordExpenses.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ³Ø¬ÙŠÙ„ ÙˆØªØªØ¨Ø¹ Ø§Ù„Ù…ØµØ±ÙˆÙØ§Øª'**
  String get empPermRecordExpenses;

  /// No description provided for @empPermViewReports.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø³Ù…Ø§Ø­ Ø¨Ø±Ø¤ÙŠØ© Ù‚Ø³Ù… Ø§Ù„ØªÙ‚Ø§Ø±ÙŠØ±'**
  String get empPermViewReports;

  /// No description provided for @empPermViewAllOrders.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø³Ù…Ø§Ø­ Ø¨Ø±Ø¤ÙŠØ© Ø¬Ù…ÙŠØ¹ Ø§Ù„Ø·Ù„Ø¨Ø§Øª'**
  String get empPermViewAllOrders;

  /// No description provided for @empPermAdd.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¶Ø§ÙØ©'**
  String get empPermAdd;

  /// No description provided for @empPermCancel.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ù„ØºØ§Ø¡'**
  String get empPermCancel;

  /// No description provided for @empImportantInstructions.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ¹Ù„ÙŠÙ…Ø§Øª Ù‡Ø§Ù…Ø© Ù„Ù„ØªØ§Ø¬Ø±'**
  String get empImportantInstructions;

  /// No description provided for @empInstruction1.
  ///
  /// In ar, this message translates to:
  /// **'1. ÙŠÙ…ÙƒÙ†Ùƒ Ø¥Ø¶Ø§ÙØ© Ø­Ø¯ Ø£Ù‚ØµÙ‰ 3 Ù…ÙˆØ¸ÙÙŠÙ†.'**
  String get empInstruction1;

  /// No description provided for @empInstruction2.
  ///
  /// In ar, this message translates to:
  /// **'2. Ø¹Ù†Ø¯Ù…Ø§ ÙŠØ­Ù…Ù„ Ø§Ù„Ù…ÙˆØ¸Ù Ø§Ù„ØªØ·Ø¨ÙŠÙ‚ØŒ ÙŠØ¬Ø¨ Ø£Ù† ÙŠØ®ØªØ§Ø± (Ø¯Ø®ÙˆÙ„ Ù…ÙˆØ¸Ù Ø¨Ø§Ù„Ø±Ù…Ø²).'**
  String get empInstruction2;

  /// No description provided for @empInstruction3.
  ///
  /// In ar, this message translates to:
  /// **'3. Ø³ÙŠÙØ·Ù„Ø¨ Ù…Ù†Ù‡ Ø¥Ø¯Ø®Ø§Ù„ Ø¥ÙŠÙ…ÙŠÙ„Ùƒ Ø§Ù„Ø£Ø³Ø§Ø³ÙŠ ÙˆØ±Ù…Ø² Ø§Ù„Ø¯Ø®ÙˆÙ„ Ø§Ù„Ø°ÙŠ Ø£Ù†Ø´Ø£ØªÙ‡ Ù„Ù‡.'**
  String get empInstruction3;

  /// No description provided for @empMainEmail.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥ÙŠÙ…ÙŠÙ„Ùƒ Ø§Ù„Ø£Ø³Ø§Ø³ÙŠ (Ø§Ù„Ø°ÙŠ ÙŠØ¬Ø¨ Ø£Ù† ÙŠÙƒØªØ¨Ù‡ Ø§Ù„Ù…ÙˆØ¸Ù):'**
  String get empMainEmail;

  /// No description provided for @empEmployeeList.
  ///
  /// In ar, this message translates to:
  /// **'Ù‚Ø§Ø¦Ù…Ø© Ø§Ù„Ù…ÙˆØ¸ÙÙŠÙ†'**
  String get empEmployeeList;

  /// No description provided for @empNoEmployees.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ù…ÙˆØ¸ÙÙŠÙ† Ø­Ø§Ù„ÙŠØ§Ù‹'**
  String get empNoEmployees;

  /// No description provided for @taxSettingsOptional.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø§Ù„Ø¶Ø±ÙŠØ¨Ø© (Ø§Ø®ØªÙŠØ§Ø±ÙŠ)'**
  String get taxSettingsOptional;

  /// No description provided for @taxSettingsWarning.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ­Ø¯ÙŠØ¯ Ø§Ù„Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ù‡Ù†Ø§ Ø³ÙŠÙ„ØºÙŠ Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø§Ù„Ù…ØªØ¬Ø± Ø§Ù„Ø¹Ø§Ù…Ø© Ù„Ù‡Ø°Ø§ Ø§Ù„Ù…Ù†ØªØ¬ØŒ ÙˆØ³ÙŠØ¤Ø«Ø± Ù…Ø¨Ø§Ø´Ø±Ø© Ø¹Ù„Ù‰ Ø§Ù„Ø­Ø³Ø§Ø¨ Ø§Ù„Ù†Ù‡Ø§Ø¦ÙŠ.'**
  String get taxSettingsWarning;

  /// No description provided for @taxPercentage.
  ///
  /// In ar, this message translates to:
  /// **'Ù†Ø³Ø¨Ø© Ø§Ù„Ø¶Ø±ÙŠØ¨Ø© Ø§Ù„Ø®Ø§ØµØ© Ø¨Ø§Ù„Ù…Ù†ØªØ¬ (%)'**
  String get taxPercentage;

  /// No description provided for @taxIncludedInPrice.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø³Ø¹Ø± Ø§Ù„Ù…Ø­Ø¯Ø¯ ÙŠØ´Ù…Ù„ Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©'**
  String get taxIncludedInPrice;

  /// No description provided for @recipeOptional.
  ///
  /// In ar, this message translates to:
  /// **'ÙˆØµÙØ© Ø§Ù„Ù…Ù†ØªØ¬ (Ù…ÙˆØ§Ø¯ Ø®Ø§Ù…) - Ø§Ø®ØªÙŠØ§Ø±ÙŠ'**
  String get recipeOptional;

  /// No description provided for @searchByNamePhone.
  ///
  /// In ar, this message translates to:
  /// **'Ø¨Ø­Ø« Ø¨Ø§Ù„Ø§Ø³Ù… Ø£Ùˆ Ø±Ù‚Ù… Ø§Ù„Ù‡Ø§ØªÙ'**
  String get searchByNamePhone;

  /// No description provided for @deleteCustomerWarning.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ­Ø°ÙŠØ±: Ø­Ø°Ù Ù…Ù„Ù Ø¹Ù…ÙŠÙ„'**
  String get deleteCustomerWarning;

  /// No description provided for @deleteCustomerText.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø°Ù Ø§Ù„Ø¹Ù…ÙŠÙ„ Ø³ÙŠØ¤Ø¯ÙŠ Ø¥Ù„Ù‰ Ù…Ø³Ø­ Ø³Ø¬Ù„Ù‡ Ø§Ù„Ù…Ø§Ù„ÙŠ ÙˆØ¯ÙŠÙˆÙ†Ù‡ Ù…Ù† Ø§Ù„Ù†Ø¸Ø§Ù… Ù†Ù‡Ø§Ø¦ÙŠØ§Ù‹. Ù„Ø§ ÙŠÙ…ÙƒÙ† Ø§Ù„ØªØ±Ø§Ø¬Ø¹ Ø¹Ù† Ù‡Ø°Ø§ Ø§Ù„Ø¥Ø¬Ø±Ø§Ø¡.'**
  String get deleteCustomerText;

  /// No description provided for @enterPinToConfirm.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ù„ØªØ£ÙƒÙŠØ¯ (PIN) Ø£Ø¯Ø®Ù„ Ø±Ù…Ø² Ø§Ù„Ø£Ù…Ø§Ù†:'**
  String get enterPinToConfirm;

  /// No description provided for @confirmDelete.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ£ÙƒÙŠØ¯ ÙˆØ­Ø°Ù'**
  String get confirmDelete;

  /// No description provided for @cancelBtn.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ±Ø§Ø¬Ø¹'**
  String get cancelBtn;

  /// No description provided for @backupExportSuccess.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… ØªØµØ¯ÙŠØ± Ø§Ù„Ù†Ø³Ø®Ø© Ø§Ù„Ø§Ø­ØªÙŠØ§Ø·ÙŠØ© Ø¨Ù†Ø¬Ø§Ø­!'**
  String get backupExportSuccess;

  /// No description provided for @backupExportError.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø¯Ø« Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ Ø§Ù„ØªØµØ¯ÙŠØ±'**
  String get backupExportError;

  /// No description provided for @backupImportSuccess.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ø§Ø³ØªØ¹Ø§Ø¯Ø© Ø§Ù„Ù†Ø³Ø®Ø© Ø¨Ù†Ø¬Ø§Ø­!'**
  String get backupImportSuccess;

  /// No description provided for @backupImportError.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø¯Ø« Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ Ø§Ù„Ø§Ø³ØªØ¹Ø§Ø¯Ø©'**
  String get backupImportError;

  /// No description provided for @backupSecurityTitle.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù†Ø³Ø®Ø© Ø§Ù„Ø§Ø­ØªÙŠØ§Ø·ÙŠØ© Ø§Ù„Ù…Ø­Ù„ÙŠØ©'**
  String get backupSecurityTitle;

  /// No description provided for @localBackupRestore.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ù†Ø´Ø§Ø¡ ÙˆØ§Ø³ØªØ¹Ø§Ø¯Ø© Ø§Ù„Ù†Ø³Ø®Ø©'**
  String get localBackupRestore;

  /// No description provided for @localBackupDesc.
  ///
  /// In ar, this message translates to:
  /// **'ÙŠØªÙ… Ø­ÙØ¸ Ù†Ø³Ø®Ø© Ù…Ù† Ù…Ù†ØªØ¬Ø§ØªÙƒ (Ø¨Ø§Ø³ØªØ«Ù†Ø§Ø¡ Ø§Ù„ÙÙˆØ§ØªÙŠØ± ÙˆØ§Ù„ØµÙˆØ±) ÙÙŠ Ù…Ù„Ù Ø¯Ø§Ø®Ù„ Ø¬Ù‡Ø§Ø²Ùƒ. ÙŠÙ…ÙƒÙ†Ùƒ Ø§Ø³ØªØ¹Ø§Ø¯Ø© Ù‡Ø°Ù‡ Ø§Ù„Ù†Ø³Ø®Ø© ÙÙŠ Ø£ÙŠ ÙˆÙ‚Øª.'**
  String get localBackupDesc;

  /// No description provided for @exportBackupToDevice.
  ///
  /// In ar, this message translates to:
  /// **'Ø­ÙØ¸ Ø§Ù„Ù†Ø³Ø®Ø© ÙÙŠ Ø§Ù„Ø¬Ù‡Ø§Ø²'**
  String get exportBackupToDevice;

  /// No description provided for @importBackupFromDevice.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø³ØªØ¹Ø§Ø¯Ø© Ø§Ù„Ù†Ø³Ø®Ø© Ù…Ù† Ø§Ù„Ø¬Ù‡Ø§Ø²'**
  String get importBackupFromDevice;

  /// No description provided for @printerErrorConnecting.
  ///
  /// In ar, this message translates to:
  /// **'Ø®Ø·Ø£ ÙÙŠ Ø¬Ù„Ø¨ Ø§Ù„Ø£Ø¬Ù‡Ø²Ø© Ø§Ù„Ù…Ù‚ØªØ±Ù†Ø©'**
  String get printerErrorConnecting;

  /// No description provided for @printerConnecting.
  ///
  /// In ar, this message translates to:
  /// **'Ø¬Ø§Ø±ÙŠ Ø§Ù„Ø§ØªØµØ§Ù„...'**
  String get printerConnecting;

  /// No description provided for @printerConnectedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ø§Ù„Ø§ØªØµØ§Ù„ Ø¨Ø§Ù„Ø·Ø§Ø¨Ø¹Ø© Ø¨Ù†Ø¬Ø§Ø­'**
  String get printerConnectedSuccess;

  /// No description provided for @printerConnectionFailed.
  ///
  /// In ar, this message translates to:
  /// **'ÙØ´Ù„ Ø§Ù„Ø§ØªØµØ§Ù„ Ø¨Ø§Ù„Ø·Ø§Ø¨Ø¹Ø©'**
  String get printerConnectionFailed;

  /// No description provided for @printerSelectFirst.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø±Ø¬Ø§Ø¡ ØªØ­Ø¯ÙŠØ¯ Ø·Ø§Ø¨Ø¹Ø© Ø£ÙˆÙ„Ø§Ù‹'**
  String get printerSelectFirst;

  /// No description provided for @printerDisconnected.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ù‚Ø·Ø¹ Ø§Ù„Ø§ØªØµØ§Ù„'**
  String get printerDisconnected;

  /// No description provided for @printerNotConnected.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø·Ø§Ø¨Ø¹Ø© Ù…ØªØµÙ„Ø©'**
  String get printerNotConnected;

  /// No description provided for @printerConnectionSettings.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø§ØªØµØ§Ù„ Ø§Ù„Ø·Ø§Ø¨Ø¹Ø©'**
  String get printerConnectionSettings;

  /// No description provided for @printerSelectDevice.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø®ØªÙŠØ§Ø± Ø§Ù„Ø·Ø§Ø¨Ø¹Ø© (Ø¨Ù„ÙˆØªÙˆØ«)'**
  String get printerSelectDevice;

  /// No description provided for @printerSelectHint.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø¯Ø¯ Ø·Ø§Ø¨Ø¹Ø©...'**
  String get printerSelectHint;

  /// No description provided for @printerPaperSize.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø¬Ù… Ø§Ù„ÙˆØ±Ù‚'**
  String get printerPaperSize;

  /// No description provided for @printerSize58.
  ///
  /// In ar, this message translates to:
  /// **'58 Ù…Ù„ÙŠÙ…ØªØ± (ØµØºÙŠØ±)'**
  String get printerSize58;

  /// No description provided for @printerSize80.
  ///
  /// In ar, this message translates to:
  /// **'80 Ù…Ù„ÙŠÙ…ØªØ± (ÙƒØ¨ÙŠØ±)'**
  String get printerSize80;

  /// No description provided for @printerRefresh.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ­Ø¯ÙŠØ« Ø§Ù„Ù‚Ø§Ø¦Ù…Ø©'**
  String get printerRefresh;

  /// No description provided for @printerConnect.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙˆØµÙŠÙ„'**
  String get printerConnect;

  /// No description provided for @printerDisconnect.
  ///
  /// In ar, this message translates to:
  /// **'Ù‚Ø·Ø¹ Ø§Ù„Ø§ØªØµØ§Ù„'**
  String get printerDisconnect;

  /// No description provided for @brandingErrorPickingImage.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø¯Ø« Ø®Ø·Ø£ ÙÙŠ Ø§Ø®ØªÙŠØ§Ø± Ø§Ù„ØµÙˆØ±Ø©'**
  String get brandingErrorPickingImage;

  /// No description provided for @brandingSavedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ø§Ù„Ø­ÙØ¸ Ø¨Ù†Ø¬Ø§Ø­'**
  String get brandingSavedSuccess;

  /// No description provided for @brandingSave.
  ///
  /// In ar, this message translates to:
  /// **'Ø­ÙØ¸'**
  String get brandingSave;

  /// No description provided for @brandingSelectLogo.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¶Ø§ÙØ© Ø§Ù„Ø´Ø¹Ø§Ø±'**
  String get brandingSelectLogo;

  /// No description provided for @brandingRemoveLogo.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø²Ø§Ù„Ø© Ø§Ù„Ø´Ø¹Ø§Ø±'**
  String get brandingRemoveLogo;

  /// No description provided for @brandingStoreName.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø³Ù… Ø§Ù„Ù…ØªØ¬Ø±'**
  String get brandingStoreName;

  /// No description provided for @brandingStorePhone.
  ///
  /// In ar, this message translates to:
  /// **'Ø±Ù‚Ù… Ù‡Ø§ØªÙ Ø§Ù„Ù…ØªØ¬Ø±'**
  String get brandingStorePhone;

  /// No description provided for @brandingStoreAddress.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¹Ù†ÙˆØ§Ù†'**
  String get brandingStoreAddress;

  /// No description provided for @brandingTaxSettings.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø§Ù„Ø¶Ø±ÙŠØ¨Ø© Ø§Ù„Ø§ÙØªØ±Ø§Ø¶ÙŠØ©'**
  String get brandingTaxSettings;

  /// No description provided for @brandingDefaultTax.
  ///
  /// In ar, this message translates to:
  /// **'Ù†Ø³Ø¨Ø© Ø§Ù„Ø¶Ø±ÙŠØ¨Ø© Ø§Ù„Ø§ÙØªØ±Ø§Ø¶ÙŠØ© (%)'**
  String get brandingDefaultTax;

  /// No description provided for @brandingDefaultTaxHelper.
  ///
  /// In ar, this message translates to:
  /// **'Ù‡Ø°Ù‡ Ù‡ÙŠ Ø§Ù„Ù†Ø³Ø¨Ø© Ø§Ù„ØªÙŠ Ø³ÙŠØªÙ… ØªØ·Ø¨ÙŠÙ‚Ù‡Ø§ ØªÙ„Ù‚Ø§Ø¦ÙŠØ§Ù‹ Ø¹Ù„Ù‰ Ø£ÙŠ Ù…Ù†ØªØ¬ Ø¬Ø¯ÙŠØ¯ ØªØ¶ÙŠÙÙ‡. ÙŠÙ…ÙƒÙ†Ùƒ ØªØºÙŠÙŠØ± Ø§Ù„Ù†Ø³Ø¨Ø© Ù„ÙƒÙ„ Ù…Ù†ØªØ¬ Ù„Ø§Ø­Ù‚Ø§Ù‹ Ù…Ù† Ù‚Ø³Ù… Ø§Ù„Ù…Ù†ØªØ¬Ø§Øª.'**
  String get brandingDefaultTaxHelper;

  /// No description provided for @brandingTaxInclusive.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø£Ø³Ø¹Ø§Ø± ØªØ´Ù…Ù„ Ø§Ù„Ø¶Ø±ÙŠØ¨Ø© (Ø§Ù„Ø§ÙØªØ±Ø§Ø¶ÙŠ)'**
  String get brandingTaxInclusive;

  /// No description provided for @brandingTaxInclusiveHelper.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙØ¹ÙŠÙ„ Ù‡Ø°Ø§ Ø§Ù„Ø®ÙŠØ§Ø± ÙŠØ¹Ù†ÙŠ Ø£Ù† Ø§Ù„Ø³Ø¹Ø± Ø§Ù„Ø°ÙŠ ØªØ¯Ø®Ù„Ù‡ Ù„Ù„Ù…Ù†ØªØ¬ Ù‡Ùˆ Ø§Ù„Ø³Ø¹Ø± Ø§Ù„Ù†Ù‡Ø§Ø¦ÙŠ Ø§Ù„Ø´Ø§Ù…Ù„ Ù„Ù„Ø¶Ø±ÙŠØ¨Ø©.'**
  String get brandingTaxInclusiveHelper;

  /// No description provided for @brandingZatcaTitle.
  ///
  /// In ar, this message translates to:
  /// **'Ù…ØªØ·Ù„Ø¨Ø§Øª Ø§Ù„ÙÙˆØªØ±Ø© Ø§Ù„Ø¥Ù„ÙƒØªØ±ÙˆÙ†ÙŠØ© (ZATCA)'**
  String get brandingZatcaTitle;

  /// No description provided for @brandingZatcaDesc.
  ///
  /// In ar, this message translates to:
  /// **'Ù…Ø·Ù„ÙˆØ¨Ø© Ù„Ù€ \"Ø§Ù„ÙÙˆØªØ±Ø© Ø§Ù„Ø¥Ù„ÙƒØªØ±ÙˆÙ†ÙŠØ©\". ÙŠÙØ±Ø¬Ù‰ ØªØ¹Ø¨Ø¦Ø© Ø§Ù„Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ø¶Ø±ÙŠØ¨ÙŠØ© Ù„ÙŠØªÙ… Ø·Ø¨Ø§Ø¹ØªÙ‡Ø§ ÙÙŠ Ø§Ù„ÙÙˆØ§ØªÙŠØ± Ø§Ù„Ø­Ø±Ø§Ø±ÙŠØ© Ù…Ø¹ Ø±Ù…Ø² QR Ù…ØªÙˆØ§ÙÙ‚ Ù…Ø¹ Ù‡ÙŠØ¦Ø© Ø§Ù„Ø²ÙƒØ§Ø© ÙˆØ§Ù„Ø¶Ø±ÙŠØ¨Ø© ÙˆØ§Ù„Ø¬Ù…Ø§Ø±Ùƒ (ZATCA) Ø¨Ø§Ù„Ù…Ù…Ù„ÙƒØ© Ø§Ù„Ø¹Ø±Ø¨ÙŠØ© Ø§Ù„Ø³Ø¹ÙˆØ¯ÙŠØ©.'**
  String get brandingZatcaDesc;

  /// No description provided for @brandingVatNumber.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø±Ù‚Ù… Ø§Ù„Ø¶Ø±ÙŠØ¨ÙŠ (VAT Number)'**
  String get brandingVatNumber;

  /// No description provided for @brandingVatHelper.
  ///
  /// In ar, this message translates to:
  /// **'ÙŠØªÙƒÙˆÙ† Ù…Ù† 15 Ø±Ù‚Ù…Ø§Ù‹ ÙˆÙŠØ¨Ø¯Ø£ ÙˆÙŠÙ†ØªÙ‡ÙŠ Ø¨Ø±Ù‚Ù… 3.'**
  String get brandingVatHelper;

  /// No description provided for @brandingCrNumber.
  ///
  /// In ar, this message translates to:
  /// **'Ø±Ù‚Ù… Ø§Ù„Ø³Ø¬Ù„ Ø§Ù„ØªØ¬Ø§Ø±ÙŠ (CR Number)'**
  String get brandingCrNumber;

  /// No description provided for @brandingCrHelper.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø®ØªÙŠØ§Ø±ÙŠØŒ ÙŠØ·Ø¨Ø¹ ÙÙŠ Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ø¥Ù† ÙˆØ¬Ø¯.'**
  String get brandingCrHelper;

  /// No description provided for @purchaseSuccess.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ø§Ù„Ø´Ø±Ø§Ø¡ Ø¨Ù†Ø¬Ø§Ø­!'**
  String get purchaseSuccess;

  /// No description provided for @purchaseError.
  ///
  /// In ar, this message translates to:
  /// **'Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ Ø§Ù„Ø´Ø±Ø§Ø¡'**
  String get purchaseError;

  /// No description provided for @restoreSuccess.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ø§Ø³ØªØ¹Ø§Ø¯Ø© Ø§Ù„Ù…Ø´ØªØ±ÙŠØ§Øª Ø¨Ù†Ø¬Ø§Ø­!'**
  String get restoreSuccess;

  /// No description provided for @restoreNoActive.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ù… ÙŠØªÙ… Ø§Ù„Ø¹Ø«ÙˆØ± Ø¹Ù„Ù‰ Ø§Ø´ØªØ±Ø§ÙƒØ§Øª ÙØ¹Ø§Ù„Ø©.'**
  String get restoreNoActive;

  /// No description provided for @restoreError.
  ///
  /// In ar, this message translates to:
  /// **'Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ Ø§Ø³ØªØ¹Ø§Ø¯Ø© Ø§Ù„Ù…Ø´ØªØ±ÙŠØ§Øª'**
  String get restoreError;

  /// No description provided for @subscriptionTitle.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø§Ø´ØªØ±Ø§Ùƒ ÙˆØ§Ù„Ø¨Ø§Ù‚Ø§Øª'**
  String get subscriptionTitle;

  /// No description provided for @premiumAccessTitle.
  ///
  /// In ar, this message translates to:
  /// **'Ø§ÙØªØ­ Ø¬Ù…ÙŠØ¹ Ø§Ù„Ù…Ù…ÙŠØ²Ø§Øª Ø§Ù„Ø§Ø­ØªØ±Ø§ÙÙŠØ©'**
  String get premiumAccessTitle;

  /// No description provided for @premiumAccessDesc.
  ///
  /// In ar, this message translates to:
  /// **'Ø£Ø¯Ø± Ù…ØªØ¬Ø±Ùƒ Ø¨ÙƒÙØ§Ø¡Ø© Ø¹Ø§Ù„ÙŠØ© Ù…Ø¹ ØªÙ‚Ø§Ø±ÙŠØ± Ù…ØªÙ‚Ø¯Ù…Ø© ÙˆØ·Ù„Ø¨Ø§Øª ØºÙŠØ± Ù…Ø­Ø¯ÙˆØ¯Ø© Ù„ØªÙ†Ù…ÙŠØ© Ù…Ø¨ÙŠØ¹Ø§ØªÙƒ.'**
  String get premiumAccessDesc;

  /// No description provided for @monthlyPlanTitle.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø§Ø´ØªØ±Ø§Ùƒ Ø§Ù„Ø´Ù‡Ø±ÙŠ'**
  String get monthlyPlanTitle;

  /// No description provided for @featureUnlimitedOrders.
  ///
  /// In ar, this message translates to:
  /// **'Ø·Ù„Ø¨Ø§Øª ÙˆÙÙˆØ§ØªÙŠØ± ØºÙŠØ± Ù…Ø­Ø¯ÙˆØ¯Ø©'**
  String get featureUnlimitedOrders;

  /// No description provided for @featureInventorySync.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¯Ø§Ø±Ø© Ù…ØªÙ‚Ø¯Ù…Ø© Ù„Ù„Ù…Ø®Ø²ÙˆÙ† ÙˆØ§Ù„Ù…Ø³ØªÙˆØ¯Ø¹'**
  String get featureInventorySync;

  /// No description provided for @featureAdvancedReports.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ‚Ø§Ø±ÙŠØ± Ù…Ø§Ù„ÙŠØ© ÙˆÙ…Ø¨ÙŠØ¹Ø§Øª Ù…ÙØµÙ„Ø©'**
  String get featureAdvancedReports;

  /// No description provided for @featurePrioritySupport.
  ///
  /// In ar, this message translates to:
  /// **'Ø¯Ø¹Ù… ÙÙ†ÙŠ Ø¹Ù„Ù‰ Ù…Ø¯Ø§Ø± Ø§Ù„Ø³Ø§Ø¹Ø©'**
  String get featurePrioritySupport;

  /// No description provided for @subscribeFor.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø´ØªØ±Ùƒ Ø§Ù„Ø¢Ù† Ø¨Ù€ {price}'**
  String subscribeFor(String price);

  /// No description provided for @noPackagesAvailable.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø¨Ø§Ù‚Ø§Øª Ù…ØªØ§Ø­Ø© Ø­Ø§Ù„ÙŠØ§Ù‹ØŒ ÙŠØ±Ø¬Ù‰ Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø© Ù„Ø§Ø­Ù‚Ø§Ù‹.'**
  String get noPackagesAvailable;

  /// No description provided for @restorePurchasesBtn.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø³ØªØ¹Ø§Ø¯Ø© Ø§Ù„Ù…Ø´ØªØ±ÙŠØ§Øª'**
  String get restorePurchasesBtn;

  /// No description provided for @subscriptionTermsDesc.
  ///
  /// In ar, this message translates to:
  /// **'ÙŠØªÙ… ØªØ¬Ø¯ÙŠØ¯ Ø§Ù„Ø§Ø´ØªØ±Ø§Ùƒ ØªÙ„Ù‚Ø§Ø¦ÙŠØ§Ù‹. ÙŠÙ…ÙƒÙ†Ùƒ Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ø§Ø´ØªØ±Ø§Ùƒ ÙÙŠ Ø£ÙŠ ÙˆÙ‚Øª Ù…Ù† Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø­Ø³Ø§Ø¨Ùƒ.'**
  String get subscriptionTermsDesc;

  /// No description provided for @confirmExit.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ£ÙƒÙŠØ¯ Ø§Ù„Ø®Ø±ÙˆØ¬'**
  String get confirmExit;

  /// No description provided for @confirmExitMessage.
  ///
  /// In ar, this message translates to:
  /// **'Ù‡Ù„ Ø£Ù†Øª Ù…ØªØ£ÙƒØ¯ Ø£Ù†Ùƒ ØªØ±ÙŠØ¯ Ø§Ù„Ø®Ø±ÙˆØ¬ Ù…Ù† Ø§Ù„ØªØ·Ø¨ÙŠÙ‚ØŸ'**
  String get confirmExitMessage;

  /// No description provided for @exit.
  ///
  /// In ar, this message translates to:
  /// **'Ø®Ø±ÙˆØ¬'**
  String get exit;

  /// No description provided for @employeePrefix.
  ///
  /// In ar, this message translates to:
  /// **'Ù…ÙˆØ¸Ù: {name}'**
  String employeePrefix(String name);

  /// No description provided for @merchantAccount.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø³Ø§Ø¨ Ø§Ù„ØªØ§Ø¬Ø± (Ø§Ù„Ø¥Ø¯Ø§Ø±Ø©)'**
  String get merchantAccount;

  /// No description provided for @rawMaterials.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…ÙˆØ§Ø¯ Ø§Ù„Ø®Ø§Ù…'**
  String get rawMaterials;

  /// No description provided for @employeesPermissionsPro.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…ÙˆØ¸ÙÙŠÙ† ÙˆØ§Ù„ØµÙ„Ø§Ø­ÙŠØ§Øª (Pro)'**
  String get employeesPermissionsPro;

  /// No description provided for @closeShiftZReport.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥ØºÙ„Ø§Ù‚ Ø§Ù„ÙˆØ±Ø¯ÙŠØ© (Z-Report)'**
  String get closeShiftZReport;

  /// No description provided for @errorFetchingInventory.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ¹Ø°Ø± Ø¬Ù„Ø¨ Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ù…Ø®Ø²ÙˆÙ†. ÙŠØ±Ø¬Ù‰ Ø§Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Ø§ØªØµØ§Ù„Ùƒ Ø¨Ø§Ù„Ø¥Ù†ØªØ±Ù†Øª.'**
  String get errorFetchingInventory;

  /// No description provided for @lowStockAlert.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ†Ø¨ÙŠÙ‡: ÙŠÙˆØ¬Ø¯ {count} Ù…Ù†ØªØ¬ ÙŠÙˆØ´Ùƒ Ø¹Ù„Ù‰ Ø§Ù„Ù†ÙØ§Ø° Ù…Ù† Ø§Ù„Ù…Ø®Ø²ÙˆÙ†!'**
  String lowStockAlert(String count);

  /// No description provided for @completeStoreBrandingAlert.
  ///
  /// In ar, this message translates to:
  /// **'âš ï¸ ÙŠØ±Ø¬Ù‰ Ø¥ÙƒÙ…Ø§Ù„ Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ù‡ÙˆÙŠØ© Ø§Ù„Ù…ØªØ¬Ø± (Ø§Ù„Ø§Ø³Ù…ØŒ Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©) Ù„Ø¶Ù…Ø§Ù† Ø·Ø¨Ø§Ø¹Ø© Ø§Ù„ÙÙˆØ§ØªÙŠØ± Ø¨Ø´ÙƒÙ„ ØµØ­ÙŠØ­ ÙˆÙ…Ø·Ø§Ø¨Ù‚ Ù„Ù„Ù…ÙˆØ§ØµÙØ§Øª.'**
  String get completeStoreBrandingAlert;

  /// No description provided for @completeNow.
  ///
  /// In ar, this message translates to:
  /// **'Ø£ÙƒÙ…Ù„ Ø§Ù„Ø¢Ù†'**
  String get completeNow;

  /// No description provided for @posCashier.
  ///
  /// In ar, this message translates to:
  /// **'ÙƒØ§Ø´ÙŠØ± (POS)'**
  String get posCashier;

  /// No description provided for @errorPrefix.
  ///
  /// In ar, this message translates to:
  /// **'Ø®Ø·Ø£: {error}'**
  String errorPrefix(String error);

  /// No description provided for @folder.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…Ø¬Ù„Ø¯'**
  String get folder;

  /// No description provided for @totalDebts.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ø¯ÙŠÙˆÙ†'**
  String get totalDebts;

  /// No description provided for @warningDeleteCustomer.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ­Ø°ÙŠØ±: Ø­Ø°Ù Ù…Ù„Ù Ø¹Ù…ÙŠÙ„'**
  String get warningDeleteCustomer;

  /// No description provided for @sortAlphabetical.
  ///
  /// In ar, this message translates to:
  /// **'Ø£Ø¨Ø¬Ø¯ÙŠ'**
  String get sortAlphabetical;

  /// No description provided for @totalCustomerDebtText.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø¯ÙŠÙ† Ø§Ù„Ø¹Ù…ÙŠÙ„: {debt}'**
  String totalCustomerDebtText(String debt);

  /// No description provided for @deleteCustomerWarningText.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø°Ù Ø§Ù„Ø¹Ù…ÙŠÙ„ Ø³ÙŠØ¤Ø¯ÙŠ Ø¥Ù„Ù‰ Ù…Ø³Ø­ Ø³Ø¬Ù„Ù‡ Ø§Ù„Ù…Ø§Ù„ÙŠ ÙˆØ¯ÙŠÙˆÙ†Ù‡ Ù…Ù† Ø§Ù„Ù†Ø¸Ø§Ù… Ù†Ù‡Ø§Ø¦ÙŠØ§Ù‹. Ù„Ø§ ÙŠÙ…ÙƒÙ† Ø§Ù„ØªØ±Ø§Ø¬Ø¹ Ø¹Ù† Ù‡Ø°Ø§ Ø§Ù„Ø¥Ø¬Ø±Ø§Ø¡.'**
  String get deleteCustomerWarningText;

  /// No description provided for @leaveEmptyToRemoveFromFolder.
  ///
  /// In ar, this message translates to:
  /// **'Ø§ØªØ±Ùƒ Ø§Ù„Ø­Ù‚Ù„ ÙØ§Ø±ØºØ§Ù‹ Ù„Ø¥Ø²Ø§Ù„Ø© Ø§Ù„Ø¹Ù…Ù„Ø§Ø¡ Ù…Ù† Ø£ÙŠ Ù…Ø¬Ù„Ø¯.'**
  String get leaveEmptyToRemoveFromFolder;

  /// No description provided for @multiSelect.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ­Ø¯ÙŠØ¯ Ù…ØªØ¹Ø¯Ø¯'**
  String get multiSelect;

  /// No description provided for @noCustomersToExport.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ø¹Ù…Ù„Ø§Ø¡ Ù„Ù„ØªØµØ¯ÙŠØ±'**
  String get noCustomersToExport;

  /// No description provided for @hasDebts.
  ///
  /// In ar, this message translates to:
  /// **'Ø¹Ù„ÙŠÙ‡Ù… Ø¯ÙŠÙˆÙ†'**
  String get hasDebts;

  /// No description provided for @totalPurchases.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ø´ØªØ±ÙŠØ§Øª'**
  String get totalPurchases;

  /// No description provided for @selectedCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} Ù…Ø­Ø¯Ø¯'**
  String selectedCount(String count);

  /// No description provided for @general.
  ///
  /// In ar, this message translates to:
  /// **'Ø¹Ø§Ù…'**
  String get general;

  /// No description provided for @whatsapp.
  ///
  /// In ar, this message translates to:
  /// **'ÙˆØ§ØªØ³Ø§Ø¨'**
  String get whatsapp;

  /// No description provided for @moveToFolder.
  ///
  /// In ar, this message translates to:
  /// **'Ù†Ù‚Ù„ Ø¥Ù„Ù‰ Ù…Ø¬Ù„Ø¯'**
  String get moveToFolder;

  /// No description provided for @dateAdded.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ§Ø±ÙŠØ® Ø§Ù„Ø¥Ø¶Ø§ÙØ©'**
  String get dateAdded;

  /// No description provided for @payDebt.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ³Ø¯ÙŠØ¯ Ø¯ÙØ¹Ø© / ØªØµÙÙŠØ© Ø¯ÙŠÙ†'**
  String get payDebt;

  /// No description provided for @customersList.
  ///
  /// In ar, this message translates to:
  /// **'Ù‚Ø§Ø¦Ù…Ø© Ø§Ù„Ø¹Ù…Ù„Ø§Ø¡'**
  String get customersList;

  /// No description provided for @searchNamePhone.
  ///
  /// In ar, this message translates to:
  /// **'Ø¨Ø­Ø« Ø¨Ø§Ù„Ø§Ø³Ù… Ø£Ùˆ Ø±Ù‚Ù… Ø§Ù„Ù‡Ø§ØªÙ'**
  String get searchNamePhone;

  /// No description provided for @customerName.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø³Ù… Ø§Ù„Ø¹Ù…ÙŠÙ„'**
  String get customerName;

  /// No description provided for @generalCustomers.
  ///
  /// In ar, this message translates to:
  /// **'Ø¹Ù…Ù„Ø§Ø¡ Ø¹Ø§Ù…ÙˆÙ†'**
  String get generalCustomers;

  /// No description provided for @sortBy.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ±ØªÙŠØ¨: '**
  String get sortBy;

  /// No description provided for @noCustomersMatch.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ø¹Ù…Ù„Ø§Ø¡ ÙŠØ·Ø§Ø¨Ù‚ÙˆÙ† Ø§Ù„Ø¨Ø­Ø«'**
  String get noCustomersMatch;

  /// No description provided for @move.
  ///
  /// In ar, this message translates to:
  /// **'Ù†Ù‚Ù„'**
  String get move;

  /// No description provided for @debtAmount.
  ///
  /// In ar, this message translates to:
  /// **'Ø¯ÙŠÙ†: {debt} {currency}'**
  String debtAmount(String debt, String currency);

  /// No description provided for @printError.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø¯Ø« Ø®Ø·Ø£ ÙÙŠ Ø§Ù„Ø·Ø¨Ø§Ø¹Ø©: {error}'**
  String printError(String error);

  /// No description provided for @phoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'Ø±Ù‚Ù… Ø§Ù„Ù‡Ø§ØªÙ'**
  String get phoneNumber;

  /// No description provided for @exportExcel.
  ///
  /// In ar, this message translates to:
  /// **'ØªØµØ¯ÙŠØ± Ù„Ø¥ÙƒØ³Ù„'**
  String get exportExcel;

  /// No description provided for @byCreator.
  ///
  /// In ar, this message translates to:
  /// **'Ø¨ÙˆØ§Ø³Ø·Ø©: {creator}'**
  String byCreator(String creator);

  /// No description provided for @exportError.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø¯Ø« Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ Ø§Ù„ØªØµØ¯ÙŠØ±: {error}'**
  String exportError(String error);

  /// No description provided for @highestDebt.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø£Ø¹Ù„Ù‰ Ø¯ÙŠÙ†Ø§Ù‹'**
  String get highestDebt;

  /// No description provided for @paidAmount.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…Ø¨Ù„Øº Ø§Ù„Ù…Ø³Ø¯Ø¯ Ù…Ù† Ø§Ù„Ø¯ÙŠÙ†'**
  String get paidAmount;

  /// No description provided for @rawMaterialsGuide.
  ///
  /// In ar, this message translates to:
  /// **'ðŸ’¡ Ø¯Ù„ÙŠÙ„ Ø§Ù„Ù…ÙˆØ§Ø¯ Ø§Ù„Ø®Ø§Ù…: Ù‡Ù†Ø§ ÙŠÙ…ÙƒÙ†Ùƒ Ø¥Ø¶Ø§ÙØ© Ù…ÙƒÙˆÙ†Ø§Øª Ù…Ø³ØªÙˆØ¯Ø¹Ùƒ (Ù…Ø«Ù„: Ù„Ø­Ù… Ø¨Ø±Ø¬Ø±ØŒ Ø¬Ø¨Ù†ØŒ Ø£ÙƒÙˆØ§Ø¨ØŒ Ø¨Ù† Ù‚Ù‡ÙˆØ©). Ø¹Ù†Ø¯ Ø±Ø¨Ø· Ù‡Ø°Ù‡ Ø§Ù„Ù…ÙƒÙˆÙ†Ø§Øª Ø¨ÙˆØµÙØ§Øª Ø§Ù„Ù…Ù†ØªØ¬Ø§Øª ÙÙŠ Ø´Ø§Ø´Ø© Ø§Ù„Ù…Ù†ØªØ¬Ø§ØªØŒ Ø³ÙŠÙ‚ÙˆÙ… Ø§Ù„Ù†Ø¸Ø§Ù… Ø¨Ø®ØµÙ… ÙƒÙ…ÙŠØ§ØªÙ‡Ø§ ØªÙ„Ù‚Ø§Ø¦ÙŠØ§Ù‹ Ø¹Ù†Ø¯ ÙƒÙ„ Ø¹Ù…Ù„ÙŠØ© Ø¨ÙŠØ¹ Ù„Ø­Ù…Ø§ÙŠØ© Ù…Ø´Ø±ÙˆØ¹Ùƒ Ù…Ù† Ø§Ù„Ù‡Ø¯Ø± ÙˆÙ…Ø¹Ø±ÙØ© Ø§Ù„ØªÙƒÙ„ÙØ© Ø§Ù„Ø­Ù‚ÙŠÙ‚ÙŠØ© Ù„Ø£Ø±Ø¨Ø§Ø­Ùƒ.'**
  String get rawMaterialsGuide;

  /// No description provided for @mlLabel.
  ///
  /// In ar, this message translates to:
  /// **'Ù…Ù„Ù„ÙŠ (ml)'**
  String get mlLabel;

  /// No description provided for @rawMaterialsUsageHint.
  ///
  /// In ar, this message translates to:
  /// **'ðŸ’¡ Ø³ØªØ³ØªØ®Ø¯Ù… Ù‡Ø°Ù‡ Ø§Ù„Ù…Ø§Ø¯Ø© Ù„Ø±Ø¨Ø·Ù‡Ø§ Ø¨ÙˆØ¬Ø¨Ø§Øª ÙˆÙ…Ù†ØªØ¬Ø§Øª Ø§Ù„Ø¨ÙŠØ¹ Ù„ÙŠØªÙ… Ø§Ù„Ø®ØµÙ… Ø§Ù„ØªÙ„Ù‚Ø§Ø¦ÙŠ Ø¹Ù†Ø¯ Ø¥ØµØ¯Ø§Ø± Ø§Ù„ÙÙˆØ§ØªÙŠØ±.'**
  String get rawMaterialsUsageHint;

  /// No description provided for @gLabel.
  ///
  /// In ar, this message translates to:
  /// **'Ø¬Ø±Ø§Ù… (g)'**
  String get gLabel;

  /// No description provided for @editRawMaterial.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ¹Ø¯ÙŠÙ„ Ù…Ø§Ø¯Ø© Ø®Ø§Ù…'**
  String get editRawMaterial;

  /// No description provided for @measuringUnit.
  ///
  /// In ar, this message translates to:
  /// **'ÙˆØ­Ø¯Ø© Ø§Ù„Ù‚ÙŠØ§Ø³:'**
  String get measuringUnit;

  /// No description provided for @noRawMaterialsFound.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ØªÙˆØ¬Ø¯ Ù…ÙˆØ§Ø¯ Ø®Ø§Ù… ÙÙŠ Ø§Ù„Ù…Ø³ØªÙˆØ¯Ø¹ Ø¨Ø¹Ø¯.\nØ§Ø¶ØºØ· Ø¹Ù„Ù‰ Ø²Ø± \"Ø¥Ø¶Ø§ÙØ© Ù…Ø§Ø¯Ø© Ø®Ø§Ù…\" Ø¨Ø§Ù„Ø£Ø³ÙÙ„ Ù„Ù„Ø¨Ø¯Ø¡!'**
  String get noRawMaterialsFound;

  /// No description provided for @availableBalance.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø±ØµÙŠØ¯ Ø§Ù„Ù…ØªÙˆÙØ±: {quantity}  ({unit})'**
  String availableBalance(String quantity, String unit);

  /// No description provided for @saveInWarehouse.
  ///
  /// In ar, this message translates to:
  /// **'Ø­ÙØ¸ ÙÙŠ Ø§Ù„Ù…Ø³ØªÙˆØ¯Ø¹'**
  String get saveInWarehouse;

  /// No description provided for @addRawMaterial.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¶Ø§ÙØ© Ù…Ø§Ø¯Ø© Ø®Ø§Ù…'**
  String get addRawMaterial;

  /// No description provided for @addNewRawMaterial.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¶Ø§ÙØ© Ù…Ø§Ø¯Ø© Ø®Ø§Ù… Ø¬Ø¯ÙŠØ¯Ø©'**
  String get addNewRawMaterial;

  /// No description provided for @pieceUnit.
  ///
  /// In ar, this message translates to:
  /// **'Ù‚Ø·Ø¹Ø© / Ø­Ø¨Ø©'**
  String get pieceUnit;

  /// No description provided for @pieceUnitDesc.
  ///
  /// In ar, this message translates to:
  /// **'Ù‚Ø·Ø¹Ø© / Ø­Ø¨Ø© (piece) - Ù„Ù„Ø£ÙƒÙˆØ§Ø¨ ÙˆØ§Ù„Ø®Ø¨Ø² ÙˆØ§Ù„Ø¹Ø¨ÙˆØ§Øª'**
  String get pieceUnitDesc;

  /// No description provided for @pleaseEnterRawMaterialName.
  ///
  /// In ar, this message translates to:
  /// **'ÙŠØ±Ø¬Ù‰ Ø¥Ø¯Ø®Ø§Ù„ Ø§Ø³Ù… Ø§Ù„Ù…Ø§Ø¯Ø© Ø§Ù„Ø®Ø§Ù… Ø£ÙˆÙ„Ø§Ù‹'**
  String get pleaseEnterRawMaterialName;

  /// No description provided for @currentAvailableQuantity.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„ÙƒÙ…ÙŠØ© Ø§Ù„Ù…ØªÙˆÙØ±Ø© Ø­Ø§Ù„ÙŠØ§Ù‹ ÙÙŠ Ø§Ù„Ù…Ø³ØªÙˆØ¯Ø¹'**
  String get currentAvailableQuantity;

  /// No description provided for @gUnitDesc.
  ///
  /// In ar, this message translates to:
  /// **'Ø¬Ø±Ø§Ù… (g) - Ù„Ù„ÙˆØ²Ù† Ù…Ø«Ù„ Ø§Ù„Ù„Ø­ÙˆÙ… ÙˆØ§Ù„Ù‚Ù‡ÙˆØ©'**
  String get gUnitDesc;

  /// No description provided for @mlUnitDesc.
  ///
  /// In ar, this message translates to:
  /// **'Ù…Ù„Ù„ÙŠ (ml) - Ù„Ù„Ø³ÙˆØ§Ø¦Ù„ ÙˆØ§Ù„ØµÙ„ØµØ§Øª'**
  String get mlUnitDesc;

  /// No description provided for @resourceRunningOut.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ†Ø¨ÙŠÙ‡: Ø§Ù„Ù…ÙˆØ±Ø¯ Ù‚Ø§Ø±Ø¨ Ø¹Ù„Ù‰ Ø§Ù„Ø§Ù†ØªÙ‡Ø§Ø¡'**
  String get resourceRunningOut;

  /// No description provided for @rawMaterialNameExample.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø³Ù… Ø§Ù„Ù…Ø§Ø¯Ø© Ø§Ù„Ø®Ø§Ù… (Ù…Ø«Ø§Ù„: Ù„Ø­Ù… Ø¨Ø±Ø¬Ø±ØŒ Ø¬Ø¨Ù†ØŒ Ù‚Ù‡ÙˆØ© Ø¨Ù†)'**
  String get rawMaterialNameExample;

  /// No description provided for @rawMaterialsWarehouse.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…ÙˆØ§Ø¯ Ø§Ù„Ø®Ø§Ù… (Ù…Ø³ØªÙˆØ¯Ø¹ Ø§Ù„Ù…ÙƒÙˆÙ†Ø§Øª)'**
  String get rawMaterialsWarehouse;

  /// No description provided for @orderNumberLabel.
  ///
  /// In ar, this message translates to:
  /// **'Ø·Ù„Ø¨ #{number}'**
  String orderNumberLabel(String number);

  /// No description provided for @thisWeekFromTo.
  ///
  /// In ar, this message translates to:
  /// **'Ù‡Ø°Ø§ Ø§Ù„Ø£Ø³Ø¨ÙˆØ¹ (Ù…Ù† {start} Ø¥Ù„Ù‰ {end})'**
  String thisWeekFromTo(String start, String end);

  /// No description provided for @thermalPrint.
  ///
  /// In ar, this message translates to:
  /// **'Ø·Ø¨Ø§Ø¹Ø© Ø­Ø±Ø§Ø±ÙŠØ©'**
  String get thermalPrint;

  /// No description provided for @invoicePermanentlyDeleted.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ø­Ø°Ù Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ø±Ù‚Ù… #{number} Ù†Ù‡Ø§Ø¦ÙŠØ§Ù‹ Ù…Ù† Ù‚Ø¨Ù„ {user}'**
  String invoicePermanentlyDeleted(String number, String user);

  /// No description provided for @scheduledOrders.
  ///
  /// In ar, this message translates to:
  /// **'Ø·Ù„Ø¨Ø§Øª Ù…Ø¬Ø¯ÙˆÙ„Ø© ðŸ—“'**
  String get scheduledOrders;

  /// No description provided for @totalIncome.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ø¯Ø®Ù„: '**
  String get totalIncome;

  /// No description provided for @monthPrefix.
  ///
  /// In ar, this message translates to:
  /// **'Ø´Ù‡Ø± '**
  String get monthPrefix;

  /// No description provided for @deleteInvoice.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø°Ù Ø§Ù„ÙØ§ØªÙˆØ±Ø©'**
  String get deleteInvoice;

  /// No description provided for @confirmDeleteInvoiceMsg.
  ///
  /// In ar, this message translates to:
  /// **'Ù‡Ù„ Ø£Ù†Øª Ù…ØªØ£ÙƒØ¯ Ù…Ù† Ù…Ø³Ø­ Ù‡Ø°Ù‡ Ø§Ù„ÙØ§ØªÙˆØ±Ø©ØŸ (Ø³ÙŠØ¹ÙˆØ¯ Ø§Ù„Ù…Ø®Ø²ÙˆÙ† Ù„Ù„Ù…Ù†ØªØ¬Ø§Øª)'**
  String get confirmDeleteInvoiceMsg;

  /// No description provided for @bankTransferMethod.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ­ÙˆÙŠÙ„ Ø¨Ù†ÙƒÙŠ ðŸ¦'**
  String get bankTransferMethod;

  /// No description provided for @cashMethod.
  ///
  /// In ar, this message translates to:
  /// **'Ø¯ÙØ¹ ÙƒØ§Ø´ ðŸ’µ'**
  String get cashMethod;

  /// No description provided for @agoPrefix.
  ///
  /// In ar, this message translates to:
  /// **'Ù‚Ø¨Ù„ '**
  String get agoPrefix;

  /// No description provided for @deleteBtn.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø°Ù'**
  String get deleteBtn;

  /// No description provided for @madaMethod.
  ///
  /// In ar, this message translates to:
  /// **'Ø¯ÙØ¹ Ù…Ø¯Ù‰ ðŸ’³'**
  String get madaMethod;

  /// No description provided for @warningFinalDelete.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ­Ø°ÙŠØ±: Ø­Ø°Ù Ù†Ù‡Ø§Ø¦ÙŠ Ù„Ù„Ø·Ù„Ø¨'**
  String get warningFinalDelete;

  /// No description provided for @hideBtn.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø®ÙØ§Ø¡'**
  String get hideBtn;

  /// No description provided for @weekFromTo.
  ///
  /// In ar, this message translates to:
  /// **' Ø£Ø³Ø¨ÙˆØ¹ (Ù…Ù† {start} Ø¥Ù„Ù‰ {end})'**
  String weekFromTo(String start, String end);

  /// No description provided for @pdfInvoice.
  ///
  /// In ar, this message translates to:
  /// **'ÙØ§ØªÙˆØ±Ø© PDF'**
  String get pdfInvoice;

  /// No description provided for @finalDeleteWarningMsg.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø­Ø°Ù Ø§Ù„Ù†Ù‡Ø§Ø¦ÙŠ Ø³ÙŠÙ…Ø­Ùˆ Ù‡Ø°Ø§ Ø§Ù„Ø·Ù„Ø¨ Ù…Ù† Ø§Ù„Ø³Ø¬Ù„Ø§Øª ØªÙ…Ø§Ù…Ø§Ù‹ Ø¨Ø§Ù„Ø¥Ø¶Ø§ÙØ© Ø¥Ù„Ù‰ Ø¥Ø±Ø¬Ø§Ø¹ Ø§Ù„Ø£Ù…ÙˆØ§Ù„ ÙˆØ¹ÙƒØ³ Ø§Ù„Ø¯ÙŠÙˆÙ†. Ù„Ø§ ÙŠÙ…ÙƒÙ† Ø§Ø³ØªØ¹Ø§Ø¯Ø© Ø§Ù„ÙØ§ØªÙˆØ±Ø©. Ù‡Ù„ Ø£Ù†Øª Ù…ØªØ£ÙƒØ¯ØŸ'**
  String get finalDeleteWarningMsg;

  /// No description provided for @failDeleteInvoiceNoPermission.
  ///
  /// In ar, this message translates to:
  /// **'ÙØ´Ù„ Ù…Ø³Ø­ Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ù†Ù‡Ø§Ø¦ÙŠØ§Ù‹ Ù„Ø¹Ø¯Ù… ÙˆØ¬ÙˆØ¯ ØµÙ„Ø§Ø­ÙŠØ© Ø£Ùˆ Ù„Ø§ ØªÙˆØ¬Ø¯ ÙØ§ØªÙˆØ±Ø©.'**
  String get failDeleteInvoiceNoPermission;

  /// No description provided for @todayPrefix.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„ÙŠÙˆÙ… - '**
  String get todayPrefix;

  /// No description provided for @posTitle.
  ///
  /// In ar, this message translates to:
  /// **'Ù†Ù‚Ø·Ø© Ø§Ù„Ø¨ÙŠØ¹ (POS)'**
  String get posTitle;

  /// No description provided for @byCreatorIcon.
  ///
  /// In ar, this message translates to:
  /// **'ðŸ‘¤ Ø¨ÙˆØ§Ø³Ø·Ø©: {creator}'**
  String byCreatorIcon(String creator);

  /// No description provided for @deleteInvoiceAction.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø°Ù ÙØ§ØªÙˆØ±Ø©'**
  String get deleteInvoiceAction;

  /// No description provided for @invoiceDeletedSuccessfully.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ø­Ø°Ù Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ø¨Ù†Ø¬Ø§Ø­'**
  String get invoiceDeletedSuccessfully;

  /// No description provided for @yearPrefix.
  ///
  /// In ar, this message translates to:
  /// **'Ø³Ù†Ø© '**
  String get yearPrefix;

  /// No description provided for @deliveryDate.
  ///
  /// In ar, this message translates to:
  /// **'Ù…ÙˆØ¹Ø¯ Ø§Ù„ØªØ³Ù„ÙŠÙ…: '**
  String get deliveryDate;

  /// No description provided for @yesterdayPrefix.
  ///
  /// In ar, this message translates to:
  /// **'Ø£Ù…Ø³ - '**
  String get yesterdayPrefix;

  /// No description provided for @paymentMethod.
  ///
  /// In ar, this message translates to:
  /// **' (Ø§Ù„Ø¯ÙØ¹: '**
  String get paymentMethod;

  /// No description provided for @invoiceCancelledMsg.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ø¥Ù„ØºØ§Ø¡ Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ø±Ù‚Ù… #{number} Ø¨Ù‚ÙŠÙ…Ø© {value}'**
  String invoiceCancelledMsg(String number, String value);

  /// No description provided for @confirmFinalDeleteMsg.
  ///
  /// In ar, this message translates to:
  /// **'Ù‡Ù„ Ø£Ù†Øª Ù…ØªØ£ÙƒØ¯ Ù…Ù† Ø±ØºØ¨ØªÙƒ ÙÙŠ Ù…Ø³Ø­ Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ù†Ù‡Ø§Ø¦ÙŠØ§Ù‹ØŸ Ù„Ø§ ÙŠÙ…ÙƒÙ† Ø§Ù„ØªØ±Ø§Ø¬Ø¹ Ø¹Ù† Ù‡Ø°Ù‡ Ø§Ù„Ø®Ø·ÙˆØ©.'**
  String get confirmFinalDeleteMsg;

  /// No description provided for @errorOccurred.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø¯Ø« Ø®Ø·Ø£: {error}'**
  String errorOccurred(String error);

  /// No description provided for @invoiceDeletedPermanently.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ø­Ø°Ù Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ù†Ù‡Ø§Ø¦ÙŠØ§Ù‹'**
  String get invoiceDeletedPermanently;

  /// No description provided for @cancelOrder.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ø·Ù„Ø¨'**
  String get cancelOrder;

  /// No description provided for @orderDetailsTitle.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙØ§ØµÙŠÙ„ Ø§Ù„Ø·Ù„Ø¨ #{number}'**
  String orderDetailsTitle(String number);

  /// No description provided for @orderConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'âœ… Ø·Ù„Ø¨ Ù…Ø¤ÙƒØ¯ / Ù…ÙƒØªÙ…Ù„'**
  String get orderConfirmed;

  /// No description provided for @invoiceOptions.
  ///
  /// In ar, this message translates to:
  /// **'âš™ï¸ Ø®ÙŠØ§Ø±Ø§Øª Ø§Ù„ÙØ§ØªÙˆØ±Ø©'**
  String get invoiceOptions;

  /// No description provided for @creditMethod.
  ///
  /// In ar, this message translates to:
  /// **'Ø¢Ø¬Ù„ / Ø°Ù…Ù… (Credit)'**
  String get creditMethod;

  /// No description provided for @warningCancelOrder.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ­Ø°ÙŠØ±: Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ø·Ù„Ø¨'**
  String get warningCancelOrder;

  /// No description provided for @confirmFinalDelete.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ£ÙƒÙŠØ¯ Ø§Ù„Ø­Ø°Ù Ø§Ù„Ù†Ù‡Ø§Ø¦ÙŠ'**
  String get confirmFinalDelete;

  /// No description provided for @subtotalBeforeTax.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ (Ù‚Ø¨Ù„ Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©)'**
  String get subtotalBeforeTax;

  /// No description provided for @cancelOrderWarningMsg.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ø·Ù„Ø¨ Ø³ÙŠØ¤Ø¯ÙŠ Ø¥Ù„Ù‰ Ø¥Ø±Ø¬Ø§Ø¹ Ø§Ù„Ù…Ù†ØªØ¬Ø§Øª Ù„Ù„Ù…Ø®Ø²ÙˆÙ†ØŒ ÙˆØ®ØµÙ… Ø§Ù„Ø£Ù…ÙˆØ§Ù„ Ø§Ù„Ù…Ø¯ÙÙˆØ¹Ø© Ù…Ù† Ø§Ù„ÙˆØ±Ø¯ÙŠØ© Ø§Ù„Ø­Ø§Ù„ÙŠØ©ØŒ ÙˆØ¹ÙƒØ³ Ø¯ÙŠÙˆÙ† Ø§Ù„Ø¹Ù…ÙŠÙ„. Ù‡Ù„ Ø£Ù†Øª Ù…ØªØ£ÙƒØ¯ØŸ'**
  String get cancelOrderWarningMsg;

  /// No description provided for @unitPricePrefix.
  ///
  /// In ar, this message translates to:
  /// **'Ø³Ø¹Ø± Ø§Ù„ÙˆØ­Ø¯Ø©: '**
  String get unitPricePrefix;

  /// No description provided for @finalDeleteBtn.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø°Ù Ù†Ù‡Ø§Ø¦ÙŠ'**
  String get finalDeleteBtn;

  /// No description provided for @itemsList.
  ///
  /// In ar, this message translates to:
  /// **'ðŸ›ï¸ Ù‚Ø§Ø¦Ù…Ø© Ø§Ù„Ø£ØµÙ†Ø§Ù ÙˆØ§Ù„Ù…Ù†ØªØ¬Ø§Øª'**
  String get itemsList;

  /// No description provided for @confirmCancelInvoiceMsg.
  ///
  /// In ar, this message translates to:
  /// **'Ù‡Ù„ Ø£Ù†Øª Ù…ØªØ£ÙƒØ¯ Ù…Ù† Ø±ØºØ¨ØªÙƒ ÙÙŠ Ø¥Ù„ØºØ§Ø¡ Ù‡Ø°Ù‡ Ø§Ù„ÙØ§ØªÙˆØ±Ø©ØŸ Ø³ÙŠØªÙ… Ø¥Ø±Ø¬Ø§Ø¹ ÙƒÙ…ÙŠØ§Øª Ø§Ù„Ø£ØµÙ†Ø§Ù Ù„Ù„Ù…Ø®Ø²ÙˆÙ† ØªÙ„Ù‚Ø§Ø¦ÙŠØ§Ù‹.'**
  String get confirmCancelInvoiceMsg;

  /// No description provided for @orderCancelledStatus.
  ///
  /// In ar, this message translates to:
  /// **'âŒ Ø·Ù„Ø¨ Ù…Ù„ØºÙŠ'**
  String get orderCancelledStatus;

  /// No description provided for @cancelInvoiceBtn.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ù„ØºØ§Ø¡ ÙØ§ØªÙˆØ±Ø©'**
  String get cancelInvoiceBtn;

  /// No description provided for @invoiceGrandTotal.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ù…Ø¬Ù…ÙˆØ¹ Ø§Ù„Ù†Ù‡Ø§Ø¦ÙŠ Ù„Ù„ÙØ§ØªÙˆØ±Ø©'**
  String get invoiceGrandTotal;

  /// No description provided for @invoiceCancelledSuccessfully.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙ… Ø¥Ù„ØºØ§Ø¡ Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ø¨Ù†Ø¬Ø§Ø­ ÙˆØ¥Ø±Ø¬Ø§Ø¹ Ø§Ù„Ù…ÙˆØ§Ø¯ Ù„Ù„Ù…Ø®Ø²ÙˆÙ†'**
  String get invoiceCancelledSuccessfully;

  /// No description provided for @totalTax.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©'**
  String get totalTax;

  /// No description provided for @confirmCancelBtn.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ£ÙƒÙŠØ¯ Ø§Ù„Ø¥Ù„ØºØ§Ø¡'**
  String get confirmCancelBtn;

  /// No description provided for @goBackBtn.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ±Ø§Ø¬Ø¹'**
  String get goBackBtn;

  /// No description provided for @yesterday.
  ///
  /// In ar, this message translates to:
  /// **'Ø£Ù…Ø³'**
  String get yesterday;

  /// No description provided for @expensesDistribution.
  ///
  /// In ar, this message translates to:
  /// **'ØªÙˆØ²ÙŠØ¹ Ø§Ù„Ù…ØµØ±ÙˆÙØ§Øª'**
  String get expensesDistribution;

  /// No description provided for @preparingExcelReport.
  ///
  /// In ar, this message translates to:
  /// **'Ø¬Ø§Ø±ÙŠ ØªØ¬Ù‡ÙŠØ² Ø§Ù„ØªÙ‚Ø±ÙŠØ± (Ø¥ÙƒØ³Ù„)...'**
  String get preparingExcelReport;

  /// No description provided for @unitsSold.
  ///
  /// In ar, this message translates to:
  /// **'{quantity} ÙˆØ­Ø¯Ø© Ù…Ø¨Ø§Ø¹Ø©'**
  String unitsSold(String quantity);

  /// No description provided for @oneWeek.
  ///
  /// In ar, this message translates to:
  /// **'Ø£Ø³Ø¨ÙˆØ¹'**
  String get oneWeek;

  /// No description provided for @excelExportError.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø¯Ø« Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ ØªØµØ¯ÙŠØ± Ø¥ÙƒØ³Ù„: {error}'**
  String excelExportError(String error);

  /// No description provided for @reportExtractionError.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø¯Ø« Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ Ø§Ø³ØªØ®Ø±Ø§Ø¬ Ø§Ù„ØªÙ‚Ø±ÙŠØ±'**
  String get reportExtractionError;

  /// No description provided for @oneMonth.
  ///
  /// In ar, this message translates to:
  /// **'Ø´Ù‡Ø±'**
  String get oneMonth;

  /// No description provided for @semiAnnual.
  ///
  /// In ar, this message translates to:
  /// **'Ù†ØµÙ Ø³Ù†ÙˆÙŠ'**
  String get semiAnnual;

  /// No description provided for @oneYear.
  ///
  /// In ar, this message translates to:
  /// **'Ø³Ù†Ø©'**
  String get oneYear;

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„ÙŠÙˆÙ…'**
  String get today;

  /// No description provided for @preparingPdfReport.
  ///
  /// In ar, this message translates to:
  /// **'Ø¬Ø§Ø±ÙŠ ØªØ¬Ù‡ÙŠØ² Ø§Ù„ØªÙ‚Ø±ÙŠØ± (PDF)...'**
  String get preparingPdfReport;

  /// No description provided for @twoDaysAgo.
  ///
  /// In ar, this message translates to:
  /// **'Ù‚Ø¨Ù„ ÙŠÙˆÙ…ÙŠÙ†'**
  String get twoDaysAgo;

  /// No description provided for @noExpensesInPeriod.
  ///
  /// In ar, this message translates to:
  /// **'Ù„Ø§ ØªÙˆØ¬Ø¯ Ù…ØµØ±ÙˆÙØ§Øª ÙÙŠ Ù‡Ø°Ù‡ Ø§Ù„ÙØªØ±Ø©'**
  String get noExpensesInPeriod;

  /// No description provided for @cash.
  ///
  /// In ar, this message translates to:
  /// **'cash'**
  String get cash;

  /// No description provided for @card.
  ///
  /// In ar, this message translates to:
  /// **'card'**
  String get card;

  /// No description provided for @transfer.
  ///
  /// In ar, this message translates to:
  /// **'transfer'**
  String get transfer;

  /// No description provided for @unknown.
  ///
  /// In ar, this message translates to:
  /// **'unknown'**
  String get unknown;

  /// No description provided for @aboutApp.
  ///
  /// In ar, this message translates to:
  /// **'Ø­ÙˆÙ„ Ø§Ù„ØªØ·Ø¨ÙŠÙ‚'**
  String get aboutApp;

  /// No description provided for @databaseBackupText.
  ///
  /// In ar, this message translates to:
  /// **'Ù†Ø³Ø® Ø§Ø­ØªÙŠØ§Ø·ÙŠ Ù„Ù‚Ø§Ø¹Ø¯Ø© Ø§Ù„Ø¨ÙŠØ§Ù†Ø§Øª'**
  String get databaseBackupText;

  /// No description provided for @thermalPrinterText.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø·Ø§Ø¨Ø¹Ø© Ø§Ù„Ø­Ø±Ø§Ø±ÙŠØ©'**
  String get thermalPrinterText;

  /// No description provided for @setupChecklistTitle.
  ///
  /// In ar, this message translates to:
  /// **'Ø¬Ù‡Ø² Ù…ØªØ¬Ø±Ùƒ Ù„Ù„Ø¨ÙŠØ¹'**
  String get setupChecklistTitle;

  /// No description provided for @setupStep1.
  ///
  /// In ar, this message translates to:
  /// **'Ø£Ø³Ø³ Ù…ØªØ¬Ø±Ùƒ (Ø£Ø¶Ù ØªØµÙ†ÙŠÙ)'**
  String get setupStep1;

  /// No description provided for @setupStep2.
  ///
  /// In ar, this message translates to:
  /// **'ØªØ¬Ù‡ÙŠØ² Ø§Ù„Ø±ÙÙˆÙ (Ø£Ø¶Ù Ù…Ù†ØªØ¬)'**
  String get setupStep2;

  /// No description provided for @setupStep3.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø³ØªÙ„Ø§Ù… Ø§Ù„Ø¹Ù‡Ø¯Ø© (Ø§ÙØªØ­ ÙˆØ±Ø¯ÙŠØ©)'**
  String get setupStep3;

  /// No description provided for @setupStep4.
  ///
  /// In ar, this message translates to:
  /// **'Ø£ÙˆÙ„ ØºÙŠØ« (Ø£Ù†Ø´Ø¦ Ù…Ø¨ÙŠØ¹Ø©)'**
  String get setupStep4;

  /// No description provided for @setupCompleted.
  ///
  /// In ar, this message translates to:
  /// **'Ø£Ù†Øª Ø¬Ø§Ù‡Ø² ØªÙ…Ø§Ù…Ø§Ù‹ Ù„Ù„Ø¨ÙŠØ¹! ðŸŽ‰'**
  String get setupCompleted;

  /// No description provided for @taxModeTitle.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©'**
  String get taxModeTitle;

  /// No description provided for @taxModeStore.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ø³ØªØ®Ø¯Ø§Ù… Ø¶Ø±ÙŠØ¨Ø© Ø§Ù„Ù…ØªØ¬Ø±'**
  String get taxModeStore;

  /// No description provided for @taxModeCustom.
  ///
  /// In ar, this message translates to:
  /// **'Ø¶Ø±ÙŠØ¨Ø© Ù…Ø®ØµØµØ©'**
  String get taxModeCustom;

  /// No description provided for @taxModeExempt.
  ///
  /// In ar, this message translates to:
  /// **'Ù…Ø¹ÙÙ‰ Ù…Ù† Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©'**
  String get taxModeExempt;

  /// No description provided for @paywallMainPlan.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø¨Ø§Ù‚Ø© Ø§Ù„Ø±Ø¦ÙŠØ³ÙŠØ©'**
  String get paywallMainPlan;

  /// No description provided for @paywallMainDesc1.
  ///
  /// In ar, this message translates to:
  /// **'ÙØ±Ø¹ Ø±Ø¦ÙŠØ³ÙŠ ÙƒØ§Ù…Ù„'**
  String get paywallMainDesc1;

  /// No description provided for @paywallMainDesc2.
  ///
  /// In ar, this message translates to:
  /// **'ØµÙ„Ø§Ø­ÙŠØ§Øª ØªØ§Ø¬Ø± ÙƒØ§Ù…Ù„Ø© Ù„Ù„ÙØ±Ø¹ Ø§Ù„Ø±Ø¦ÙŠØ³ÙŠ'**
  String get paywallMainDesc2;

  /// No description provided for @paywallMainDesc3.
  ///
  /// In ar, this message translates to:
  /// **'Ø­ØªÙ‰ 3 Ù…ÙˆØ¸ÙÙŠÙ† ÙÙŠ Ø§Ù„ÙØ±Ø¹ Ø§Ù„Ø±Ø¦ÙŠØ³ÙŠ'**
  String get paywallMainDesc3;

  /// No description provided for @paywallMainDesc4.
  ///
  /// In ar, this message translates to:
  /// **'Ø¥Ù…ÙƒØ§Ù†ÙŠØ© Ø¥Ø¶Ø§ÙØ© ÙØ±ÙˆØ¹ ØªØ¬Ø±ÙŠØ¨ÙŠØ©'**
  String get paywallMainDesc4;

  /// No description provided for @paywallMainDesc5.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„ÙØ±ÙˆØ¹ Ø§Ù„ØªØ¬Ø±ÙŠØ¨ÙŠØ© ØªØ¨Ù‚Ù‰ Ù…Ø­Ø¯ÙˆØ¯Ø©'**
  String get paywallMainDesc5;

  /// No description provided for @paywallMultiPlan.
  ///
  /// In ar, this message translates to:
  /// **'Ø¨Ø§Ù‚Ø© Ù…ØªØ¹Ø¯Ø¯ Ø§Ù„ÙØ±ÙˆØ¹'**
  String get paywallMultiPlan;

  /// No description provided for @paywallMultiDesc1.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø±Ø¦ÙŠØ³ÙŠ + 3 ÙØ±ÙˆØ¹ Ø¥Ù†ØªØ§Ø¬ÙŠØ© Ø¥Ø¶Ø§ÙÙŠØ©'**
  String get paywallMultiDesc1;

  /// No description provided for @paywallMultiDesc2.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø¯ Ø£Ù‚ØµÙ‰ 4 ÙØ±ÙˆØ¹ ÙƒØ§Ù…Ù„Ø©'**
  String get paywallMultiDesc2;

  /// No description provided for @paywallMultiDesc3.
  ///
  /// In ar, this message translates to:
  /// **'Ù…ÙˆØ¸ÙÙŠ Ø§Ù„Ø±Ø¦ÙŠØ³ÙŠ = 3ØŒ Ø§Ù„Ø¥Ø¶Ø§ÙÙŠ = 2 Ù„ÙƒÙ„ ÙØ±Ø¹'**
  String get paywallMultiDesc3;

  /// No description provided for @paywallMultiDesc4.
  ///
  /// In ar, this message translates to:
  /// **'Ø­Ø¯ Ø£Ù‚ØµÙ‰ 9 Ù…ÙˆØ¸ÙÙŠÙ† Ø¥Ø¬Ù…Ø§Ù„Ø§Ù‹'**
  String get paywallMultiDesc4;

  /// No description provided for @paywallMultiDesc5.
  ///
  /// In ar, this message translates to:
  /// **'ØµÙ„Ø§Ø­ÙŠØ§Øª Ø§Ù„ÙØ±ÙˆØ¹ Ø§Ù„Ù…ØªØ¹Ø¯Ø¯Ø© ÙƒØ§Ù…Ù„Ø©'**
  String get paywallMultiDesc5;

  /// No description provided for @paywallMultiDesc6.
  ///
  /// In ar, this message translates to:
  /// **'Ø­ÙØ¸ Ø¥Ù…ÙƒØ§Ù†ÙŠØ§Øª Ù†Ù‚Ù„ Ø§Ù„Ù…Ø®Ø²ÙˆÙ† Ø§Ù„Ø­Ø§Ù„ÙŠØ©'**
  String get paywallMultiDesc6;

  /// No description provided for @pricePendingStore.
  ///
  /// In ar, this message translates to:
  /// **'Ø§Ù„Ø³Ø¹Ø± Ù…ØªØ§Ø­ Ø¨Ø¹Ø¯ Ø§Ù„Ø§ØªØµØ§Ù„ Ø¨Ø§Ù„Ù…ØªØ¬Ø±'**
  String get pricePendingStore;

  /// No description provided for @freeLimitReachedTitle.
  ///
  /// In ar, this message translates to:
  /// **'اكتملت تجربتك المجانية'**
  String get freeLimitReachedTitle;

  /// No description provided for @freeLimitReachedMessage.
  ///
  /// In ar, this message translates to:
  /// **'لقد وصلت للحد الأقصى من الطلبات المسموح بها في الباقة المجانية.'**
  String get freeLimitReachedMessage;

  /// No description provided for @later.
  ///
  /// In ar, this message translates to:
  /// **'لاحقاً'**
  String get later;

  /// No description provided for @viewPlans.
  ///
  /// In ar, this message translates to:
  /// **'عرض الباقات'**
  String get viewPlans;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
