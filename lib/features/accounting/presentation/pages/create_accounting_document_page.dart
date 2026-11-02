import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/persian_input.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_money_text.dart';

import '../../../../core/widgets/app_date_picker.dart';
import '../../domain/entities/accounting_audit_entity.dart';
import '../../domain/entities/accounting_document_entity.dart';
import '../../domain/entities/accounting_subject_entity.dart';
import '../../domain/entities/accounting_transaction_entity.dart';
import '../../domain/repositories/accounting_repository.dart';
import '../bloc/accounting_document_bloc.dart';

class CreateAccountingDocumentPage extends StatefulWidget {
  const CreateAccountingDocumentPage({super.key});

  @override
  State<CreateAccountingDocumentPage> createState() =>
      _CreateAccountingDocumentPageState();
}

class _CreateAccountingDocumentPageState
    extends State<CreateAccountingDocumentPage> {
  final _titleController = TextEditingController(text: 'سند حسابداری دستی');
  DateTime _selectedDate = DateTime.now();

  List<AccountingSubjectEntity> _availableSubjects = [];
  bool _isLoadingSubjects = true;

  /// Active تفصیلی شناور ledgers (and their active values) for optional
  /// document tagging.
  List<DetailLedgerWithValues> _detailLedgers = [];
  final Map<String, String?> _selectedDetailValues = {};

  final List<_VoucherRowItem> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
    _loadDetailLedgers();
    // Start with 2 empty rows (Debit & Credit)
    _rows.add(_VoucherRowItem());
    _rows.add(_VoucherRowItem());
  }

  Future<void> _loadSubjects() async {
    final repo = getIt<AccountingRepository>();
    final subjects = await repo.getAllSubjects();
    setState(() {
      _availableSubjects = subjects;
      _isLoadingSubjects = false;
    });
  }

  Future<void> _loadDetailLedgers() async {
    try {
      final ledgers = await getIt<AccountingRepository>().getDetailLedgers();
      if (!mounted) return;
      setState(() {
        _detailLedgers = ledgers
            .where((l) => l.ledger.isActive)
            .map(
              (l) => DetailLedgerWithValues(
                ledger: l.ledger,
                values: l.values.where((v) => v.isActive).toList(),
              ),
            )
            .toList();
      });
    } catch (_) {
      // Detail tagging is optional — never block document creation on it.
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  int get _totalDebitMinor {
    int total = 0;
    for (final row in _rows) {
      total += row.debitAmount.minorUnits;
    }
    return total;
  }

  int get _totalCreditMinor {
    int total = 0;
    for (final row in _rows) {
      total += row.creditAmount.minorUnits;
    }
    return total;
  }

  bool get _isBalanced =>
      _totalDebitMinor == _totalCreditMinor && _totalDebitMinor > 0;

  int get _differenceMinor => (_totalDebitMinor - _totalCreditMinor).abs();

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final jalali = JalaliDate.fromDateTime(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ثبت سند حسابداری جدید'),
        centerTitle: true,
      ),
      body: _isLoadingSubjects
          ? const Center(child: CircularProgressIndicator())
          : BlocListener<AccountingDocumentBloc, AccountingDocumentState>(
              listener: (context, state) {
                if (state is AccountingDocumentOperationSuccess) {
                  context.pop();
                } else if (state is AccountingDocumentError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: colors.expense,
                    ),
                  );
                }
              },
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Header Card: Title and Date
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _titleController,
                                  decoration: const InputDecoration(
                                    labelText: 'شرح کلی سند',
                                    hintText:
                                        'مثال: پرداخت هزینه اجاره و شارژ دفتر',
                                    prefixIcon: Icon(
                                      Icons.description_outlined,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: () => _pickDate(context),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_month,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'تاریخ سند: ${TextNormalizer.toPersianDigits(jalali.day.toString())} ${jalali.monthName} ${TextNormalizer.toPersianDigits(jalali.year.toString())}',
                                          style: AppTypography.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'سطرهای سند (آرتیکل‌ها):',
                              style: AppTypography.titleSmall,
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _rows.add(_VoucherRowItem());
                                });
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('افزودن سطر'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Rows List
                        ...List.generate(_rows.length, (index) {
                          return _buildRowCard(index, colors);
                        }),

                        // Optional تفصیلی شناور tagging
                        if (_detailLedgers.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildDetailTagsSection(colors),
                        ],
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),

                  // Sticky Bottom Balance & Save Bar
                  _buildStickyBottomBar(colors),
                ],
              ),
            ),
    );
  }

  Widget _buildRowCard(int index, KifinoColorsExtension colors) {
    final row = _rows[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: colors.primary.withValues(alpha: 0.1),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickSubjectForRow(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_tree_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              row.selectedSubject != null
                                  ? row.selectedSubject!.formattedName
                                  : 'انتخاب سرفصل حسابداری...',
                              style: TextStyle(
                                color: row.selectedSubject != null
                                    ? colors.textPrimary
                                    : colors.textSecondary,
                                fontWeight: row.selectedSubject != null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_rows.length > 2)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _rows[index].dispose();
                        _rows.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.debitController,
                    decoration: const InputDecoration(
                      labelText: 'بدهکار',
                      hintText: '۰',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      PersianThousandsSeparatorTextInputFormatter(
                        enabled: true,
                      ),
                    ],
                    onChanged: (val) {
                      if (val.isNotEmpty) {
                        row.creditController.text = '';
                      }
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: row.creditController,
                    decoration: const InputDecoration(
                      labelText: 'بستانکار',
                      hintText: '۰',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      PersianThousandsSeparatorTextInputFormatter(
                        enabled: true,
                      ),
                    ],
                    onChanged: (val) {
                      if (val.isNotEmpty) {
                        row.debitController.text = '';
                      }
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: row.descController,
              decoration: const InputDecoration(
                labelText: 'شرح سطر آرتیکل',
                hintText: 'شرح اختیاری برای این سطر',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTagsSection(KifinoColorsExtension colors) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category_outlined, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('تفصیلی شناور', style: AppTypography.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'برچسب تحلیلی سند برای گزارش‌گیری به تفکیک مشتری، پروژه و... (اختیاری)',
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            ..._detailLedgers.map((l) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedDetailValues[l.ledger.id],
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: '${l.ledger.title} (اختیاری)',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('بدون تفصیلی'),
                    ),
                    ...l.values.map(
                      (v) => DropdownMenuItem<String>(
                        value: v.id,
                        child: Text(v.title, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (valueId) {
                    setState(
                      () => _selectedDetailValues[l.ledger.id] = valueId,
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar(KifinoColorsExtension colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, -3),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('جمع بدهکار: ', style: AppTypography.bodySmall),
                    AppMoneyText(
                      money: Money.fromMinor(_totalDebitMinor),
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('جمع بستانکار: ', style: AppTypography.bodySmall),
                    AppMoneyText(
                      money: Money.fromMinor(_totalCreditMinor),
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isBalanced
                          ? Icons.check_circle
                          : Icons.warning_amber_rounded,
                      color: _isBalanced ? colors.income : colors.expense,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isBalanced
                          ? 'سند کاملاً تراز است'
                          : 'اختلاف: ${Money.fromMinor(_differenceMinor).formatted}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isBalanced ? colors.income : colors.expense,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _saveDocument,
                  icon: const Icon(Icons.save),
                  label: const Text('ثبت سند'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _pickSubjectForRow(int rowIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final filtered = _availableSubjects.where((s) {
              final q = query.trim().toLowerCase();
              return q.isEmpty ||
                  s.name.toLowerCase().contains(q) ||
                  s.code.contains(q);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (_, scrollCtrl) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'انتخاب سرفصل حسابداری',
                        style: AppTypography.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'جستجوی سرفصل (نام یا کد)...',
                          prefixIcon: const Icon(Icons.search),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() => query = val);
                        },
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollCtrl,
                          itemCount: filtered.length,
                          itemBuilder: (c, i) {
                            final sub = filtered[i];
                            return ListTile(
                              dense: true,
                              title: Text(
                                sub.formattedName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${sub.level.titleFa} • ${sub.type.titleFa}',
                              ),
                              onTap: () {
                                setState(() {
                                  _rows[rowIndex].selectedSubject = sub;
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _saveDocument() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً شرح کلی سند را وارد کنید')),
      );
      return;
    }

    final validTransactions = <AccountingTransactionEntity>[];
    int order = 1;
    final now = DateTime.now();
    const uuid = Uuid();

    for (final row in _rows) {
      if (row.selectedSubject == null) continue;
      final deb = row.debitAmount;
      final cred = row.creditAmount;
      if (deb.minorUnits == 0 && cred.minorUnits == 0) continue;

      validTransactions.add(
        AccountingTransactionEntity(
          id: uuid.v4(),
          documentId: '',
          subjectId: row.selectedSubject!.id,
          subject: row.selectedSubject,
          debit: deb,
          credit: cred,
          description: row.descController.text.trim().isNotEmpty
              ? row.descController.text.trim()
              : title,
          rowOrder: order++,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (validTransactions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حداقل دو سطر آرتیکل معتبر لازم است')),
      );
      return;
    }

    final doc = AccountingDocumentEntity(
      id: '',
      number: 0,
      date: _selectedDate,
      title: title,
      status: _isBalanced ? DocumentStatus.approved : DocumentStatus.draft,
      isManual: true,
      approvedAt: _isBalanced ? now : null,
      transactions: validTransactions,
      createdAt: now,
      updatedAt: now,
    );

    final detailTags = <DocumentDetailTag>[];
    for (final entry in _selectedDetailValues.entries) {
      final valueId = entry.value;
      if (valueId == null || valueId.isEmpty) continue;
      detailTags.add(DocumentDetailTag(ledgerId: entry.key, valueId: valueId));
    }

    context.read<AccountingDocumentBloc>().add(
      CreateAccountingDocumentSubmitted(doc, details: detailTags),
    );
  }
}

class _VoucherRowItem {
  AccountingSubjectEntity? selectedSubject;
  final TextEditingController debitController = TextEditingController();
  final TextEditingController creditController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  Money get debitAmount {
    final val = TextNormalizer.parseMoneyInput(debitController.text) ?? 0;
    return Money.fromMinor(val);
  }

  Money get creditAmount {
    final val = TextNormalizer.parseMoneyInput(creditController.text) ?? 0;
    return Money.fromMinor(val);
  }

  void dispose() {
    debitController.dispose();
    creditController.dispose();
    descController.dispose();
  }
}
