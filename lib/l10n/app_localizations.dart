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
  /// **'تاجر'**
  String get appTitle;

  /// No description provided for @loginTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginTitle;

  /// No description provided for @products.
  ///
  /// In ar, this message translates to:
  /// **'المنتجات'**
  String get products;

  /// No description provided for @customers.
  ///
  /// In ar, this message translates to:
  /// **'العملاء'**
  String get customers;

  /// No description provided for @orders.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات'**
  String get orders;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @dashboard.
  ///
  /// In ar, this message translates to:
  /// **'لوحة التحكم'**
  String get dashboard;

  /// No description provided for @adminPanel.
  ///
  /// In ar, this message translates to:
  /// **'لوحة الإدارة العليا'**
  String get adminPanel;

  /// No description provided for @expenses.
  ///
  /// In ar, this message translates to:
  /// **'المصروفات'**
  String get expenses;

  /// No description provided for @suppliers.
  ///
  /// In ar, this message translates to:
  /// **'الموردين'**
  String get suppliers;

  /// No description provided for @categories.
  ///
  /// In ar, this message translates to:
  /// **'التصنيفات'**
  String get categories;

  /// No description provided for @inventoryLog.
  ///
  /// In ar, this message translates to:
  /// **'سجل المخزون'**
  String get inventoryLog;

  /// No description provided for @reports.
  ///
  /// In ar, this message translates to:
  /// **'التقارير'**
  String get reports;

  /// No description provided for @totalSales.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المبيعات'**
  String get totalSales;

  /// No description provided for @ordersCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد الطلبات'**
  String get ordersCount;

  /// No description provided for @quickActions.
  ///
  /// In ar, this message translates to:
  /// **'أوامر سريعة'**
  String get quickActions;

  /// No description provided for @managementAndInventory.
  ///
  /// In ar, this message translates to:
  /// **'الإدارة والمخزون'**
  String get managementAndInventory;

  /// No description provided for @add.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @update.
  ///
  /// In ar, this message translates to:
  /// **'تحديث'**
  String get update;

  /// No description provided for @name.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get name;

  /// No description provided for @price.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get price;

  /// No description provided for @quantity.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get quantity;

  /// No description provided for @barcode.
  ///
  /// In ar, this message translates to:
  /// **'الباركود'**
  String get barcode;

  /// No description provided for @category.
  ///
  /// In ar, this message translates to:
  /// **'التصنيف'**
  String get category;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phone;

  /// No description provided for @email.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get email;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @notes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get notes;

  /// No description provided for @date.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get date;

  /// No description provided for @scanBarcode.
  ///
  /// In ar, this message translates to:
  /// **'مسح الباركود'**
  String get scanBarcode;

  /// No description provided for @searchByBarcode.
  ///
  /// In ar, this message translates to:
  /// **'بحث بالباركود'**
  String get searchByBarcode;

  /// No description provided for @productName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المنتج'**
  String get productName;

  /// No description provided for @availableQuantity.
  ///
  /// In ar, this message translates to:
  /// **'الكمية المتاحة'**
  String get availableQuantity;

  /// No description provided for @noCategory.
  ///
  /// In ar, this message translates to:
  /// **'بدون تصنيف'**
  String get noCategory;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @upgradeAccount.
  ///
  /// In ar, this message translates to:
  /// **'ترقية الحساب (ربط بـ Google)'**
  String get upgradeAccount;

  /// No description provided for @subscriptions.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراكات والباقات'**
  String get subscriptions;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'لغة التطبيق'**
  String get language;

  /// No description provided for @currency.
  ///
  /// In ar, this message translates to:
  /// **'العملة الأساسية'**
  String get currency;

  /// No description provided for @theme.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In ar, this message translates to:
  /// **'تلقائي'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ar, this message translates to:
  /// **'داكن'**
  String get themeDark;

  /// No description provided for @error.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ'**
  String get error;

  /// No description provided for @success.
  ///
  /// In ar, this message translates to:
  /// **'تم بنجاح'**
  String get success;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحميل...'**
  String get loading;

  /// No description provided for @requiredField.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب'**
  String get requiredField;

  /// No description provided for @currency_SAR.
  ///
  /// In ar, this message translates to:
  /// **'ريال سعودي'**
  String get currency_SAR;

  /// No description provided for @currency_USD.
  ///
  /// In ar, this message translates to:
  /// **'دولار أمريكي'**
  String get currency_USD;

  /// No description provided for @currency_YER.
  ///
  /// In ar, this message translates to:
  /// **'ريال يمني'**
  String get currency_YER;

  /// No description provided for @currency_AED.
  ///
  /// In ar, this message translates to:
  /// **'درهم إماراتي'**
  String get currency_AED;

  /// No description provided for @currency_JOD.
  ///
  /// In ar, this message translates to:
  /// **'دينار أردني'**
  String get currency_JOD;

  /// No description provided for @currency_IQD.
  ///
  /// In ar, this message translates to:
  /// **'دينار عراقي'**
  String get currency_IQD;

  /// No description provided for @currency_SYP.
  ///
  /// In ar, this message translates to:
  /// **'ليرة سورية'**
  String get currency_SYP;

  /// No description provided for @currency_LBP.
  ///
  /// In ar, this message translates to:
  /// **'ليرة لبنانية'**
  String get currency_LBP;

  /// No description provided for @currency_KWD.
  ///
  /// In ar, this message translates to:
  /// **'دينار كويتي'**
  String get currency_KWD;

  /// No description provided for @currency_EGP.
  ///
  /// In ar, this message translates to:
  /// **'جنيه مصري'**
  String get currency_EGP;

  /// No description provided for @currency_DZD.
  ///
  /// In ar, this message translates to:
  /// **'دينار جزائري'**
  String get currency_DZD;

  /// No description provided for @currency_LYD.
  ///
  /// In ar, this message translates to:
  /// **'دينار ليبي'**
  String get currency_LYD;

  /// No description provided for @currency_MAD.
  ///
  /// In ar, this message translates to:
  /// **'درهم مغربي'**
  String get currency_MAD;

  /// No description provided for @currency_BHD.
  ///
  /// In ar, this message translates to:
  /// **'دينار بحريني'**
  String get currency_BHD;

  /// No description provided for @currency_QAR.
  ///
  /// In ar, this message translates to:
  /// **'ريال قطري'**
  String get currency_QAR;

  /// No description provided for @currency_OMR.
  ///
  /// In ar, this message translates to:
  /// **'ريال عماني'**
  String get currency_OMR;

  /// No description provided for @text1.
  ///
  /// In ar, this message translates to:
  /// **'وصلت للحد الأقصى!'**
  String get text1;

  /// No description provided for @text2.
  ///
  /// In ar, this message translates to:
  /// **'حسابك الحالي هو حساب ضيف تجريبي. لقد وصلت للحد الأقصى المسموح به للإضافات.\n\nيرجى ربط حسابك بـ Google للاستمرار في استخدام التطبيق مجاناً وبدون قيود، وحفظ بياناتك من الضياع.'**
  String get text2;

  /// No description provided for @text3.
  ///
  /// In ar, this message translates to:
  /// **'لاحقاً'**
  String get text3;

  /// No description provided for @text4.
  ///
  /// In ar, this message translates to:
  /// **'ربط بحساب Google'**
  String get text4;

  /// No description provided for @text5.
  ///
  /// In ar, this message translates to:
  /// **'تم ترقية الحساب بنجاح! يمكنك الآن الاستمرار بلا قيود.'**
  String get text5;

  /// No description provided for @text6.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة مبيعات'**
  String get text6;

  /// No description provided for @text7.
  ///
  /// In ar, this message translates to:
  /// **'بيانات العميل:'**
  String get text7;

  /// No description provided for @text8.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الطلب:'**
  String get text8;

  /// No description provided for @text9.
  ///
  /// In ar, this message translates to:
  /// **'المنتج'**
  String get text9;

  /// No description provided for @text10.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get text10;

  /// No description provided for @text11.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get text11;

  /// No description provided for @text12.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get text12;

  /// No description provided for @text13.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي المستحق:'**
  String get text13;

  /// No description provided for @text14.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المدفوع:'**
  String get text14;

  /// No description provided for @text15.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي (آجل):'**
  String get text15;

  /// No description provided for @text16.
  ///
  /// In ar, this message translates to:
  /// **'شكراً لتعاملكم معنا!'**
  String get text16;

  /// No description provided for @text17.
  ///
  /// In ar, this message translates to:
  /// **'كشف حساب عميل'**
  String get text17;

  /// No description provided for @text18.
  ///
  /// In ar, this message translates to:
  /// **'سجل الطلبات:'**
  String get text18;

  /// No description provided for @text19.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الطلب'**
  String get text19;

  /// No description provided for @text20.
  ///
  /// In ar, this message translates to:
  /// **'المدفوع'**
  String get text20;

  /// No description provided for @text21.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي'**
  String get text21;

  /// No description provided for @text22.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get text22;

  /// No description provided for @text23.
  ///
  /// In ar, this message translates to:
  /// **'cancelled\' ? \'ملغي'**
  String get text23;

  /// No description provided for @text24.
  ///
  /// In ar, this message translates to:
  /// **'معتمد'**
  String get text24;

  /// No description provided for @text25.
  ///
  /// In ar, this message translates to:
  /// **'مسح الباركود'**
  String get text25;

  /// No description provided for @text26.
  ///
  /// In ar, this message translates to:
  /// **'فشل في تسجيل الدخول المجهول'**
  String get text26;

  /// No description provided for @text27.
  ///
  /// In ar, this message translates to:
  /// **'تهيئة مساحة العمل الخاصة بك...'**
  String get text27;

  /// No description provided for @text28.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get text28;

  /// No description provided for @text29.
  ///
  /// In ar, this message translates to:
  /// **'المستخدم غير مسجل الدخول'**
  String get text29;

  /// No description provided for @text30.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء تسجيل الدخول'**
  String get text30;

  /// No description provided for @text31.
  ///
  /// In ar, this message translates to:
  /// **'تم ربط الحساب بنجاح!'**
  String get text31;

  /// No description provided for @text32.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال رقم الهاتف'**
  String get text32;

  /// No description provided for @text33.
  ///
  /// In ar, this message translates to:
  /// **'إكمال التسجيل'**
  String get text33;

  /// No description provided for @text34.
  ///
  /// In ar, this message translates to:
  /// **'لحماية بياناتك من الضياع، يرجى ربط حسابك بـ Google وإدخال رقم للتواصل.'**
  String get text34;

  /// No description provided for @text35.
  ///
  /// In ar, this message translates to:
  /// **'الربط بحساب Google'**
  String get text35;

  /// No description provided for @text36.
  ///
  /// In ar, this message translates to:
  /// **'تم ربط الحساب بنجاح'**
  String get text36;

  /// No description provided for @text37.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف (الواتساب)'**
  String get text37;

  /// No description provided for @text38.
  ///
  /// In ar, this message translates to:
  /// **'حفظ والمتابعة'**
  String get text38;

  /// No description provided for @text39.
  ///
  /// In ar, this message translates to:
  /// **'إدارة التصنيفات'**
  String get text39;

  /// No description provided for @text40.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد تصنيفات حالياً'**
  String get text40;

  /// No description provided for @text41.
  ///
  /// In ar, this message translates to:
  /// **'إضافة تصنيف جديد'**
  String get text41;

  /// No description provided for @text42.
  ///
  /// In ar, this message translates to:
  /// **'اسم التصنيف'**
  String get text42;

  /// No description provided for @text43.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get text43;

  /// No description provided for @text44.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get text44;

  /// No description provided for @text45.
  ///
  /// In ar, this message translates to:
  /// **'تعديل التصنيف'**
  String get text45;

  /// No description provided for @text46.
  ///
  /// In ar, this message translates to:
  /// **'تحديث'**
  String get text46;

  /// No description provided for @text47.
  ///
  /// In ar, this message translates to:
  /// **'المستخدم غير مسجل'**
  String get text47;

  /// No description provided for @text48.
  ///
  /// In ar, this message translates to:
  /// **'تعديل بيانات العميل'**
  String get text48;

  /// No description provided for @text49.
  ///
  /// In ar, this message translates to:
  /// **'إضافة عميل جديد'**
  String get text49;

  /// No description provided for @text50.
  ///
  /// In ar, this message translates to:
  /// **'اسم العميل'**
  String get text50;

  /// No description provided for @text51.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب'**
  String get text51;

  /// No description provided for @text52.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get text52;

  /// No description provided for @text53.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التعديلات'**
  String get text53;

  /// No description provided for @text54.
  ///
  /// In ar, this message translates to:
  /// **'إضافة العميل'**
  String get text54;

  /// No description provided for @text55.
  ///
  /// In ar, this message translates to:
  /// **'إدارة العملاء'**
  String get text55;

  /// No description provided for @text56.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد عملاء بعد.\nاضغط على + لإضافة عميل جديد.'**
  String get text56;

  /// No description provided for @text57.
  ///
  /// In ar, this message translates to:
  /// **'حذف العميل'**
  String get text57;

  /// No description provided for @text58.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من حذف هذا العميل؟'**
  String get text58;

  /// No description provided for @text59.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get text59;

  /// No description provided for @text60.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get text60;

  /// No description provided for @text61.
  ///
  /// In ar, this message translates to:
  /// **'طباعة كشف حساب'**
  String get text61;

  /// No description provided for @text62.
  ///
  /// In ar, this message translates to:
  /// **'إضافة عميل'**
  String get text62;

  /// No description provided for @text63.
  ///
  /// In ar, this message translates to:
  /// **'عرض'**
  String get text63;

  /// No description provided for @text64.
  ///
  /// In ar, this message translates to:
  /// **'المصروفات'**
  String get text64;

  /// No description provided for @text65.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد مصروفات حالياً'**
  String get text65;

  /// No description provided for @text66.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المصروفات'**
  String get text66;

  /// No description provided for @text67.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مصروف جديد'**
  String get text67;

  /// No description provided for @text68.
  ///
  /// In ar, this message translates to:
  /// **'البيان (مثال: إيجار المحل)'**
  String get text68;

  /// No description provided for @text69.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get text69;

  /// No description provided for @text70.
  ///
  /// In ar, this message translates to:
  /// **'التصنيف (اختياري)'**
  String get text70;

  /// No description provided for @text71.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء إدخال البيان (اسم المصروف)'**
  String get text71;

  /// No description provided for @text72.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء إدخال مبلغ صحيح أكبر من الصفر'**
  String get text72;

  /// No description provided for @text73.
  ///
  /// In ar, this message translates to:
  /// **'سجل حركة المخزون'**
  String get text73;

  /// No description provided for @text74.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حركات مسجلة حالياً'**
  String get text74;

  /// No description provided for @text75.
  ///
  /// In ar, this message translates to:
  /// **'المنتج غير موجود'**
  String get text75;

  /// No description provided for @text76.
  ///
  /// In ar, this message translates to:
  /// **'الكمية غير كافية في المخزون'**
  String get text76;

  /// No description provided for @text77.
  ///
  /// In ar, this message translates to:
  /// **'العميل غير موجود'**
  String get text77;

  /// No description provided for @text78.
  ///
  /// In ar, this message translates to:
  /// **'الكمية غير كافية لإعادة تفعيل الطلب'**
  String get text78;

  /// No description provided for @text79.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم العثور على منتج بهذا الباركود'**
  String get text79;

  /// No description provided for @text80.
  ///
  /// In ar, this message translates to:
  /// **'الكمية المطلوبة غير متوفرة في المخزون'**
  String get text80;

  /// No description provided for @text81.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المدفوع لا يمكن أن يكون أكبر من الإجمالي'**
  String get text81;

  /// No description provided for @text82.
  ///
  /// In ar, this message translates to:
  /// **'طلب مبيعات جديد'**
  String get text82;

  /// No description provided for @text83.
  ///
  /// In ar, this message translates to:
  /// **'بيع آجل (دين)'**
  String get text83;

  /// No description provided for @text84.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الطلب كدين على العميل'**
  String get text84;

  /// No description provided for @text85.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المدفوع مقدماً (اختياري)'**
  String get text85;

  /// No description provided for @text86.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات بعد.\nاضغط على + لإنشاء طلب جديد.'**
  String get text86;

  /// No description provided for @text87.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من حذف هذا الطلب؟ سيتم استرجاع كمية المنتج للمخزون.'**
  String get text87;

  /// No description provided for @text88.
  ///
  /// In ar, this message translates to:
  /// **'قيد الانتظار 🟡'**
  String get text88;

  /// No description provided for @text89.
  ///
  /// In ar, this message translates to:
  /// **'قيد التجهيز 🔵'**
  String get text89;

  /// No description provided for @text90.
  ///
  /// In ar, this message translates to:
  /// **'تم الشحن 🟠'**
  String get text90;

  /// No description provided for @text91.
  ///
  /// In ar, this message translates to:
  /// **'مكتمل 🟢'**
  String get text91;

  /// No description provided for @text92.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب 🔴'**
  String get text92;

  /// No description provided for @text93.
  ///
  /// In ar, this message translates to:
  /// **'طباعة الفاتورة PDF'**
  String get text93;

  /// No description provided for @text94.
  ///
  /// In ar, this message translates to:
  /// **'طلب جديد'**
  String get text94;

  /// No description provided for @text95.
  ///
  /// In ar, this message translates to:
  /// **'قيد التجهيز'**
  String get text95;

  /// No description provided for @text96.
  ///
  /// In ar, this message translates to:
  /// **'تم الشحن'**
  String get text96;

  /// No description provided for @text97.
  ///
  /// In ar, this message translates to:
  /// **'مكتمل'**
  String get text97;

  /// No description provided for @text98.
  ///
  /// In ar, this message translates to:
  /// **'ملغي'**
  String get text98;

  /// No description provided for @text99.
  ///
  /// In ar, this message translates to:
  /// **'قيد الانتظار'**
  String get text99;

  /// No description provided for @text100.
  ///
  /// In ar, this message translates to:
  /// **'تعديل يدوي'**
  String get text100;

  /// No description provided for @text101.
  ///
  /// In ar, this message translates to:
  /// **'إضافة منتج'**
  String get text101;

  /// No description provided for @text102.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد منتجات بعد.\nاضغط على + لإضافة منتج جديد.'**
  String get text102;

  /// No description provided for @text103.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من حذف هذا المنتج؟'**
  String get text103;

  /// No description provided for @text104.
  ///
  /// In ar, this message translates to:
  /// **'التقارير والأرباح'**
  String get text104;

  /// No description provided for @text105.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المبيعات'**
  String get text105;

  /// No description provided for @text106.
  ///
  /// In ar, this message translates to:
  /// **'صافي الربح'**
  String get text106;

  /// No description provided for @text107.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الديون (الآجل)'**
  String get text107;

  /// No description provided for @text108.
  ///
  /// In ar, this message translates to:
  /// **'المبيعات اليومية'**
  String get text108;

  /// No description provided for @text109.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مبيعات بعد'**
  String get text109;

  /// No description provided for @text110.
  ///
  /// In ar, this message translates to:
  /// **'الأكثر مبيعاً'**
  String get text110;

  /// No description provided for @text111.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get text111;

  /// No description provided for @text112.
  ///
  /// In ar, this message translates to:
  /// **'ترقية الحساب'**
  String get text112;

  /// No description provided for @text113.
  ///
  /// In ar, this message translates to:
  /// **'باقة تاجـــر برو 🚀'**
  String get text113;

  /// No description provided for @text114.
  ///
  /// In ar, this message translates to:
  /// **'استمتع بإضافة منتجات وعملاء لا محدودين، مع دعم فني متقدم وإحصائيات مفصلة.'**
  String get text114;

  /// No description provided for @text115.
  ///
  /// In ar, this message translates to:
  /// **'يجب عليك ربط حسابك بـ Google أولاً لتتمكن من الاشتراك في الباقة.'**
  String get text115;

  /// No description provided for @text116.
  ///
  /// In ar, this message translates to:
  /// **'ربط الحساب الآن'**
  String get text116;

  /// No description provided for @text117.
  ///
  /// In ar, this message translates to:
  /// **'عملية شراء الباقات ودفع الاشتراكات (10 دولار/شهرياً) متاحة فقط عبر تطبيق الأندرويد من متجر Google Play، ولا يمكن الدفع عبر متصفح الويب.'**
  String get text117;

  /// No description provided for @text118.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تحميل التطبيق على هاتفك لإتمام عملية الترقية والدفع.'**
  String get text118;

  /// No description provided for @text119.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اشتراكات متاحة حالياً. الرجاء المحاولة لاحقاً.'**
  String get text119;

  /// No description provided for @text120.
  ///
  /// In ar, this message translates to:
  /// **'اشترك الآن'**
  String get text120;

  /// No description provided for @text121.
  ///
  /// In ar, this message translates to:
  /// **'استعادة المشتريات السابقة'**
  String get text121;

  /// No description provided for @text122.
  ///
  /// In ar, this message translates to:
  /// **'إدارة الموردين'**
  String get text122;

  /// No description provided for @text123.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد موردين حالياً'**
  String get text123;

  /// No description provided for @text124.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد رقم هاتف'**
  String get text124;

  /// No description provided for @text125.
  ///
  /// In ar, this message translates to:
  /// **'الديون المستحقة'**
  String get text125;

  /// No description provided for @text126.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مورد جديد'**
  String get text126;

  /// No description provided for @text127.
  ///
  /// In ar, this message translates to:
  /// **'اسم المورد'**
  String get text127;

  /// No description provided for @text128.
  ///
  /// In ar, this message translates to:
  /// **'رقم الجوال'**
  String get text128;

  /// No description provided for @text129.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الافتتاحي (الديون)'**
  String get text129;

  /// No description provided for @text130.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المورد'**
  String get text130;

  /// No description provided for @text131.
  ///
  /// In ar, this message translates to:
  /// **'تحديث الديون'**
  String get text131;

  /// No description provided for @permCanManageProducts.
  ///
  /// In ar, this message translates to:
  /// **'إضافة وتعديل المنتجات'**
  String get permCanManageProducts;

  /// No description provided for @permCanViewCost.
  ///
  /// In ar, this message translates to:
  /// **'رؤية سعر التكلفة والأرباح'**
  String get permCanViewCost;

  /// No description provided for @permCanManageInventory.
  ///
  /// In ar, this message translates to:
  /// **'إدارة وجرد المخزون'**
  String get permCanManageInventory;

  /// No description provided for @permCanCreateOrders.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء فواتير وطلبات جديدة'**
  String get permCanCreateOrders;

  /// No description provided for @permCanCancelOrders.
  ///
  /// In ar, this message translates to:
  /// **'تعديل أو إلغاء الطلبات'**
  String get permCanCancelOrders;

  /// No description provided for @permCanSellOnCredit.
  ///
  /// In ar, this message translates to:
  /// **'البيع بالآجل / الدين'**
  String get permCanSellOnCredit;

  /// No description provided for @permCanManageCustomers.
  ///
  /// In ar, this message translates to:
  /// **'إضافة وتعديل بيانات العملاء'**
  String get permCanManageCustomers;

  /// No description provided for @permCanReceivePayments.
  ///
  /// In ar, this message translates to:
  /// **'تسديد الديون واستلام المبالغ'**
  String get permCanReceivePayments;

  /// No description provided for @permCanManageExpenses.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل ومتابعة المصروفات'**
  String get permCanManageExpenses;

  /// No description provided for @employeePermissions.
  ///
  /// In ar, this message translates to:
  /// **'الموظفين والصلاحيات (Pro)'**
  String get employeePermissions;

  /// No description provided for @permissionSettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الصلاحيات'**
  String get permissionSettings;

  /// No description provided for @credit.
  ///
  /// In ar, this message translates to:
  /// **'آجل'**
  String get credit;

  /// No description provided for @customer.
  ///
  /// In ar, this message translates to:
  /// **'العميل'**
  String get customer;

  /// No description provided for @walkInCustomer.
  ///
  /// In ar, this message translates to:
  /// **'عميل نقدي (بدون حساب)'**
  String get walkInCustomer;

  /// No description provided for @cancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغي'**
  String get cancelled;

  /// No description provided for @settingsAccountEmployees.
  ///
  /// In ar, this message translates to:
  /// **'الحساب والموظفين'**
  String get settingsAccountEmployees;

  /// No description provided for @settingsPersonalMerchantAccount.
  ///
  /// In ar, this message translates to:
  /// **'حساب التاجر (الإدارة)'**
  String get settingsPersonalMerchantAccount;

  /// No description provided for @settingsUnknown.
  ///
  /// In ar, this message translates to:
  /// **'غير معروف'**
  String get settingsUnknown;

  /// No description provided for @settingsEmployeesPermissions.
  ///
  /// In ar, this message translates to:
  /// **'(Pro) الموظفين والصلاحيات'**
  String get settingsEmployeesPermissions;

  /// No description provided for @settingsCentralizedAuditLog.
  ///
  /// In ar, this message translates to:
  /// **'سجل حركات النظام (المراقبة)'**
  String get settingsCentralizedAuditLog;

  /// No description provided for @settingsMonitorActions.
  ///
  /// In ar, this message translates to:
  /// **'مراقبة جميع حركات الموظفين والمبيعات'**
  String get settingsMonitorActions;

  /// No description provided for @settingsStoreSettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات المتجر'**
  String get settingsStoreSettings;

  /// No description provided for @settingsBackupSecurity.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطي والأمان'**
  String get settingsBackupSecurity;

  /// No description provided for @settingsThermalPrinter.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الطابعة الحرارية'**
  String get settingsThermalPrinter;

  /// No description provided for @settingsStoreBranding.
  ///
  /// In ar, this message translates to:
  /// **'هوية المتجر (الشعار والفواتير)'**
  String get settingsStoreBranding;

  /// No description provided for @settingsSystemPreferences.
  ///
  /// In ar, this message translates to:
  /// **'تفضيلات النظام'**
  String get settingsSystemPreferences;

  /// No description provided for @settingsSupportRating.
  ///
  /// In ar, this message translates to:
  /// **'الدعم والتقييم'**
  String get settingsSupportRating;

  /// No description provided for @settingsAppUserGuide.
  ///
  /// In ar, this message translates to:
  /// **'دليل استخدام التطبيق (شرح فيديو)'**
  String get settingsAppUserGuide;

  /// No description provided for @settingsHowToSetup.
  ///
  /// In ar, this message translates to:
  /// **'كيفية تجهيز متجرك وإضافة المنتجات'**
  String get settingsHowToSetup;

  /// No description provided for @settingsFollowTikTok.
  ///
  /// In ar, this message translates to:
  /// **'تابعنا على تيك توك'**
  String get settingsFollowTikTok;

  /// No description provided for @settingsSuggestionsUpdates.
  ///
  /// In ar, this message translates to:
  /// **'للاقتراحات والتحديثات الجديدة'**
  String get settingsSuggestionsUpdates;

  /// No description provided for @settingsCouldNotOpenLink.
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح الرابط'**
  String get settingsCouldNotOpenLink;

  /// No description provided for @settingsEmailSupport.
  ///
  /// In ar, this message translates to:
  /// **'الدعم الفني عبر البريد الإلكتروني'**
  String get settingsEmailSupport;

  /// No description provided for @settingsTechnicalIssues.
  ///
  /// In ar, this message translates to:
  /// **'لحل المشكلات التقنية والاستفسارات'**
  String get settingsTechnicalIssues;

  /// No description provided for @settingsCouldNotOpenEmail.
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح تطبيق البريد الإلكتروني'**
  String get settingsCouldNotOpenEmail;

  /// No description provided for @settingsRatePlayStore.
  ///
  /// In ar, this message translates to:
  /// **'تقييم التطبيق على متجر بلاي'**
  String get settingsRatePlayStore;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsCouldNotOpenBrowser.
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح المتصفح. تأكد من وجود متصفح في جهازك.'**
  String get settingsCouldNotOpenBrowser;

  /// No description provided for @settingsAppVersion.
  ///
  /// In ar, this message translates to:
  /// **'بسطه - نقطة بيع v1.0.42\nصُنع بحب 💛'**
  String get settingsAppVersion;

  /// No description provided for @empPermViewCostProfits.
  ///
  /// In ar, this message translates to:
  /// **'رؤية التكلفة والأرباح'**
  String get empPermViewCostProfits;

  /// No description provided for @empPermManageInventory.
  ///
  /// In ar, this message translates to:
  /// **'إدارة وتتبع المخزون'**
  String get empPermManageInventory;

  /// No description provided for @empPermCreateInvoices.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء فواتير وطلبات جديدة'**
  String get empPermCreateInvoices;

  /// No description provided for @empPermEditCancelOrders.
  ///
  /// In ar, this message translates to:
  /// **'تعديل أو إلغاء الطلبات'**
  String get empPermEditCancelOrders;

  /// No description provided for @empPermSellCredit.
  ///
  /// In ar, this message translates to:
  /// **'البيع بالآجل (الديون)'**
  String get empPermSellCredit;

  /// No description provided for @empPermAddEditCustomer.
  ///
  /// In ar, this message translates to:
  /// **'إضافة وتعديل بيانات العملاء'**
  String get empPermAddEditCustomer;

  /// No description provided for @empPermSettleDebts.
  ///
  /// In ar, this message translates to:
  /// **'تسوية الديون واستلام الدفعات'**
  String get empPermSettleDebts;

  /// No description provided for @empPermRecordExpenses.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل وتتبع المصروفات'**
  String get empPermRecordExpenses;

  /// No description provided for @empPermViewReports.
  ///
  /// In ar, this message translates to:
  /// **'السماح برؤية قسم التقارير'**
  String get empPermViewReports;

  /// No description provided for @empPermViewAllOrders.
  ///
  /// In ar, this message translates to:
  /// **'السماح برؤية جميع الطلبات'**
  String get empPermViewAllOrders;

  /// No description provided for @empPermAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get empPermAdd;

  /// No description provided for @empPermCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get empPermCancel;

  /// No description provided for @empImportantInstructions.
  ///
  /// In ar, this message translates to:
  /// **'تعليمات هامة للتاجر'**
  String get empImportantInstructions;

  /// No description provided for @empInstruction1.
  ///
  /// In ar, this message translates to:
  /// **'1. يمكنك إضافة حد أقصى 3 موظفين.'**
  String get empInstruction1;

  /// No description provided for @empInstruction2.
  ///
  /// In ar, this message translates to:
  /// **'2. عندما يحمل الموظف التطبيق، يجب أن يختار (دخول موظف بالرمز).'**
  String get empInstruction2;

  /// No description provided for @empInstruction3.
  ///
  /// In ar, this message translates to:
  /// **'3. سيُطلب منه إدخال إيميلك الأساسي ورمز الدخول الذي أنشأته له.'**
  String get empInstruction3;

  /// No description provided for @empMainEmail.
  ///
  /// In ar, this message translates to:
  /// **'إيميلك الأساسي (الذي يجب أن يكتبه الموظف):'**
  String get empMainEmail;

  /// No description provided for @empEmployeeList.
  ///
  /// In ar, this message translates to:
  /// **'قائمة الموظفين'**
  String get empEmployeeList;

  /// No description provided for @empNoEmployees.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد موظفين حالياً'**
  String get empNoEmployees;

  /// No description provided for @taxSettingsOptional.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الضريبة (اختياري)'**
  String get taxSettingsOptional;

  /// No description provided for @taxSettingsWarning.
  ///
  /// In ar, this message translates to:
  /// **'تحديد الإعدادات هنا سيلغي إعدادات المتجر العامة لهذا المنتج، وسيؤثر مباشرة على الحساب النهائي.'**
  String get taxSettingsWarning;

  /// No description provided for @taxPercentage.
  ///
  /// In ar, this message translates to:
  /// **'نسبة الضريبة الخاصة بالمنتج (%)'**
  String get taxPercentage;

  /// No description provided for @taxIncludedInPrice.
  ///
  /// In ar, this message translates to:
  /// **'السعر المحدد يشمل الضريبة'**
  String get taxIncludedInPrice;

  /// No description provided for @recipeOptional.
  ///
  /// In ar, this message translates to:
  /// **'وصفة المنتج (مواد خام) - اختياري'**
  String get recipeOptional;

  /// No description provided for @searchByNamePhone.
  ///
  /// In ar, this message translates to:
  /// **'بحث بالاسم أو رقم الهاتف'**
  String get searchByNamePhone;

  /// No description provided for @deleteCustomerWarning.
  ///
  /// In ar, this message translates to:
  /// **'تحذير: حذف ملف عميل'**
  String get deleteCustomerWarning;

  /// No description provided for @deleteCustomerText.
  ///
  /// In ar, this message translates to:
  /// **'حذف العميل سيؤدي إلى مسح سجله المالي وديونه من النظام نهائياً. لا يمكن التراجع عن هذا الإجراء.'**
  String get deleteCustomerText;

  /// No description provided for @enterPinToConfirm.
  ///
  /// In ar, this message translates to:
  /// **'للتأكيد (PIN) أدخل رمز الأمان:'**
  String get enterPinToConfirm;

  /// No description provided for @confirmDelete.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد وحذف'**
  String get confirmDelete;

  /// No description provided for @cancelBtn.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get cancelBtn;

  /// No description provided for @backupExportSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تصدير النسخة الاحتياطية بنجاح!'**
  String get backupExportSuccess;

  /// No description provided for @backupExportError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء التصدير'**
  String get backupExportError;

  /// No description provided for @backupImportSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم استعادة النسخة بنجاح!'**
  String get backupImportSuccess;

  /// No description provided for @backupImportError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء الاستعادة'**
  String get backupImportError;

  /// No description provided for @backupSecurityTitle.
  ///
  /// In ar, this message translates to:
  /// **'النسخة الاحتياطية المحلية'**
  String get backupSecurityTitle;

  /// No description provided for @localBackupRestore.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء واستعادة النسخة'**
  String get localBackupRestore;

  /// No description provided for @localBackupDesc.
  ///
  /// In ar, this message translates to:
  /// **'يتم حفظ نسخة من منتجاتك (باستثناء الفواتير والصور) في ملف داخل جهازك. يمكنك استعادة هذه النسخة في أي وقت.'**
  String get localBackupDesc;

  /// No description provided for @exportBackupToDevice.
  ///
  /// In ar, this message translates to:
  /// **'حفظ النسخة في الجهاز'**
  String get exportBackupToDevice;

  /// No description provided for @importBackupFromDevice.
  ///
  /// In ar, this message translates to:
  /// **'استعادة النسخة من الجهاز'**
  String get importBackupFromDevice;

  /// No description provided for @printerErrorConnecting.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في جلب الأجهزة المقترنة'**
  String get printerErrorConnecting;

  /// No description provided for @printerConnecting.
  ///
  /// In ar, this message translates to:
  /// **'جاري الاتصال...'**
  String get printerConnecting;

  /// No description provided for @printerConnectedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم الاتصال بالطابعة بنجاح'**
  String get printerConnectedSuccess;

  /// No description provided for @printerConnectionFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل الاتصال بالطابعة'**
  String get printerConnectionFailed;

  /// No description provided for @printerSelectFirst.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء تحديد طابعة أولاً'**
  String get printerSelectFirst;

  /// No description provided for @printerDisconnected.
  ///
  /// In ar, this message translates to:
  /// **'تم قطع الاتصال'**
  String get printerDisconnected;

  /// No description provided for @printerNotConnected.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طابعة متصلة'**
  String get printerNotConnected;

  /// No description provided for @printerConnectionSettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات اتصال الطابعة'**
  String get printerConnectionSettings;

  /// No description provided for @printerSelectDevice.
  ///
  /// In ar, this message translates to:
  /// **'اختيار الطابعة (بلوتوث)'**
  String get printerSelectDevice;

  /// No description provided for @printerSelectHint.
  ///
  /// In ar, this message translates to:
  /// **'حدد طابعة...'**
  String get printerSelectHint;

  /// No description provided for @printerPaperSize.
  ///
  /// In ar, this message translates to:
  /// **'حجم الورق'**
  String get printerPaperSize;

  /// No description provided for @printerSize58.
  ///
  /// In ar, this message translates to:
  /// **'58 مليمتر (صغير)'**
  String get printerSize58;

  /// No description provided for @printerSize80.
  ///
  /// In ar, this message translates to:
  /// **'80 مليمتر (كبير)'**
  String get printerSize80;

  /// No description provided for @printerRefresh.
  ///
  /// In ar, this message translates to:
  /// **'تحديث القائمة'**
  String get printerRefresh;

  /// No description provided for @printerConnect.
  ///
  /// In ar, this message translates to:
  /// **'توصيل'**
  String get printerConnect;

  /// No description provided for @printerDisconnect.
  ///
  /// In ar, this message translates to:
  /// **'قطع الاتصال'**
  String get printerDisconnect;

  /// No description provided for @brandingErrorPickingImage.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في اختيار الصورة'**
  String get brandingErrorPickingImage;

  /// No description provided for @brandingSavedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ بنجاح'**
  String get brandingSavedSuccess;

  /// No description provided for @brandingSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get brandingSave;

  /// No description provided for @brandingSelectLogo.
  ///
  /// In ar, this message translates to:
  /// **'إضافة الشعار'**
  String get brandingSelectLogo;

  /// No description provided for @brandingRemoveLogo.
  ///
  /// In ar, this message translates to:
  /// **'إزالة الشعار'**
  String get brandingRemoveLogo;

  /// No description provided for @brandingStoreName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المتجر'**
  String get brandingStoreName;

  /// No description provided for @brandingStorePhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم هاتف المتجر'**
  String get brandingStorePhone;

  /// No description provided for @brandingStoreAddress.
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get brandingStoreAddress;

  /// No description provided for @brandingTaxSettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الضريبة الافتراضية'**
  String get brandingTaxSettings;

  /// No description provided for @brandingDefaultTax.
  ///
  /// In ar, this message translates to:
  /// **'نسبة الضريبة الافتراضية (%)'**
  String get brandingDefaultTax;

  /// No description provided for @brandingDefaultTaxHelper.
  ///
  /// In ar, this message translates to:
  /// **'هذه هي النسبة التي سيتم تطبيقها تلقائياً على أي منتج جديد تضيفه. يمكنك تغيير النسبة لكل منتج لاحقاً من قسم المنتجات.'**
  String get brandingDefaultTaxHelper;

  /// No description provided for @brandingTaxInclusive.
  ///
  /// In ar, this message translates to:
  /// **'الأسعار تشمل الضريبة (الافتراضي)'**
  String get brandingTaxInclusive;

  /// No description provided for @brandingTaxInclusiveHelper.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل هذا الخيار يعني أن السعر الذي تدخله للمنتج هو السعر النهائي الشامل للضريبة.'**
  String get brandingTaxInclusiveHelper;

  /// No description provided for @brandingZatcaTitle.
  ///
  /// In ar, this message translates to:
  /// **'متطلبات الفوترة الإلكترونية (ZATCA)'**
  String get brandingZatcaTitle;

  /// No description provided for @brandingZatcaDesc.
  ///
  /// In ar, this message translates to:
  /// **'مطلوبة لـ \"الفوترة الإلكترونية\". يُرجى تعبئة البيانات الضريبية ليتم طباعتها في الفواتير الحرارية مع رمز QR متوافق مع هيئة الزكاة والضريبة والجمارك (ZATCA) بالمملكة العربية السعودية.'**
  String get brandingZatcaDesc;

  /// No description provided for @brandingVatNumber.
  ///
  /// In ar, this message translates to:
  /// **'الرقم الضريبي (VAT Number)'**
  String get brandingVatNumber;

  /// No description provided for @brandingVatHelper.
  ///
  /// In ar, this message translates to:
  /// **'يتكون من 15 رقماً ويبدأ وينتهي برقم 3.'**
  String get brandingVatHelper;

  /// No description provided for @brandingCrNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم السجل التجاري (CR Number)'**
  String get brandingCrNumber;

  /// No description provided for @brandingCrHelper.
  ///
  /// In ar, this message translates to:
  /// **'اختياري، يطبع في الفاتورة إن وجد.'**
  String get brandingCrHelper;

  /// No description provided for @purchaseSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم الشراء بنجاح!'**
  String get purchaseSuccess;

  /// No description provided for @purchaseError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ أثناء الشراء'**
  String get purchaseError;

  /// No description provided for @restoreSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم استعادة المشتريات بنجاح!'**
  String get restoreSuccess;

  /// No description provided for @restoreNoActive.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم العثور على اشتراكات فعالة.'**
  String get restoreNoActive;

  /// No description provided for @restoreError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ أثناء استعادة المشتريات'**
  String get restoreError;

  /// No description provided for @subscriptionTitle.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراك والباقات'**
  String get subscriptionTitle;

  /// No description provided for @premiumAccessTitle.
  ///
  /// In ar, this message translates to:
  /// **'افتح جميع المميزات الاحترافية'**
  String get premiumAccessTitle;

  /// No description provided for @premiumAccessDesc.
  ///
  /// In ar, this message translates to:
  /// **'أدر متجرك بكفاءة عالية مع تقارير متقدمة وطلبات غير محدودة لتنمية مبيعاتك.'**
  String get premiumAccessDesc;

  /// No description provided for @monthlyPlanTitle.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراك الشهري'**
  String get monthlyPlanTitle;

  /// No description provided for @featureUnlimitedOrders.
  ///
  /// In ar, this message translates to:
  /// **'طلبات وفواتير غير محدودة'**
  String get featureUnlimitedOrders;

  /// No description provided for @featureInventorySync.
  ///
  /// In ar, this message translates to:
  /// **'إدارة متقدمة للمخزون والمستودع'**
  String get featureInventorySync;

  /// No description provided for @featureAdvancedReports.
  ///
  /// In ar, this message translates to:
  /// **'تقارير مالية ومبيعات مفصلة'**
  String get featureAdvancedReports;

  /// No description provided for @featurePrioritySupport.
  ///
  /// In ar, this message translates to:
  /// **'دعم فني على مدار الساعة'**
  String get featurePrioritySupport;

  /// No description provided for @subscribeFor.
  ///
  /// In ar, this message translates to:
  /// **'اشترك الآن بـ {price}'**
  String subscribeFor(String price);

  /// No description provided for @noPackagesAvailable.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد باقات متاحة حالياً، يرجى المحاولة لاحقاً.'**
  String get noPackagesAvailable;

  /// No description provided for @restorePurchasesBtn.
  ///
  /// In ar, this message translates to:
  /// **'استعادة المشتريات'**
  String get restorePurchasesBtn;

  /// No description provided for @subscriptionTermsDesc.
  ///
  /// In ar, this message translates to:
  /// **'يتم تجديد الاشتراك تلقائياً. يمكنك إلغاء الاشتراك في أي وقت من إعدادات حسابك.'**
  String get subscriptionTermsDesc;

  /// No description provided for @confirmExit.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الخروج'**
  String get confirmExit;

  /// No description provided for @confirmExitMessage.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد أنك تريد الخروج من التطبيق؟'**
  String get confirmExitMessage;

  /// No description provided for @exit.
  ///
  /// In ar, this message translates to:
  /// **'خروج'**
  String get exit;

  /// No description provided for @employeePrefix.
  ///
  /// In ar, this message translates to:
  /// **'موظف: {name}'**
  String employeePrefix(String name);

  /// No description provided for @merchantAccount.
  ///
  /// In ar, this message translates to:
  /// **'حساب التاجر (الإدارة)'**
  String get merchantAccount;

  /// No description provided for @rawMaterials.
  ///
  /// In ar, this message translates to:
  /// **'المواد الخام'**
  String get rawMaterials;

  /// No description provided for @employeesPermissionsPro.
  ///
  /// In ar, this message translates to:
  /// **'الموظفين والصلاحيات (Pro)'**
  String get employeesPermissionsPro;

  /// No description provided for @closeShiftZReport.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق الوردية (Z-Report)'**
  String get closeShiftZReport;

  /// No description provided for @errorFetchingInventory.
  ///
  /// In ar, this message translates to:
  /// **'تعذر جلب بيانات المخزون. يرجى التحقق من اتصالك بالإنترنت.'**
  String get errorFetchingInventory;

  /// No description provided for @lowStockAlert.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه: يوجد {count} منتج يوشك على النفاذ من المخزون!'**
  String lowStockAlert(String count);

  /// No description provided for @completeStoreBrandingAlert.
  ///
  /// In ar, this message translates to:
  /// **'⚠️ يرجى إكمال إعدادات هوية المتجر (الاسم، الضريبة) لضمان طباعة الفواتير بشكل صحيح ومطابق للمواصفات.'**
  String get completeStoreBrandingAlert;

  /// No description provided for @completeNow.
  ///
  /// In ar, this message translates to:
  /// **'أكمل الآن'**
  String get completeNow;

  /// No description provided for @posCashier.
  ///
  /// In ar, this message translates to:
  /// **'كاشير (POS)'**
  String get posCashier;

  /// No description provided for @errorPrefix.
  ///
  /// In ar, this message translates to:
  /// **'خطأ: {error}'**
  String errorPrefix(String error);

  /// No description provided for @folder.
  ///
  /// In ar, this message translates to:
  /// **'المجلد'**
  String get folder;

  /// No description provided for @totalDebts.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الديون'**
  String get totalDebts;

  /// No description provided for @warningDeleteCustomer.
  ///
  /// In ar, this message translates to:
  /// **'تحذير: حذف ملف عميل'**
  String get warningDeleteCustomer;

  /// No description provided for @sortAlphabetical.
  ///
  /// In ar, this message translates to:
  /// **'أبجدي'**
  String get sortAlphabetical;

  /// No description provided for @totalCustomerDebtText.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي دين العميل: {debt}'**
  String totalCustomerDebtText(String debt);

  /// No description provided for @deleteCustomerWarningText.
  ///
  /// In ar, this message translates to:
  /// **'حذف العميل سيؤدي إلى مسح سجله المالي وديونه من النظام نهائياً. لا يمكن التراجع عن هذا الإجراء.'**
  String get deleteCustomerWarningText;

  /// No description provided for @leaveEmptyToRemoveFromFolder.
  ///
  /// In ar, this message translates to:
  /// **'اترك الحقل فارغاً لإزالة العملاء من أي مجلد.'**
  String get leaveEmptyToRemoveFromFolder;

  /// No description provided for @multiSelect.
  ///
  /// In ar, this message translates to:
  /// **'تحديد متعدد'**
  String get multiSelect;

  /// No description provided for @noCustomersToExport.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد عملاء للتصدير'**
  String get noCustomersToExport;

  /// No description provided for @hasDebts.
  ///
  /// In ar, this message translates to:
  /// **'عليهم ديون'**
  String get hasDebts;

  /// No description provided for @totalPurchases.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المشتريات'**
  String get totalPurchases;

  /// No description provided for @selectedCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} محدد'**
  String selectedCount(String count);

  /// No description provided for @general.
  ///
  /// In ar, this message translates to:
  /// **'عام'**
  String get general;

  /// No description provided for @whatsapp.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get whatsapp;

  /// No description provided for @moveToFolder.
  ///
  /// In ar, this message translates to:
  /// **'نقل إلى مجلد'**
  String get moveToFolder;

  /// No description provided for @dateAdded.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الإضافة'**
  String get dateAdded;

  /// No description provided for @payDebt.
  ///
  /// In ar, this message translates to:
  /// **'تسديد دفعة / تصفية دين'**
  String get payDebt;

  /// No description provided for @customersList.
  ///
  /// In ar, this message translates to:
  /// **'قائمة العملاء'**
  String get customersList;

  /// No description provided for @searchNamePhone.
  ///
  /// In ar, this message translates to:
  /// **'بحث بالاسم أو رقم الهاتف'**
  String get searchNamePhone;

  /// No description provided for @customerName.
  ///
  /// In ar, this message translates to:
  /// **'اسم العميل'**
  String get customerName;

  /// No description provided for @generalCustomers.
  ///
  /// In ar, this message translates to:
  /// **'عملاء عامون'**
  String get generalCustomers;

  /// No description provided for @sortBy.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب: '**
  String get sortBy;

  /// No description provided for @noCustomersMatch.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد عملاء يطابقون البحث'**
  String get noCustomersMatch;

  /// No description provided for @move.
  ///
  /// In ar, this message translates to:
  /// **'نقل'**
  String get move;

  /// No description provided for @debtAmount.
  ///
  /// In ar, this message translates to:
  /// **'دين: {debt} {currency}'**
  String debtAmount(String debt, String currency);

  /// No description provided for @printError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في الطباعة: {error}'**
  String printError(String error);

  /// No description provided for @phoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phoneNumber;

  /// No description provided for @exportExcel.
  ///
  /// In ar, this message translates to:
  /// **'تصدير لإكسل'**
  String get exportExcel;

  /// No description provided for @byCreator.
  ///
  /// In ar, this message translates to:
  /// **'بواسطة: {creator}'**
  String byCreator(String creator);

  /// No description provided for @exportError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء التصدير: {error}'**
  String exportError(String error);

  /// No description provided for @highestDebt.
  ///
  /// In ar, this message translates to:
  /// **'الأعلى ديناً'**
  String get highestDebt;

  /// No description provided for @paidAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المسدد من الدين'**
  String get paidAmount;

  /// No description provided for @rawMaterialsGuide.
  ///
  /// In ar, this message translates to:
  /// **'💡 دليل المواد الخام: هنا يمكنك إضافة مكونات مستودعك (مثل: لحم برجر، جبن، أكواب، بن قهوة). عند ربط هذه المكونات بوصفات المنتجات في شاشة المنتجات، سيقوم النظام بخصم كمياتها تلقائياً عند كل عملية بيع لحماية مشروعك من الهدر ومعرفة التكلفة الحقيقية لأرباحك.'**
  String get rawMaterialsGuide;

  /// No description provided for @mlLabel.
  ///
  /// In ar, this message translates to:
  /// **'مللي (ml)'**
  String get mlLabel;

  /// No description provided for @rawMaterialsUsageHint.
  ///
  /// In ar, this message translates to:
  /// **'💡 ستستخدم هذه المادة لربطها بوجبات ومنتجات البيع ليتم الخصم التلقائي عند إصدار الفواتير.'**
  String get rawMaterialsUsageHint;

  /// No description provided for @gLabel.
  ///
  /// In ar, this message translates to:
  /// **'جرام (g)'**
  String get gLabel;

  /// No description provided for @editRawMaterial.
  ///
  /// In ar, this message translates to:
  /// **'تعديل مادة خام'**
  String get editRawMaterial;

  /// No description provided for @measuringUnit.
  ///
  /// In ar, this message translates to:
  /// **'وحدة القياس:'**
  String get measuringUnit;

  /// No description provided for @noRawMaterialsFound.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مواد خام في المستودع بعد.\nاضغط على زر \"إضافة مادة خام\" بالأسفل للبدء!'**
  String get noRawMaterialsFound;

  /// No description provided for @availableBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد المتوفر: {quantity}  ({unit})'**
  String availableBalance(String quantity, String unit);

  /// No description provided for @saveInWarehouse.
  ///
  /// In ar, this message translates to:
  /// **'حفظ في المستودع'**
  String get saveInWarehouse;

  /// No description provided for @addRawMaterial.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مادة خام'**
  String get addRawMaterial;

  /// No description provided for @addNewRawMaterial.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مادة خام جديدة'**
  String get addNewRawMaterial;

  /// No description provided for @pieceUnit.
  ///
  /// In ar, this message translates to:
  /// **'قطعة / حبة'**
  String get pieceUnit;

  /// No description provided for @pieceUnitDesc.
  ///
  /// In ar, this message translates to:
  /// **'قطعة / حبة (piece) - للأكواب والخبز والعبوات'**
  String get pieceUnitDesc;

  /// No description provided for @pleaseEnterRawMaterialName.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال اسم المادة الخام أولاً'**
  String get pleaseEnterRawMaterialName;

  /// No description provided for @currentAvailableQuantity.
  ///
  /// In ar, this message translates to:
  /// **'الكمية المتوفرة حالياً في المستودع'**
  String get currentAvailableQuantity;

  /// No description provided for @gUnitDesc.
  ///
  /// In ar, this message translates to:
  /// **'جرام (g) - للوزن مثل اللحوم والقهوة'**
  String get gUnitDesc;

  /// No description provided for @mlUnitDesc.
  ///
  /// In ar, this message translates to:
  /// **'مللي (ml) - للسوائل والصلصات'**
  String get mlUnitDesc;

  /// No description provided for @resourceRunningOut.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه: المورد قارب على الانتهاء'**
  String get resourceRunningOut;

  /// No description provided for @rawMaterialNameExample.
  ///
  /// In ar, this message translates to:
  /// **'اسم المادة الخام (مثال: لحم برجر، جبن، قهوة بن)'**
  String get rawMaterialNameExample;

  /// No description provided for @rawMaterialsWarehouse.
  ///
  /// In ar, this message translates to:
  /// **'المواد الخام (مستودع المكونات)'**
  String get rawMaterialsWarehouse;

  /// No description provided for @orderNumberLabel.
  ///
  /// In ar, this message translates to:
  /// **'طلب #{number}'**
  String orderNumberLabel(String number);

  /// No description provided for @thisWeekFromTo.
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع (من {start} إلى {end})'**
  String thisWeekFromTo(String start, String end);

  /// No description provided for @thermalPrint.
  ///
  /// In ar, this message translates to:
  /// **'طباعة حرارية'**
  String get thermalPrint;

  /// No description provided for @invoicePermanentlyDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الفاتورة رقم #{number} نهائياً من قبل {user}'**
  String invoicePermanentlyDeleted(String number, String user);

  /// No description provided for @scheduledOrders.
  ///
  /// In ar, this message translates to:
  /// **'طلبات مجدولة 🗓'**
  String get scheduledOrders;

  /// No description provided for @totalIncome.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الدخل: '**
  String get totalIncome;

  /// No description provided for @monthPrefix.
  ///
  /// In ar, this message translates to:
  /// **'شهر '**
  String get monthPrefix;

  /// No description provided for @deleteInvoice.
  ///
  /// In ar, this message translates to:
  /// **'حذف الفاتورة'**
  String get deleteInvoice;

  /// No description provided for @confirmDeleteInvoiceMsg.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من مسح هذه الفاتورة؟ (سيعود المخزون للمنتجات)'**
  String get confirmDeleteInvoiceMsg;

  /// No description provided for @bankTransferMethod.
  ///
  /// In ar, this message translates to:
  /// **'تحويل بنكي 🏦'**
  String get bankTransferMethod;

  /// No description provided for @cashMethod.
  ///
  /// In ar, this message translates to:
  /// **'دفع كاش 💵'**
  String get cashMethod;

  /// No description provided for @agoPrefix.
  ///
  /// In ar, this message translates to:
  /// **'قبل '**
  String get agoPrefix;

  /// No description provided for @deleteBtn.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get deleteBtn;

  /// No description provided for @madaMethod.
  ///
  /// In ar, this message translates to:
  /// **'دفع مدى 💳'**
  String get madaMethod;

  /// No description provided for @warningFinalDelete.
  ///
  /// In ar, this message translates to:
  /// **'تحذير: حذف نهائي للطلب'**
  String get warningFinalDelete;

  /// No description provided for @hideBtn.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء'**
  String get hideBtn;

  /// No description provided for @weekFromTo.
  ///
  /// In ar, this message translates to:
  /// **' أسبوع (من {start} إلى {end})'**
  String weekFromTo(String start, String end);

  /// No description provided for @pdfInvoice.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة PDF'**
  String get pdfInvoice;

  /// No description provided for @finalDeleteWarningMsg.
  ///
  /// In ar, this message translates to:
  /// **'الحذف النهائي سيمحو هذا الطلب من السجلات تماماً بالإضافة إلى إرجاع الأموال وعكس الديون. لا يمكن استعادة الفاتورة. هل أنت متأكد؟'**
  String get finalDeleteWarningMsg;

  /// No description provided for @failDeleteInvoiceNoPermission.
  ///
  /// In ar, this message translates to:
  /// **'فشل مسح الفاتورة نهائياً لعدم وجود صلاحية أو لا توجد فاتورة.'**
  String get failDeleteInvoiceNoPermission;

  /// No description provided for @todayPrefix.
  ///
  /// In ar, this message translates to:
  /// **'اليوم - '**
  String get todayPrefix;

  /// No description provided for @posTitle.
  ///
  /// In ar, this message translates to:
  /// **'نقطة البيع (POS)'**
  String get posTitle;

  /// No description provided for @byCreatorIcon.
  ///
  /// In ar, this message translates to:
  /// **'👤 بواسطة: {creator}'**
  String byCreatorIcon(String creator);

  /// No description provided for @deleteInvoiceAction.
  ///
  /// In ar, this message translates to:
  /// **'حذف فاتورة'**
  String get deleteInvoiceAction;

  /// No description provided for @invoiceDeletedSuccessfully.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الفاتورة بنجاح'**
  String get invoiceDeletedSuccessfully;

  /// No description provided for @yearPrefix.
  ///
  /// In ar, this message translates to:
  /// **'سنة '**
  String get yearPrefix;

  /// No description provided for @deliveryDate.
  ///
  /// In ar, this message translates to:
  /// **'موعد التسليم: '**
  String get deliveryDate;

  /// No description provided for @yesterdayPrefix.
  ///
  /// In ar, this message translates to:
  /// **'أمس - '**
  String get yesterdayPrefix;

  /// No description provided for @paymentMethod.
  ///
  /// In ar, this message translates to:
  /// **' (الدفع: '**
  String get paymentMethod;

  /// No description provided for @invoiceCancelledMsg.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الفاتورة رقم #{number} بقيمة {value}'**
  String invoiceCancelledMsg(String number, String value);

  /// No description provided for @confirmFinalDeleteMsg.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من رغبتك في مسح الفاتورة نهائياً؟ لا يمكن التراجع عن هذه الخطوة.'**
  String get confirmFinalDeleteMsg;

  /// No description provided for @errorOccurred.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ: {error}'**
  String errorOccurred(String error);

  /// No description provided for @invoiceDeletedPermanently.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الفاتورة نهائياً'**
  String get invoiceDeletedPermanently;

  /// No description provided for @cancelOrder.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get cancelOrder;

  /// No description provided for @orderDetailsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الطلب #{number}'**
  String orderDetailsTitle(String number);

  /// No description provided for @orderConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'✅ طلب مؤكد / مكتمل'**
  String get orderConfirmed;

  /// No description provided for @invoiceOptions.
  ///
  /// In ar, this message translates to:
  /// **'⚙️ خيارات الفاتورة'**
  String get invoiceOptions;

  /// No description provided for @creditMethod.
  ///
  /// In ar, this message translates to:
  /// **'آجل / ذمم (Credit)'**
  String get creditMethod;

  /// No description provided for @warningCancelOrder.
  ///
  /// In ar, this message translates to:
  /// **'تحذير: إلغاء الطلب'**
  String get warningCancelOrder;

  /// No description provided for @confirmFinalDelete.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الحذف النهائي'**
  String get confirmFinalDelete;

  /// No description provided for @subtotalBeforeTax.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي (قبل الضريبة)'**
  String get subtotalBeforeTax;

  /// No description provided for @cancelOrderWarningMsg.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب سيؤدي إلى إرجاع المنتجات للمخزون، وخصم الأموال المدفوعة من الوردية الحالية، وعكس ديون العميل. هل أنت متأكد؟'**
  String get cancelOrderWarningMsg;

  /// No description provided for @unitPricePrefix.
  ///
  /// In ar, this message translates to:
  /// **'سعر الوحدة: '**
  String get unitPricePrefix;

  /// No description provided for @finalDeleteBtn.
  ///
  /// In ar, this message translates to:
  /// **'حذف نهائي'**
  String get finalDeleteBtn;

  /// No description provided for @itemsList.
  ///
  /// In ar, this message translates to:
  /// **'🛍️ قائمة الأصناف والمنتجات'**
  String get itemsList;

  /// No description provided for @confirmCancelInvoiceMsg.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من رغبتك في إلغاء هذه الفاتورة؟ سيتم إرجاع كميات الأصناف للمخزون تلقائياً.'**
  String get confirmCancelInvoiceMsg;

  /// No description provided for @orderCancelledStatus.
  ///
  /// In ar, this message translates to:
  /// **'❌ طلب ملغي'**
  String get orderCancelledStatus;

  /// No description provided for @cancelInvoiceBtn.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء فاتورة'**
  String get cancelInvoiceBtn;

  /// No description provided for @invoiceGrandTotal.
  ///
  /// In ar, this message translates to:
  /// **'المجموع النهائي للفاتورة'**
  String get invoiceGrandTotal;

  /// No description provided for @invoiceCancelledSuccessfully.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الفاتورة بنجاح وإرجاع المواد للمخزون'**
  String get invoiceCancelledSuccessfully;

  /// No description provided for @totalTax.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الضريبة'**
  String get totalTax;

  /// No description provided for @confirmCancelBtn.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الإلغاء'**
  String get confirmCancelBtn;

  /// No description provided for @goBackBtn.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get goBackBtn;

  /// No description provided for @yesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get yesterday;

  /// No description provided for @expensesDistribution.
  ///
  /// In ar, this message translates to:
  /// **'توزيع المصروفات'**
  String get expensesDistribution;

  /// No description provided for @preparingExcelReport.
  ///
  /// In ar, this message translates to:
  /// **'جاري تجهيز التقرير (إكسل)...'**
  String get preparingExcelReport;

  /// No description provided for @unitsSold.
  ///
  /// In ar, this message translates to:
  /// **'{quantity} وحدة مباعة'**
  String unitsSold(String quantity);

  /// No description provided for @oneWeek.
  ///
  /// In ar, this message translates to:
  /// **'أسبوع'**
  String get oneWeek;

  /// No description provided for @excelExportError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تصدير إكسل: {error}'**
  String excelExportError(String error);

  /// No description provided for @reportExtractionError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء استخراج التقرير'**
  String get reportExtractionError;

  /// No description provided for @oneMonth.
  ///
  /// In ar, this message translates to:
  /// **'شهر'**
  String get oneMonth;

  /// No description provided for @semiAnnual.
  ///
  /// In ar, this message translates to:
  /// **'نصف سنوي'**
  String get semiAnnual;

  /// No description provided for @oneYear.
  ///
  /// In ar, this message translates to:
  /// **'سنة'**
  String get oneYear;

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get today;

  /// No description provided for @preparingPdfReport.
  ///
  /// In ar, this message translates to:
  /// **'جاري تجهيز التقرير (PDF)...'**
  String get preparingPdfReport;

  /// No description provided for @twoDaysAgo.
  ///
  /// In ar, this message translates to:
  /// **'قبل يومين'**
  String get twoDaysAgo;

  /// No description provided for @noExpensesInPeriod.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مصروفات في هذه الفترة'**
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
  /// **'حول التطبيق'**
  String get aboutApp;

  /// No description provided for @databaseBackupText.
  ///
  /// In ar, this message translates to:
  /// **'نسخ احتياطي لقاعدة البيانات'**
  String get databaseBackupText;

  /// No description provided for @thermalPrinterText.
  ///
  /// In ar, this message translates to:
  /// **'الطابعة الحرارية'**
  String get thermalPrinterText;

  /// No description provided for @setupChecklistTitle.
  ///
  /// In ar, this message translates to:
  /// **'جهز متجرك للبيع'**
  String get setupChecklistTitle;

  /// No description provided for @setupStep1.
  ///
  /// In ar, this message translates to:
  /// **'أسس متجرك (أضف تصنيف)'**
  String get setupStep1;

  /// No description provided for @setupStep2.
  ///
  /// In ar, this message translates to:
  /// **'تجهيز الرفوف (أضف منتج)'**
  String get setupStep2;

  /// No description provided for @setupStep3.
  ///
  /// In ar, this message translates to:
  /// **'استلام العهدة (افتح وردية)'**
  String get setupStep3;

  /// No description provided for @setupStep4.
  ///
  /// In ar, this message translates to:
  /// **'أول غيث (أنشئ مبيعة)'**
  String get setupStep4;

  /// No description provided for @setupCompleted.
  ///
  /// In ar, this message translates to:
  /// **'أنت جاهز تماماً للبيع! 🎉'**
  String get setupCompleted;

  /// No description provided for @taxModeTitle.
  ///
  /// In ar, this message translates to:
  /// **'الضريبة'**
  String get taxModeTitle;

  /// No description provided for @taxModeStore.
  ///
  /// In ar, this message translates to:
  /// **'استخدام ضريبة المتجر'**
  String get taxModeStore;

  /// No description provided for @taxModeCustom.
  ///
  /// In ar, this message translates to:
  /// **'ضريبة مخصصة'**
  String get taxModeCustom;

  /// No description provided for @taxModeExempt.
  ///
  /// In ar, this message translates to:
  /// **'معفى من الضريبة'**
  String get taxModeExempt;

  /// No description provided for @businessOverview.
  ///
  /// In ar, this message translates to:
  /// **'نظرة شاملة'**
  String get businessOverview;

  /// No description provided for @last7Days.
  ///
  /// In ar, this message translates to:
  /// **'آخر 7 أيام'**
  String get last7Days;

  /// No description provided for @last30Days.
  ///
  /// In ar, this message translates to:
  /// **'آخر 30 يوم'**
  String get last30Days;

  /// No description provided for @custom.
  ///
  /// In ar, this message translates to:
  /// **'مخصص'**
  String get custom;

  /// No description provided for @costDataIncomplete.
  ///
  /// In ar, this message translates to:
  /// **'بيانات التكلفة غير مكتملة'**
  String get costDataIncomplete;

  /// No description provided for @branchPerformance.
  ///
  /// In ar, this message translates to:
  /// **'أداء الفروع'**
  String get branchPerformance;

  /// No description provided for @moneyPosition.
  ///
  /// In ar, this message translates to:
  /// **'الوضع المالي'**
  String get moneyPosition;

  /// No description provided for @customerReceivables.
  ///
  /// In ar, this message translates to:
  /// **'مستحقات العملاء'**
  String get customerReceivables;

  /// No description provided for @supplierPayables.
  ///
  /// In ar, this message translates to:
  /// **'مستحقات الموردين'**
  String get supplierPayables;

  /// No description provided for @inventoryHealth.
  ///
  /// In ar, this message translates to:
  /// **'حالة المخزون'**
  String get inventoryHealth;

  /// No description provided for @outOfStock.
  ///
  /// In ar, this message translates to:
  /// **'نفذت الكمية'**
  String get outOfStock;

  /// No description provided for @lowStock.
  ///
  /// In ar, this message translates to:
  /// **'مخزون منخفض'**
  String get lowStock;

  /// No description provided for @lowRawMaterials.
  ///
  /// In ar, this message translates to:
  /// **'مواد خام منخفضة'**
  String get lowRawMaterials;

  /// No description provided for @needsReorder.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج إعادة طلب'**
  String get needsReorder;

  /// No description provided for @shiftStatus.
  ///
  /// In ar, this message translates to:
  /// **'حالة الورديات'**
  String get shiftStatus;

  /// No description provided for @openShifts.
  ///
  /// In ar, this message translates to:
  /// **'ورديات مفتوحة'**
  String get openShifts;

  /// No description provided for @recentDiscrepancies.
  ///
  /// In ar, this message translates to:
  /// **'عجوزات حديثة'**
  String get recentDiscrepancies;

  /// No description provided for @attentionRequired.
  ///
  /// In ar, this message translates to:
  /// **'يتطلب الانتباه'**
  String get attentionRequired;

  /// No description provided for @actionCenter.
  ///
  /// In ar, this message translates to:
  /// **'مركز الإجراءات'**
  String get actionCenter;

  /// No description provided for @reorderCenter.
  ///
  /// In ar, this message translates to:
  /// **'مركز إعادة الطلب'**
  String get reorderCenter;

  /// No description provided for @dailySummaries.
  ///
  /// In ar, this message translates to:
  /// **'الملخصات اليومية'**
  String get dailySummaries;

  /// No description provided for @stocktake.
  ///
  /// In ar, this message translates to:
  /// **'جرد المخزون'**
  String get stocktake;
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
