// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BizManager';

  @override
  String get appSubtitle => 'Retail & Wholesale ERP';

  @override
  String get common_ok => 'OK';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_save => 'Save';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_edit => 'Edit';

  @override
  String get common_add => 'Add';

  @override
  String get common_back => 'Back';

  @override
  String get common_search => 'Search';

  @override
  String get common_loading => 'Loading...';

  @override
  String get common_error => 'Error';

  @override
  String get common_success => 'Success';

  @override
  String get common_warning => 'Warning';

  @override
  String get common_close => 'Close';

  @override
  String get common_settings => 'Settings';

  @override
  String get common_logout => 'Logout';

  @override
  String get auth_welcome => 'Welcome to BizManager';

  @override
  String get auth_enterPin => 'Enter your PIN';

  @override
  String get auth_confirmPin => 'Confirm your PIN';

  @override
  String get auth_pinMismatch => 'PINs do not match';

  @override
  String get auth_invalidPin => 'Invalid PIN';

  @override
  String get auth_pinTooShort => 'PIN must be at least 4 digits';

  @override
  String get auth_signIn => 'Sign In';

  @override
  String get auth_createPin => 'Create PIN';

  @override
  String get auth_biometric => 'Biometric Login';

  @override
  String get auth_securityQuestion => 'Security Question';

  @override
  String get auth_securityAnswer => 'Security Answer';

  @override
  String get auth_forgotPin => 'Forgot PIN?';

  @override
  String get auth_useSecurityQuestion => 'Use Security Question';

  @override
  String get dashboard_title => 'Dashboard';

  @override
  String get dashboard_todaysSales => 'Today\'s Sales';

  @override
  String get dashboard_totalReceivable => 'Total Receivable';

  @override
  String get dashboard_totalExpenses => 'Today\'s Expenses';

  @override
  String get dashboard_estimatedProfit => 'Estimated Profit';

  @override
  String get dashboard_totalPurchase => 'Total Purchase';

  @override
  String get dashboard_lowStockProducts => 'Low Stock Products';

  @override
  String get dashboard_recentTransactions => 'Recent Transactions';

  @override
  String get dashboard_quickActions => 'Quick Actions';

  @override
  String get settings_title => 'Settings';

  @override
  String get settings_language => 'Language';

  @override
  String get settings_currency => 'Currency';

  @override
  String get settings_dateFormat => 'Date Format';

  @override
  String get settings_biometric => 'Biometric Login';

  @override
  String get settings_theme => 'Theme';

  @override
  String get settings_about => 'About';

  @override
  String get settings_version => 'Version';

  @override
  String get settings_backup => 'Backup & Restore';

  @override
  String get settings_security => 'Security';

  @override
  String get settings_companyProfile => 'Company Profile';

  @override
  String get company_name => 'Company Name';

  @override
  String get company_owner => 'Owner Name';

  @override
  String get company_address => 'Address';

  @override
  String get company_phone => 'Phone';

  @override
  String get company_email => 'Email';

  @override
  String get company_ntn => 'NTN/GST';

  @override
  String get company_currencyCode => 'Currency Code';

  @override
  String get company_currencySymbol => 'Currency Symbol';

  @override
  String get company_decimalPlaces => 'Decimal Places';

  @override
  String get sales_title => 'Sales';

  @override
  String get sales_newSale => 'New Sale';

  @override
  String get sales_invoiceNumber => 'Invoice #';

  @override
  String get sales_customer => 'Customer';

  @override
  String get sales_product => 'Product';

  @override
  String get sales_quantity => 'Quantity';

  @override
  String get sales_price => 'Price';

  @override
  String get sales_total => 'Total';

  @override
  String get sales_discount => 'Discount';

  @override
  String get sales_tax => 'Tax';

  @override
  String get sales_paid => 'Paid';

  @override
  String get sales_due => 'Due';

  @override
  String get sales_paymentMethod => 'Payment Method';

  @override
  String get sales_cash => 'Cash';

  @override
  String get sales_credit => 'Credit';

  @override
  String get sales_cheque => 'Cheque';

  @override
  String get sales_bank => 'Bank Transfer';

  @override
  String get purchase_title => 'Purchase';

  @override
  String get purchase_newPurchase => 'New Purchase';

  @override
  String get purchase_supplier => 'Supplier';

  @override
  String get purchase_invoiceNumber => 'Invoice #';

  @override
  String get expense_title => 'Expenses';

  @override
  String get expense_category => 'Category';

  @override
  String get expense_amount => 'Amount';

  @override
  String get expense_date => 'Date';

  @override
  String get expense_description => 'Description';

  @override
  String get customer_title => 'Customers';

  @override
  String get customer_name => 'Name';

  @override
  String get customer_mobile => 'Mobile';

  @override
  String get customer_address => 'Address';

  @override
  String get customer_creditLimit => 'Credit Limit';

  @override
  String get customer_balance => 'Balance';

  @override
  String get customer_addNew => 'Add New Customer';

  @override
  String get product_title => 'Products';

  @override
  String get product_name => 'Product Name';

  @override
  String get product_code => 'Product Code';

  @override
  String get product_barcode => 'Barcode';

  @override
  String get product_category => 'Category';

  @override
  String get product_price => 'Price';

  @override
  String get product_stock => 'Stock';

  @override
  String get product_addNew => 'Add New Product';

  @override
  String get validation_required => 'This field is required';

  @override
  String get validation_invalidEmail => 'Invalid email address';

  @override
  String get validation_invalidPhone => 'Invalid phone number';

  @override
  String validation_minLength(int min) {
    return 'Minimum length is $min';
  }

  @override
  String get error_saveFailed => 'Failed to save';

  @override
  String get error_loadFailed => 'Failed to load';

  @override
  String get error_deleteFailed => 'Failed to delete';

  @override
  String get error_networkError => 'Network error';

  @override
  String get error_databaseError => 'Database error';

  @override
  String get message_saved => 'Saved successfully';

  @override
  String get message_deleted => 'Deleted successfully';

  @override
  String get message_updated => 'Updated successfully';

  @override
  String get message_confirmDelete => 'Are you sure you want to delete?';

  @override
  String get message_noData => 'No data available';
}
