// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'BizManager';

  @override
  String get appSubtitle => 'نظام المبيعات والشراء';

  @override
  String get common_ok => 'موافق';

  @override
  String get common_cancel => 'إلغاء';

  @override
  String get common_save => 'حفظ';

  @override
  String get common_delete => 'حذف';

  @override
  String get common_edit => 'تعديل';

  @override
  String get common_add => 'إضافة';

  @override
  String get common_back => 'رجوع';

  @override
  String get common_search => 'بحث';

  @override
  String get common_loading => 'جاري التحميل...';

  @override
  String get common_error => 'خطأ';

  @override
  String get common_success => 'نجح';

  @override
  String get common_warning => 'تحذير';

  @override
  String get common_close => 'إغلاق';

  @override
  String get common_settings => 'الإعدادات';

  @override
  String get common_logout => 'تسجيل الخروج';

  @override
  String get auth_welcome => 'أهلا وسهلا بك في BizManager';

  @override
  String get auth_enterPin => 'أدخل رمزك';

  @override
  String get auth_confirmPin => 'أعد إدخال رمزك';

  @override
  String get auth_pinMismatch => 'الرموز غير متطابقة';

  @override
  String get auth_invalidPin => 'رمز غير صحيح';

  @override
  String get auth_pinTooShort => 'يجب أن يكون الرمز من 4 أرقام على الأقل';

  @override
  String get auth_signIn => 'دخول';

  @override
  String get auth_createPin => 'إنشاء رمز';

  @override
  String get auth_biometric => 'دخول بيومتري';

  @override
  String get auth_securityQuestion => 'سؤال الأمان';

  @override
  String get auth_securityAnswer => 'إجابة الأمان';

  @override
  String get auth_forgotPin => 'هل نسيت الرمز؟';

  @override
  String get auth_useSecurityQuestion => 'استخدم سؤال الأمان';

  @override
  String get dashboard_title => 'لوحة التحكم';

  @override
  String get dashboard_todaysSales => 'مبيعات اليوم';

  @override
  String get dashboard_totalReceivable => 'إجمالي المستحقات';

  @override
  String get dashboard_totalExpenses => 'إجمالي المصاريف اليومية';

  @override
  String get dashboard_estimatedProfit => 'الربح المتوقع';

  @override
  String get dashboard_totalPurchase => 'إجمالي المشتريات';

  @override
  String get dashboard_lowStockProducts => 'المنتجات قليلة المخزون';

  @override
  String get dashboard_recentTransactions => 'المعاملات الأخيرة';

  @override
  String get dashboard_quickActions => 'الإجراءات السريعة';

  @override
  String get settings_title => 'الإعدادات';

  @override
  String get settings_language => 'اللغة';

  @override
  String get settings_currency => 'العملة';

  @override
  String get settings_dateFormat => 'صيغة التاريخ';

  @override
  String get settings_biometric => 'دخول بيومتري';

  @override
  String get settings_theme => 'المظهر';

  @override
  String get settings_about => 'حول';

  @override
  String get settings_version => 'الإصدار';

  @override
  String get settings_backup => 'النسخ الاحتياطي والاستعادة';

  @override
  String get settings_security => 'الأمان';

  @override
  String get settings_companyProfile => 'ملف الشركة';

  @override
  String get company_name => 'اسم الشركة';

  @override
  String get company_owner => 'اسم المالك';

  @override
  String get company_address => 'العنوان';

  @override
  String get company_phone => 'الهاتف';

  @override
  String get company_email => 'البريد الإلكتروني';

  @override
  String get company_ntn => 'الرقم الضريبي';

  @override
  String get company_currencyCode => 'رمز العملة';

  @override
  String get company_currencySymbol => 'رمز العملة';

  @override
  String get company_decimalPlaces => 'عدد الكسور العشرية';

  @override
  String get sales_title => 'المبيعات';

  @override
  String get sales_newSale => 'عملية بيع جديدة';

  @override
  String get sales_invoiceNumber => 'رقم الفاتورة';

  @override
  String get sales_customer => 'العميل';

  @override
  String get sales_product => 'المنتج';

  @override
  String get sales_quantity => 'الكمية';

  @override
  String get sales_price => 'السعر';

  @override
  String get sales_total => 'الإجمالي';

  @override
  String get sales_discount => 'الخصم';

  @override
  String get sales_tax => 'الضريبة';

  @override
  String get sales_paid => 'مدفوع';

  @override
  String get sales_due => 'مستحق';

  @override
  String get sales_paymentMethod => 'طريقة الدفع';

  @override
  String get sales_cash => 'نقد';

  @override
  String get sales_credit => 'ائتمان';

  @override
  String get sales_cheque => 'شيك';

  @override
  String get sales_bank => 'تحويل بنكي';

  @override
  String get purchase_title => 'المشتريات';

  @override
  String get purchase_newPurchase => 'عملية شراء جديدة';

  @override
  String get purchase_supplier => 'المورد';

  @override
  String get purchase_invoiceNumber => 'رقم الفاتورة';

  @override
  String get expense_title => 'المصاريف';

  @override
  String get expense_category => 'الفئة';

  @override
  String get expense_amount => 'المبلغ';

  @override
  String get expense_date => 'التاريخ';

  @override
  String get expense_description => 'الوصف';

  @override
  String get customer_title => 'العملاء';

  @override
  String get customer_name => 'الاسم';

  @override
  String get customer_mobile => 'الهاتف المحمول';

  @override
  String get customer_address => 'العنوان';

  @override
  String get customer_creditLimit => 'حد الائتمان';

  @override
  String get customer_balance => 'الرصيد';

  @override
  String get customer_addNew => 'إضافة عميل جديد';

  @override
  String get product_title => 'المنتجات';

  @override
  String get product_name => 'اسم المنتج';

  @override
  String get product_code => 'رمز المنتج';

  @override
  String get product_barcode => 'الباركود';

  @override
  String get product_category => 'الفئة';

  @override
  String get product_price => 'السعر';

  @override
  String get product_stock => 'المخزون';

  @override
  String get product_addNew => 'إضافة منتج جديد';

  @override
  String get validation_required => 'هذا الحقل مطلوب';

  @override
  String get validation_invalidEmail => 'عنوان بريد إلكتروني غير صحيح';

  @override
  String get validation_invalidPhone => 'رقم هاتف غير صحيح';

  @override
  String validation_minLength(int min) {
    return 'الحد الأدنى للطول هو $min';
  }

  @override
  String get error_saveFailed => 'فشل الحفظ';

  @override
  String get error_loadFailed => 'فشل التحميل';

  @override
  String get error_deleteFailed => 'فشل الحذف';

  @override
  String get error_networkError => 'خطأ في الشبكة';

  @override
  String get error_databaseError => 'خطأ في قاعدة البيانات';

  @override
  String get message_saved => 'تم الحفظ بنجاح';

  @override
  String get message_deleted => 'تم الحذف بنجاح';

  @override
  String get message_updated => 'تم التحديث بنجاح';

  @override
  String get message_confirmDelete => 'هل أنت متأكد أنك تريد الحذف؟';

  @override
  String get message_noData => 'لا توجد بيانات متاحة';
}
