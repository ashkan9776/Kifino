import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('fa'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('fa', 'IR'),
    Locale('fa'),
    Locale('en'),
  ];

  bool get isPersian => locale.languageCode == 'fa';
  String get localeName => locale.languageCode;

  // Common UI Strings
  String get appName => isPersian ? 'کیفینو' : 'Kifino';
  String get appTagline =>
      isPersian ? 'سیستم عامل مالی شما' : 'Your Financial OS';
  String get confirm => isPersian ? 'تایید' : 'Confirm';
  String get cancel => isPersian ? 'انصراف' : 'Cancel';
  String get save => isPersian ? 'ذخیره' : 'Save';
  String get delete => isPersian ? 'حذف' : 'Delete';
  String get edit => isPersian ? 'ویرایش' : 'Edit';
  String get retry => isPersian ? 'تلاش مجدد' : 'Try Again';
  String get search => isPersian ? 'جستجو...' : 'Search...';
  String get undo => isPersian ? 'بازگردانی' : 'Undo';
  String get close => isPersian ? 'بستن' : 'Close';
  String get all => isPersian ? 'همه' : 'All';

  // Navigation
  String get navHome => isPersian ? 'خانه' : 'Home';
  String get navActivity => isPersian ? 'تراکنش‌ها' : 'Activity';
  String get navAnalytics => isPersian ? 'تحلیل' : 'Analytics';
  String get navBusiness => isPersian ? 'کسب‌وکار' : 'Business';
  String get navMore => isPersian ? 'بیشتر' : 'More';

  // Financial Terms
  String get netWorth => isPersian ? 'ارزش خالص دارایی' : 'Net Worth';
  String get totalBalance => isPersian ? 'موجودی کل' : 'Total Balance';
  String get income => isPersian ? 'درآمد' : 'Income';
  String get expense => isPersian ? 'هزینه' : 'Expense';
  String get transfer => isPersian ? 'انتقال' : 'Transfer';
  String get accounts => isPersian ? 'حساب‌ها' : 'Accounts';
  String get categories => isPersian ? 'دسته‌بندی‌ها' : 'Categories';
  String get budget => isPersian ? 'بودجه' : 'Budget';
  String get budgets => isPersian ? 'بودجه‌ها' : 'Budgets';
  String get debts => isPersian ? 'طلب و بدهی' : 'Debts & Loans';
  String get installments => isPersian ? 'اقساط' : 'Installments';
  String get checks => isPersian ? 'چک‌ها' : 'Checks';
  String get assets => isPersian ? 'دارایی‌ها' : 'Assets';
  String get invoices => isPersian ? 'فاکتورها' : 'Invoices';
  String get customers => isPersian ? 'مشتریان' : 'Customers';
  String get products => isPersian ? 'کالاها و خدمات' : 'Products & Stock';
  String get aiAssistant => isPersian ? 'دستیار هوشمند' : 'AI Assistant';

  // Dashboard Greetings & Widgets
  String greeting(String name) =>
      isPersian ? 'سلام، $name 👋' : 'Hello, $name 👋';
  String get financialHealth =>
      isPersian ? 'وضعیت مالی شما' : 'Financial Health';
  String get thisMonth => isPersian ? 'این ماه' : 'This Month';
  String get recentTransactions =>
      isPersian ? 'تراکنش‌های اخیر' : 'Recent Transactions';
  String get cashFlow => isPersian ? 'جریان نقدی' : 'Cash Flow';
  String get budgetAdherence =>
      isPersian ? 'پایبندی به بودجه' : 'Budget Adherence';
  String get noTransactionsYet =>
      isPersian ? 'هنوز تراکنشی ثبت نشده است' : 'No transactions recorded yet';
  String get noTransactionsDesc => isPersian
      ? 'مدیریت پول خود را با ثبت اولین تراکنش آغاز کنید.'
      : 'Start tracking your money by recording your first transaction.';
  String get addTransaction => isPersian ? 'ثبت تراکنش' : 'Add Transaction';
  String get newExpense => isPersian ? 'ثبت هزینه' : 'New Expense';
  String get newIncome => isPersian ? 'ثبت درآمد' : 'New Income';

  // Transaction Entry
  String get amount => isPersian ? 'مبلغ' : 'Amount';
  String get selectCategory =>
      isPersian ? 'انتخاب دسته‌بندی' : 'Select Category';
  String get selectAccount => isPersian ? 'انتخاب حساب' : 'Select Account';
  String get destinationAccount =>
      isPersian ? 'حساب مقصد' : 'Destination Account';
  String get note => isPersian ? 'یادداشت' : 'Note';
  String get notePlaceholder =>
      isPersian ? 'بابت چی بود؟' : 'What was this for?';
  String get tags => isPersian ? 'برچسب‌ها' : 'Tags';
  String get date => isPersian ? 'تاریخ' : 'Date';

  // Validation
  String get amountRequired => isPersian
      ? 'مبلغ باید بیشتر از صفر باشد'
      : 'Amount must be greater than zero';
  String get accountRequired =>
      isPersian ? 'لطفاً حساب را انتخاب کنید' : 'Please select an account';
  String get categoryRequired =>
      isPersian ? 'لطفاً دسته‌بندی را انتخاب کنید' : 'Please select a category';

  // Analytics & Budgets
  String get savingsRate => isPersian ? 'نرخ پس‌انداز' : 'Savings Rate';
  String get runway => isPersian ? 'تاب‌آوری مالی' : 'Runway';
  String get months => isPersian ? 'ماه' : 'Months';
  String get spent => isPersian ? 'مصرف شده' : 'Spent';
  String get remaining => isPersian ? 'باقیمانده' : 'Remaining';
  String get limit => isPersian ? 'سقف بودجه' : 'Limit';
  String get overBudget => isPersian ? 'فراتر از بودجه' : 'Over Budget';
  String get nearLimit => isPersian ? 'نزدیک به سقف' : 'Near Limit';
  String get onTrack => isPersian ? 'در بودجه' : 'On Track';
  String get categorySpending =>
      isPersian ? 'هزینه‌ها بر اساس دسته‌بندی' : 'Spending by Category';
  String get cashFlowTrend => isPersian ? 'روند جریان نقدی' : 'Cash Flow Trend';
  String get dailyAverage => isPersian ? 'میانگین روزانه' : 'Daily Average';
  String get netCashFlow => isPersian ? 'جریان نقدی خالص' : 'Net Cash Flow';
  String get periodThisMonth => isPersian ? 'این ماه' : 'This Month';
  String get periodLast3Months => isPersian ? '۳ ماه اخیر' : 'Last 3 Months';
  String get periodThisYear => isPersian ? 'امسال' : 'This Year';
  String get activeBudgets => isPersian ? 'بودجه‌های فعال' : 'Active Budgets';
  String get noBudgetsYet =>
      isPersian ? 'بودجه‌ای تعریف نشده است' : 'No active budgets';
  String get noBudgetsDesc => isPersian
      ? 'برای مدیریت بهتر هزینه‌ها، سقف بودجه تعیین کنید.'
      : 'Set budget limits to keep your expenses in check.';
  String get newBudget => isPersian ? 'بودجه جدید' : 'New Budget';
  String get budgetName => isPersian ? 'عنوان بودجه' : 'Budget Name';

  // Debts, Installments, Checks, Assets
  String get debtsAndLoans =>
      isPersian ? 'بدهی‌ها و مطالبات' : 'Debts & Receivables';
  String get payables => isPersian ? 'بدهی‌های من' : 'My Payables';
  String get receivables => isPersian ? 'طلب‌های من' : 'My Receivables';
  String get personName => isPersian ? 'طرف حساب / شخص' : 'Person Name';
  String get dueDate => isPersian ? 'سررسید' : 'Due Date';
  String get settled => isPersian ? 'تسویه شده' : 'Settled';
  String get unpaid => isPersian ? 'تسویه نشده' : 'Unpaid';
  String get checkNumber =>
      isPersian ? 'شماره چک / صیادی' : 'Check / Sayadi Number';
  String get bankName => isPersian ? 'نام بانک' : 'Bank Name';
  String get assetType => isPersian ? 'نوع دارایی' : 'Asset Type';
  String get currentValuation => isPersian ? 'ارزش روز' : 'Current Value';
  String get purchasePrice => isPersian ? 'قیمت خرید' : 'Purchase Price';
  String get profitLoss => isPersian ? 'سود / زیان' : 'Profit / Loss';

  // Small Business & Invoicing
  String get businessOverview =>
      isPersian ? 'نمای کلی کسب‌وکار' : 'Business Overview';
  String get salesInvoices => isPersian ? 'فاکتورهای فروش' : 'Sales Invoices';
  String get purchaseInvoices =>
      isPersian ? 'فاکتورهای خرید' : 'Purchase Invoices';
  String get inventoryStock => isPersian ? 'موجودی انبار' : 'Inventory Stock';
  String get newInvoice => isPersian ? 'صدور فاکتور جدید' : 'New Invoice';
  String get newCustomer => isPersian ? 'مشتری جدید' : 'New Customer';
  String get newProduct => isPersian ? 'کالای جدید' : 'New Product';
  String get printPdf => isPersian ? 'چاپ فاکتور PDF' : 'Print PDF Invoice';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['fa', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
