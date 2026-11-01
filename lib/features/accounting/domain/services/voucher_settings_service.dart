import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Configurable counterpart accounts for automatic accounting vouchers
/// (Phase 2). Stored as JSON in SharedPreferences — company-level config,
/// not user data; defaults match the standard Iranian chart of accounts so
/// the feature works out of the box.
class VoucherAccountSettings {
  final String salesCode; // کریدور فروش (sale invoice credit)
  final String receivableCode; // بدهکار حساب‌های دریافتنی
  final String vatOutputCode; // مالیات بر ارزش افزوده فروش
  final String discountSalesCode; // تخفیف فروش
  final String inventoryCode; // موجودی کالا (sale credit)
  final String purchaseCode; // بدهکار خرید (purchase invoice debit)
  final String payableCode; // بستانکاران (purchase credit)
  final String vatInputCode; // مالیات خرید
  final String purchaseDiscountCode; // تخفیف خرید
  // Cheque accounting codes
  final String notesReceivableCode; // اسناد دریافتنی نزد صندوق (013001)
  final String notesInCollectionCode; // اسناد در جریان وصول (014001)
  final String notesPayableCode; // اسناد پرداختنی (020001)
  final String bankCode; // موجودی بانک (010)

  const VoucherAccountSettings({
    this.salesCode = '060001',
    this.receivableCode = '012001',
    this.vatOutputCode = '023001',
    this.discountSalesCode = '061001',
    this.inventoryCode = '015002',
    this.purchaseCode = '060002',
    this.payableCode = '023003',
    this.vatInputCode = '018001',
    this.purchaseDiscountCode = '066001',
    this.notesReceivableCode = '013001',
    this.notesInCollectionCode = '014001',
    this.notesPayableCode = '020001',
    this.bankCode = '010',
  });

  static const VoucherAccountSettings defaults = VoucherAccountSettings();

  VoucherAccountSettings copyWith({
    String? salesCode,
    String? receivableCode,
    String? vatOutputCode,
    String? discountSalesCode,
    String? inventoryCode,
    String? purchaseCode,
    String? payableCode,
    String? vatInputCode,
    String? purchaseDiscountCode,
    String? notesReceivableCode,
    String? notesInCollectionCode,
    String? notesPayableCode,
    String? bankCode,
  }) {
    return VoucherAccountSettings(
      salesCode: salesCode ?? this.salesCode,
      receivableCode: receivableCode ?? this.receivableCode,
      vatOutputCode: vatOutputCode ?? this.vatOutputCode,
      discountSalesCode: discountSalesCode ?? this.discountSalesCode,
      inventoryCode: inventoryCode ?? this.inventoryCode,
      purchaseCode: purchaseCode ?? this.purchaseCode,
      payableCode: payableCode ?? this.payableCode,
      vatInputCode: vatInputCode ?? this.vatInputCode,
      purchaseDiscountCode: purchaseDiscountCode ?? this.purchaseDiscountCode,
      notesReceivableCode: notesReceivableCode ?? this.notesReceivableCode,
      notesInCollectionCode:
          notesInCollectionCode ?? this.notesInCollectionCode,
      notesPayableCode: notesPayableCode ?? this.notesPayableCode,
      bankCode: bankCode ?? this.bankCode,
    );
  }

  Map<String, String> toMap() => {
    'salesCode': salesCode,
    'receivableCode': receivableCode,
    'vatOutputCode': vatOutputCode,
    'discountSalesCode': discountSalesCode,
    'inventoryCode': inventoryCode,
    'purchaseCode': purchaseCode,
    'payableCode': payableCode,
    'vatInputCode': vatInputCode,
    'purchaseDiscountCode': purchaseDiscountCode,
    'notesReceivableCode': notesReceivableCode,
    'notesInCollectionCode': notesInCollectionCode,
    'notesPayableCode': notesPayableCode,
    'bankCode': bankCode,
  };

  factory VoucherAccountSettings.fromMap(Map<String, dynamic> map) {
    const d = defaults;
    return VoucherAccountSettings(
      salesCode: map['salesCode'] as String? ?? d.salesCode,
      receivableCode: map['receivableCode'] as String? ?? d.receivableCode,
      vatOutputCode: map['vatOutputCode'] as String? ?? d.vatOutputCode,
      discountSalesCode:
          map['discountSalesCode'] as String? ?? d.discountSalesCode,
      inventoryCode: map['inventoryCode'] as String? ?? d.inventoryCode,
      purchaseCode: map['purchaseCode'] as String? ?? d.purchaseCode,
      payableCode: map['payableCode'] as String? ?? d.payableCode,
      vatInputCode: map['vatInputCode'] as String? ?? d.vatInputCode,
      purchaseDiscountCode:
          map['purchaseDiscountCode'] as String? ?? d.purchaseDiscountCode,
      notesReceivableCode:
          map['notesReceivableCode'] as String? ?? d.notesReceivableCode,
      notesInCollectionCode:
          map['notesInCollectionCode'] as String? ?? d.notesInCollectionCode,
      notesPayableCode:
          map['notesPayableCode'] as String? ?? d.notesPayableCode,
      bankCode: map['bankCode'] as String? ?? d.bankCode,
    );
  }

  String encode() => jsonEncode(toMap());

  static VoucherAccountSettings decode(String raw) {
    try {
      return VoucherAccountSettings.fromMap(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return defaults;
    }
  }
}

/// Persists [VoucherAccountSettings] in SharedPreferences.
class VoucherSettingsService {
  static const String _key = 'accounting_voucher_account_settings';

  final SharedPreferences prefs;

  const VoucherSettingsService(this.prefs);

  VoucherAccountSettings load() {
    final raw = prefs.getString(_key);
    if (raw == null) return VoucherAccountSettings.defaults;
    return VoucherAccountSettings.decode(raw);
  }

  Future<void> save(VoucherAccountSettings settings) =>
      prefs.setString(_key, settings.encode());
}
