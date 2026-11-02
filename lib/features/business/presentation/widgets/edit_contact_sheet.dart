import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/utils/persian_input.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/repositories/business_repository.dart';

/// Edit sheet for an existing contact (side of business). Outstanding
/// balance is repo-managed and is never touched here.
class EditContactSheet extends StatefulWidget {
  final ContactEntity contact;

  const EditContactSheet({super.key, required this.contact});

  static Future<void> show(BuildContext context, ContactEntity contact) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditContactSheet(contact: contact),
    );
  }

  @override
  State<EditContactSheet> createState() => _EditContactSheetState();
}

class _EditContactSheetState extends State<EditContactSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _companyController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late ContactType _selectedType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    _nameController = TextEditingController(text: contact.name);
    _companyController = TextEditingController(text: contact.companyName ?? '');
    _phoneController = TextEditingController(text: contact.phone ?? '');
    _emailController = TextEditingController(text: contact.email ?? '');
    _selectedType = contact.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_saving) return;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isPersian
                ? 'نام مخاطب را وارد کنید.'
                : 'Enter the contact name.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final old = widget.contact;
    final phone = _phoneController.text.trim();
    final company = _companyController.text.trim();
    final email = _emailController.text.trim();

    // Built via the constructor (not copyWith) so cleared optional fields
    // (company, phone, email) actually persist as null.
    final updated = ContactEntity(
      id: old.id,
      name: _nameController.text.trim(),
      companyName: company.isEmpty ? null : company,
      type: _selectedType,
      phone: phone.isEmpty ? null : phone,
      email: email.isEmpty ? null : email,
      address: old.address,
      taxNumber: old.taxNumber,
      outstandingBalance: old.outstandingBalance,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
      deletedAt: old.deletedAt,
    );

    final result = await sl<BusinessRepository>().updateContact(updated);
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
              AppSheetHeader(title: isFa ? 'ویرایش مخاطب' : 'Edit Contact'),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _nameController,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: isFa ? 'نام و نام خانوادگی' : 'Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _companyController,
                decoration: InputDecoration(
                  labelText: isFa
                      ? 'نام شرکت یا فروشگاه (اختیاری)'
                      : 'Company (optional)',
                  prefixIcon: const Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  PersianDigitsTextInputFormatter(enabled: isFa),
                ],
                decoration: InputDecoration(
                  labelText: isFa ? 'شماره تماس' : 'Phone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: isFa ? 'ایمیل (اختیاری)' : 'Email (optional)',
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<ContactType>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  labelText: isFa ? 'نوع مخاطب' : 'Contact type',
                ),
                items: ContactType.values
                    .map(
                      (t) => DropdownMenuItem(value: t, child: Text(t.titleFa)),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
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
