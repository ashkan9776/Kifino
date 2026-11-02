import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/persian_input.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/business_repository.dart';

/// Edit sheet for an existing product. Stock is deliberately NOT editable
/// here — stock changes only happen through «تغییر موجودی» (adjustStock),
/// which keeps the کاردکس (inventory log) consistent.
class EditProductSheet extends StatefulWidget {
  final ProductEntity product;

  const EditProductSheet({super.key, required this.product});

  static Future<void> show(BuildContext context, ProductEntity product) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProductSheet(product: product),
    );
  }

  @override
  State<EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends State<EditProductSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _unitController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _thresholdController;
  bool _saving = false;

  /// Plain (Persian-digit aware) text for a quantity-like double.
  String _qtyText(double value) {
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return TextNormalizer.auto(text);
  }

  @override
  void initState() {
    super.initState();
    final isFa = isFaLocale(context);
    final p = widget.product;
    _nameController = TextEditingController(text: p.name);
    _skuController = TextEditingController(text: p.sku ?? '');
    _unitController = TextEditingController(text: p.unit);
    _purchasePriceController = TextEditingController(
      text: formatNumberWithSeparators(
        p.purchasePrice.minorUnits,
        toPersian: isFa,
      ),
    );
    _sellingPriceController = TextEditingController(
      text: formatNumberWithSeparators(
        p.sellingPrice.minorUnits,
        toPersian: isFa,
      ),
    );
    _thresholdController = TextEditingController(
      text: _qtyText(p.lowStockThreshold),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _unitController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final isFa = l10n.isPersian;
    if (_saving) return;

    final name = _nameController.text.trim();
    final pPrice =
        int.tryParse(normalizeNumericInput(_purchasePriceController.text)) ?? 0;
    final sPrice =
        int.tryParse(normalizeNumericInput(_sellingPriceController.text)) ?? 0;

    if (name.isEmpty || sPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFa
                ? 'نام کالا و قیمت فروش را کامل کنید.'
                : 'Fill in the product name and selling price.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final old = widget.product;
    final cur = Currency.fromCode(AppConstants.defaultCurrencyCode);
    final sku = _skuController.text.trim();
    final unit = _unitController.text.trim();
    final threshold =
        double.tryParse(normalizeDecimalInput(_thresholdController.text)) ??
        old.lowStockThreshold;

    // currentStock is untouched — stock only changes via adjustStock.
    final updated = ProductEntity(
      id: old.id,
      name: name,
      sku: sku.isEmpty ? null : sku,
      barcode: old.barcode,
      description: old.description,
      unit: unit.isEmpty ? old.unit : unit,
      secondaryUnit: old.secondaryUnit,
      conversionFactor: old.conversionFactor,
      purchasePrice: Money.fromMinor(pPrice, cur),
      sellingPrice: Money.fromMinor(sPrice, cur),
      currentStock: old.currentStock,
      lowStockThreshold: threshold,
      supplierId: old.supplierId,
      supplierName: old.supplierName,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: old.deletedAt,
    );

    final result = await sl<BusinessRepository>().updateProduct(updated);
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.of(context).pop(),
      onFailure: (failure) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isFa = context.l10n.isPersian;

    return AppBottomSheet(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSheetHeader(title: isFa ? 'ویرایش کالا' : 'Edit Product'),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${isFa ? 'موجودی فعلی انبار' : 'Current stock'}: ${_qtyText(widget.product.currentStock)} ${widget.product.unit}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkSubtext
                      : AppColors.lightSubtext,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _nameController,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: isFa ? 'نام کالا یا خدمت' : 'Product name',
                  prefixIcon: const Icon(Icons.shopping_bag_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _skuController,
                      decoration: InputDecoration(
                        labelText: isFa ? 'کد کالا (SKU)' : 'SKU',
                        prefixIcon: const Icon(Icons.qr_code_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _unitController,
                      decoration: InputDecoration(
                        labelText: isFa ? 'واحد' : 'Unit',
                        prefixIcon: const Icon(Icons.straighten_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _purchasePriceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        PersianThousandsSeparatorTextInputFormatter(
                          enabled: isFa,
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: isFa ? 'قیمت خرید (ریال)' : 'Purchase price',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _sellingPriceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        PersianThousandsSeparatorTextInputFormatter(
                          enabled: isFa,
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: isFa ? 'قیمت فروش (ریال)' : 'Selling price',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _thresholdController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  PersianDigitsTextInputFormatter(enabled: isFa),
                ],
                decoration: InputDecoration(
                  labelText: isFa
                      ? 'حداقل موجودی هشدار'
                      : 'Low-stock threshold',
                  prefixIcon: const Icon(Icons.warning_amber_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: isFa ? 'ذخیره تغییرات' : 'Save changes',
                isLoading: _saving,
                onPressed: _saving ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
