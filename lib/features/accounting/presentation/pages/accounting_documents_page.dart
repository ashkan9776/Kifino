import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../domain/entities/accounting_document_entity.dart';
import '../bloc/accounting_document_bloc.dart';
import '../services/accounting_voucher_pdf_generator.dart';

class AccountingDocumentsPage extends StatefulWidget {
  const AccountingDocumentsPage({super.key});

  @override
  State<AccountingDocumentsPage> createState() => _AccountingDocumentsPageState();
}

class _AccountingDocumentsPageState extends State<AccountingDocumentsPage> {
  DocumentStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    context.read<AccountingDocumentBloc>().add(const LoadAccountingDocuments());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('اسناد حسابداری (Vouchers)'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildStatusFilterChip('همه اسناد', null, colors),
                const SizedBox(width: 8),
                _buildStatusFilterChip('تأیید شده', DocumentStatus.approved, colors),
                const SizedBox(width: 8),
                _buildStatusFilterChip('پیش‌نویس / موقت', DocumentStatus.draft, colors),
                const SizedBox(width: 8),
                _buildStatusFilterChip('ثبت قطعی', DocumentStatus.posted, colors),
              ],
            ),
          ),
          const Divider(height: 1),

          // Documents List
          Expanded(
            child: BlocConsumer<AccountingDocumentBloc, AccountingDocumentState>(
              listener: (context, state) {
                if (state is AccountingDocumentOperationSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message)),
                  );
                } else if (state is AccountingDocumentError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: colors.expense,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is AccountingDocumentLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is AccountingDocumentLoaded) {
                  final docs = state.documents;
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 56, color: colors.textSecondary),
                          const SizedBox(height: 12),
                          Text('سند حسابداری یافت نشد', style: AppTypography.titleMedium),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => context.push('/accounting/documents/create'),
                            icon: const Icon(Icons.add),
                            label: const Text('ثبت سند جدید'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      return _buildDocumentCard(context, doc, colors);
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/accounting/documents/create'),
        icon: const Icon(Icons.add),
        label: const Text('سند جدید'),
      ),
    );
  }

  Widget _buildStatusFilterChip(String label, DocumentStatus? status, KifinoColorsExtension colors) {
    final isSelected = _selectedStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedStatus = status);
        context.read<AccountingDocumentBloc>().add(
              LoadAccountingDocuments(status: status),
            );
      },
      selectedColor: colors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? colors.primary : colors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, AccountingDocumentEntity doc, KifinoColorsExtension colors) {
    final jalali = JalaliDate.fromDateTime(doc.date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => _showDocumentDetails(context, doc, colors),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'سند #${TextNormalizer.toPersianDigits(doc.number.toString())}',
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: doc.isManual
                              ? Colors.purple.withValues(alpha: 0.1)
                              : Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          doc.isManual ? 'دستی' : 'خودکار',
                          style: TextStyle(
                            fontSize: 10,
                            color: doc.isManual ? Colors.purple : Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: doc.isBalanced
                              ? colors.income.withValues(alpha: 0.12)
                              : colors.expense.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              doc.isBalanced ? Icons.check : Icons.close,
                              size: 12,
                              color: doc.isBalanced ? colors.income : colors.expense,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              doc.isBalanced ? 'تراز' : 'ناتراز',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: doc.isBalanced ? colors.income : colors.expense,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: doc.status == DocumentStatus.approved
                              ? colors.income.withValues(alpha: 0.15)
                              : colors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          doc.status.titleFa,
                          style: TextStyle(
                            fontSize: 10,
                            color: doc.status == DocumentStatus.approved
                                ? colors.income
                                : colors.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                doc.title,
                style: AppTypography.titleMedium.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${TextNormalizer.toPersianDigits(jalali.day.toString())} ${jalali.monthName} ${TextNormalizer.toPersianDigits(jalali.year.toString())} • ${TextNormalizer.toPersianDigits(doc.transactions.length.toString())} آرتیکل',
                    style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                  Row(
                    children: [
                      Text('مبلغ سند: ', style: AppTypography.bodySmall),
                      AppMoneyText(
                        money: doc.totalDebit,
                        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocumentDetails(BuildContext context, AccountingDocumentEntity doc, KifinoColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final jalali = JalaliDate.fromDateTime(doc.date);
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('سند حسابداری #${TextNormalizer.toPersianDigits(doc.number.toString())}', style: AppTypography.titleLarge),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.print_outlined),
                            tooltip: 'چاپ و صدور PDF سند',
                            onPressed: () {
                              AccountingVoucherPdfGenerator.printOrShareVoucher(document: doc);
                            },
                          ),
                          if (doc.status == DocumentStatus.draft)
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                context
                                    .read<AccountingDocumentBloc>()
                                    .add(ApproveAccountingDocumentSubmitted(doc.id));
                              },
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('تأیید سند'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.income,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('شرح: ${doc.title}', style: AppTypography.bodyMedium),
                  Text(
                    'تاریخ سند: ${TextNormalizer.toPersianDigits(jalali.day.toString())} ${jalali.monthName} ${TextNormalizer.toPersianDigits(jalali.year.toString())}',
                    style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                  const Divider(height: 24),

                  Text('آرتیکل‌های سند (سطرهای بدهکار و بستانکار):',
                      style: AppTypography.titleSmall),
                  const SizedBox(height: 8),

                  ...doc.transactions.map((tx) {
                    final isDeb = tx.debit.minorUnits > 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDeb
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isDeb ? 'بدهکار' : 'بستانکار',
                              style: TextStyle(
                                color: isDeb ? Colors.red : Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.subject != null ? tx.subject!.formattedName : tx.subjectId,
                                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (tx.description.isNotEmpty)
                                  Text(
                                    tx.description,
                                    style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                          AppMoneyText(
                            money: isDeb ? tx.debit : tx.credit,
                            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }),

                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('مجموع بدهکار:'),
                          AppMoneyText(money: doc.totalDebit),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('مجموع بستانکار:'),
                          AppMoneyText(money: doc.totalCredit),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            AccountingVoucherPdfGenerator.printOrShareVoucher(document: doc);
                          },
                          icon: const Icon(Icons.print_rounded, size: 18),
                          label: const Text('چاپ رسمی سند (PDF)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context
                              .read<AccountingDocumentBloc>()
                              .add(DeleteAccountingDocumentSubmitted(doc.id));
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('حذف', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
