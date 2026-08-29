import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('en'),
    Locale('ur')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'BizManager'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Retail & Wholesale ERP'**
  String get appSubtitle;

  /// No description provided for @common_ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get common_ok;

  /// No description provided for @common_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_cancel;

  /// No description provided for @common_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get common_save;

  /// No description provided for @common_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get common_delete;

  /// No description provided for @common_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get common_edit;

  /// No description provided for @common_add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get common_add;

  /// No description provided for @common_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get common_back;

  /// No description provided for @common_search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get common_search;

  /// No description provided for @common_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get common_loading;

  /// No description provided for @common_error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get common_error;

  /// No description provided for @common_success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get common_success;

  /// No description provided for @common_warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get common_warning;

  /// No description provided for @common_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get common_close;

  /// No description provided for @common_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get common_settings;

  /// No description provided for @common_logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get common_logout;

  /// No description provided for @auth_welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to BizManager'**
  String get auth_welcome;

  /// No description provided for @auth_enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get auth_enterPin;

  /// No description provided for @auth_confirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm your PIN'**
  String get auth_confirmPin;

  /// No description provided for @auth_pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get auth_pinMismatch;

  /// No description provided for @auth_invalidPin.
  ///
  /// In en, this message translates to:
  /// **'Invalid PIN'**
  String get auth_invalidPin;

  /// No description provided for @auth_pinTooShort.
  ///
  /// In en, this message translates to:
  /// **'PIN must be at least 4 digits'**
  String get auth_pinTooShort;

  /// No description provided for @auth_signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get auth_signIn;

  /// No description provided for @auth_createPin.
  ///
  /// In en, this message translates to:
  /// **'Create PIN'**
  String get auth_createPin;

  /// No description provided for @auth_biometric.
  ///
  /// In en, this message translates to:
  /// **'Biometric Login'**
  String get auth_biometric;

  /// No description provided for @auth_securityQuestion.
  ///
  /// In en, this message translates to:
  /// **'Security Question'**
  String get auth_securityQuestion;

  /// No description provided for @auth_securityAnswer.
  ///
  /// In en, this message translates to:
  /// **'Security Answer'**
  String get auth_securityAnswer;

  /// No description provided for @auth_forgotPin.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get auth_forgotPin;

  /// No description provided for @auth_useSecurityQuestion.
  ///
  /// In en, this message translates to:
  /// **'Use Security Question'**
  String get auth_useSecurityQuestion;

  /// No description provided for @dashboard_title.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard_title;

  /// No description provided for @dashboard_todaysSales.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Sales'**
  String get dashboard_todaysSales;

  /// No description provided for @dashboard_totalReceivable.
  ///
  /// In en, this message translates to:
  /// **'Total Receivable'**
  String get dashboard_totalReceivable;

  /// No description provided for @dashboard_totalExpenses.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Expenses'**
  String get dashboard_totalExpenses;

  /// No description provided for @dashboard_estimatedProfit.
  ///
  /// In en, this message translates to:
  /// **'Estimated Profit'**
  String get dashboard_estimatedProfit;

  /// No description provided for @dashboard_totalPurchase.
  ///
  /// In en, this message translates to:
  /// **'Total Purchase'**
  String get dashboard_totalPurchase;

  /// No description provided for @dashboard_lowStockProducts.
  ///
  /// In en, this message translates to:
  /// **'Low Stock Products'**
  String get dashboard_lowStockProducts;

  /// No description provided for @dashboard_recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get dashboard_recentTransactions;

  /// No description provided for @dashboard_quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get dashboard_quickActions;

  /// No description provided for @settings_title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_title;

  /// No description provided for @settings_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_language;

  /// No description provided for @settings_currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settings_currency;

  /// No description provided for @settings_dateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date Format'**
  String get settings_dateFormat;

  /// No description provided for @settings_biometric.
  ///
  /// In en, this message translates to:
  /// **'Biometric Login'**
  String get settings_biometric;

  /// No description provided for @settings_theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settings_theme;

  /// No description provided for @settings_about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settings_about;

  /// No description provided for @settings_version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settings_version;

  /// No description provided for @settings_backup.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settings_backup;

  /// No description provided for @settings_security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settings_security;

  /// No description provided for @settings_companyProfile.
  ///
  /// In en, this message translates to:
  /// **'Company Profile'**
  String get settings_companyProfile;

  /// No description provided for @company_name.
  ///
  /// In en, this message translates to:
  /// **'Company Name'**
  String get company_name;

  /// No description provided for @company_owner.
  ///
  /// In en, this message translates to:
  /// **'Owner Name'**
  String get company_owner;

  /// No description provided for @company_address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get company_address;

  /// No description provided for @company_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get company_phone;

  /// No description provided for @company_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get company_email;

  /// No description provided for @company_ntn.
  ///
  /// In en, this message translates to:
  /// **'NTN/GST'**
  String get company_ntn;

  /// No description provided for @company_currencyCode.
  ///
  /// In en, this message translates to:
  /// **'Currency Code'**
  String get company_currencyCode;

  /// No description provided for @company_currencySymbol.
  ///
  /// In en, this message translates to:
  /// **'Currency Symbol'**
  String get company_currencySymbol;

  /// No description provided for @company_decimalPlaces.
  ///
  /// In en, this message translates to:
  /// **'Decimal Places'**
  String get company_decimalPlaces;

  /// No description provided for @sales_title.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sales_title;

  /// No description provided for @sales_newSale.
  ///
  /// In en, this message translates to:
  /// **'New Sale'**
  String get sales_newSale;

  /// No description provided for @sales_invoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Invoice #'**
  String get sales_invoiceNumber;

  /// No description provided for @sales_customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get sales_customer;

  /// No description provided for @sales_product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get sales_product;

  /// No description provided for @sales_quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get sales_quantity;

  /// No description provided for @sales_price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get sales_price;

  /// No description provided for @sales_total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get sales_total;

  /// No description provided for @sales_discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get sales_discount;

  /// No description provided for @sales_tax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get sales_tax;

  /// No description provided for @sales_paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get sales_paid;

  /// No description provided for @sales_due.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get sales_due;

  /// No description provided for @sales_paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get sales_paymentMethod;

  /// No description provided for @sales_cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get sales_cash;

  /// No description provided for @sales_credit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get sales_credit;

  /// No description provided for @sales_cheque.
  ///
  /// In en, this message translates to:
  /// **'Cheque'**
  String get sales_cheque;

  /// No description provided for @sales_bank.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get sales_bank;

  /// No description provided for @purchase_title.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get purchase_title;

  /// No description provided for @purchase_newPurchase.
  ///
  /// In en, this message translates to:
  /// **'New Purchase'**
  String get purchase_newPurchase;

  /// No description provided for @purchase_supplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get purchase_supplier;

  /// No description provided for @purchase_invoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Invoice #'**
  String get purchase_invoiceNumber;

  /// No description provided for @expense_title.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expense_title;

  /// No description provided for @expense_category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get expense_category;

  /// No description provided for @expense_amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expense_amount;

  /// No description provided for @expense_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get expense_date;

  /// No description provided for @expense_description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get expense_description;

  /// No description provided for @customer_title.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customer_title;

  /// No description provided for @customer_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get customer_name;

  /// No description provided for @customer_mobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get customer_mobile;

  /// No description provided for @customer_address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get customer_address;

  /// No description provided for @customer_creditLimit.
  ///
  /// In en, this message translates to:
  /// **'Credit Limit'**
  String get customer_creditLimit;

  /// No description provided for @customer_balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get customer_balance;

  /// No description provided for @customer_addNew.
  ///
  /// In en, this message translates to:
  /// **'Add New Customer'**
  String get customer_addNew;

  /// No description provided for @product_title.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get product_title;

  /// No description provided for @product_name.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get product_name;

  /// No description provided for @product_code.
  ///
  /// In en, this message translates to:
  /// **'Product Code'**
  String get product_code;

  /// No description provided for @product_barcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get product_barcode;

  /// No description provided for @product_category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get product_category;

  /// No description provided for @product_price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get product_price;

  /// No description provided for @product_stock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get product_stock;

  /// No description provided for @product_addNew.
  ///
  /// In en, this message translates to:
  /// **'Add New Product'**
  String get product_addNew;

  /// No description provided for @validation_required.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get validation_required;

  /// No description provided for @validation_invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get validation_invalidEmail;

  /// No description provided for @validation_invalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number'**
  String get validation_invalidPhone;

  /// No description provided for @validation_minLength.
  ///
  /// In en, this message translates to:
  /// **'Minimum length is {min}'**
  String validation_minLength(int min);

  /// No description provided for @error_saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get error_saveFailed;

  /// No description provided for @error_loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get error_loadFailed;

  /// No description provided for @error_deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete'**
  String get error_deleteFailed;

  /// No description provided for @error_networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get error_networkError;

  /// No description provided for @error_databaseError.
  ///
  /// In en, this message translates to:
  /// **'Database error'**
  String get error_databaseError;

  /// No description provided for @message_saved.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get message_saved;

  /// No description provided for @message_deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted successfully'**
  String get message_deleted;

  /// No description provided for @message_updated.
  ///
  /// In en, this message translates to:
  /// **'Updated successfully'**
  String get message_updated;

  /// No description provided for @message_confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete?'**
  String get message_confirmDelete;

  /// No description provided for @message_noData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get message_noData;
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
      <String>['ar', 'en', 'ur'].contains(locale.languageCode);

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
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
