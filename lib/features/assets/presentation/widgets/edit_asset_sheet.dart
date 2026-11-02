import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/persian_input.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../domain/entities/asset_entity.dart';
import '../../domain/repositories/asset_repository.dart';

/// Full edit sheet for an existing asset.
class EditAssetSheet extends StatefulWidget {
  final AssetEntity asset;

  const EditAssetSheet({super.key, required this.asset});

  static Future<void> show(BuildContext context, AssetEntity asset) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditAssetSheet(asset: asset),
    );
  }

  @override
  State<EditAssetSheet> createState() => _EditAssetSheetState();
}

class _EditAssetSheetState extends State<EditAssetSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitController;
  late final TextEditingController _costController;
  late final TextEditingController _valueController;
  late final TextEditingController _customTypeController;
  late final TextEditingController _notesController;
  late AssetCategory _category;
  late DateTime _purchaseDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    _nameController = TextEditingController(text: asset.name);
    _quantityController = TextEditingController(text: _trimNum(asset.quantity));
    _unitController = TextEditingController(text: asset.unit);
    _costController = TextEditingController(
      text: asset.costBasis.minorUnits.toString(),
    );
    _valueController = TextEditingController(
      text: asset.currentValue.minorUnits.toString(),
    );
    _customTypeController = TextEditingController(
      text: asset.customTypeName ?? '',
    );
    _notesController = TextEditingController(text: asset.notes ?? '');
    _category = asset.category;
    _purchaseDate = asset.purchaseDate;
  }

  static String _trimNum(double v) {
    final s = v.toStringAsFixed(v == v.truncateToDouble() ? 0 : 3);
    return s.endsWith('.000') ? s.substring(0, s.length - 4) : s;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _costController.dispose();
    _valueController.dispose();
    _customTypeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: now.subtract(const Duration(days: 365 * 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _purchaseDate = picked);
    }
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_saving) return;
    final name = _nameController.text.trim();
    final qty =
        double.tryParse(normalizeDecimalInput(_quantityController.text)) ?? 0;
    final costMinor =
        int.tryParse(normalizeNumericInput(_costController.text)) ?? 0;
    final valueMinor =
        int.tryParse(normalizeNumericInput(_valueController.text)) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isPersian
                ? 'نام دارایی را وارد کنید.'
                : 'Enter the asset name.',
          ),
        ),
      );
      return;
    }
    if (costMinor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isPersian
                ? 'بهای تمام‌شده را درست وارد کنید.'
                : 'Enter a valid cost basis.',
          ),
        ),
      );
      return;
    }
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isPersian
                ? 'مقدار را درست وارد کنید.'
                : 'Enter a valid quantity.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final old = widget.asset;
    final unit = _unitController.text.trim();
    final customType = _customTypeController.text.trim();
    final notes = _notesController.text.trim();

    final updated = AssetEntity(
      id: old.id,
      name: name,
      category: _category,
      customTypeName: _category == AssetCategory.other && customType.isNotEmpty
          ? customType
          : null,
      quantity: qty,
      unit: unit.isEmpty ? 'واحد' : unit,
      costBasis: Money.fromMinor(costMinor, old.costBasis.currency),
      currentValue: Money.fromMinor(
        valueMinor > 0 ? valueMinor : costMinor,
        old.currentValue.currency,
      ),
      purchaseDate: _purchaseDate,
      notes: notes.isEmpty ? null : notes,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: old.deletedAt,
    );

    final result = await sl<AssetRepository>().updateAsset(updated);
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
              AppSheetHeader(title: isFa ? 'ویرایش دارایی' : 'Edit Asset'),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<AssetCategory>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: isFa ? 'نوع دارایی' : 'Asset type',
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: AssetCategory.values.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat.titleFa));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_category == AssetCategory.other)
                TextField(
                  controller: _customTypeController,
                  decoration: InputDecoration(
                    labelText: isFa
                        ? 'نوع دلخواه (مثلاً فرش دستباف، طلای آب‌شده)'
                        : 'Custom type (e.g. handwoven carpet)',
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                  ),
                ),
              if (_category == AssetCategory.other)
                const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _nameController,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: isFa
                      ? 'نام دارایی (مثلاً سکه امامی)'
                      : 'Asset name',
                  prefixIcon: const Icon(Icons.label_outline_rounded),
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        PersianDigitsTextInputFormatter(enabled: isFa),
                      ],
                      decoration: InputDecoration(
                        labelText: isFa ? 'تعداد / مقدار' : 'Quantity',
                        prefixIcon: const Icon(Icons.numbers_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _unitController,
                      decoration: InputDecoration(
                        labelText: isFa ? 'واحد (گرم، عدد، سهم)' : 'Unit',
                        prefixIcon: const Icon(Icons.straighten_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _costController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  PersianThousandsSeparatorTextInputFormatter(enabled: isFa),
                ],
                decoration: InputDecoration(
                  labelText: isFa ? 'بهای تمام‌شده (خرید)' : 'Cost basis',
                  prefixIcon: const Icon(Icons.shopping_cart_outlined),
                  suffixText: isFa ? 'تومان' : '',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _valueController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  PersianThousandsSeparatorTextInputFormatter(enabled: isFa),
                ],
                decoration: InputDecoration(
                  labelText: isFa ? 'ارزش روز' : 'Current value',
                  prefixIcon: const Icon(Icons.trending_up_rounded),
                  suffixText: isFa ? 'تومان' : '',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(isFa ? 'تاریخ خرید' : 'Purchase date'),
                        ],
                      ),
                      Text(
                        AppDateFormatter.formatShort(
                          _purchaseDate,
                          locale: context.l10n.localeName,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.income,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _notesController,
                maxLines: 2,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: isFa ? 'یادداشت (اختیاری)' : 'Notes (optional)',
                  prefixIcon: const Icon(Icons.notes_outlined),
                  counterText: '',
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
