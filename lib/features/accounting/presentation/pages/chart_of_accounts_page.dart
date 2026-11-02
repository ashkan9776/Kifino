import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/accounting_subject_entity.dart';
import '../bloc/chart_of_accounts_cubit.dart';

class ChartOfAccountsPage extends StatefulWidget {
  const ChartOfAccountsPage({super.key});

  @override
  State<ChartOfAccountsPage> createState() => _ChartOfAccountsPageState();
}

class _ChartOfAccountsPageState extends State<ChartOfAccountsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ChartOfAccountsCubit>().loadChartOfAccounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('کدینگ و سرفصل‌های حسابداری'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'جستجوی نام یا کد حسابداری (مثال: 011 یا صندوق)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<ChartOfAccountsCubit>().search('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) {
                context.read<ChartOfAccountsCubit>().search(val);
              },
            ),
          ),

          // Level Filter Chips
          BlocBuilder<ChartOfAccountsCubit, ChartOfAccountsState>(
            builder: (context, state) {
              final selectedLevel = (state is ChartOfAccountsLoaded)
                  ? state.selectedLevel
                  : null;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    _buildFilterChip('همه سطوح', null, selectedLevel, colors),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'حساب‌های کل',
                      AccountingSubjectLevel.kol,
                      selectedLevel,
                      colors,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'حساب‌های معین',
                      AccountingSubjectLevel.moein,
                      selectedLevel,
                      colors,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'حساب‌های تفصیلی',
                      AccountingSubjectLevel.tafsili,
                      selectedLevel,
                      colors,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // Main Accounts List
          Expanded(
            child: BlocBuilder<ChartOfAccountsCubit, ChartOfAccountsState>(
              builder: (context, state) {
                if (state is ChartOfAccountsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is ChartOfAccountsLoaded) {
                  final subjects = state.filteredSubjects;
                  if (subjects.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_tree_outlined,
                            size: 48,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'سرفصلی یافت نشد',
                            style: AppTypography.titleMedium,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      final subject = subjects[index];
                      return _buildSubjectTile(context, subject, colors);
                    },
                  );
                }

                if (state is ChartOfAccountsError) {
                  return Center(child: Text(state.message));
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSubjectDialog(context),
        tooltip: 'افزودن حساب جدید',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    AccountingSubjectLevel? level,
    AccountingSubjectLevel? current,
    KifinoColorsExtension colors,
  ) {
    final isSelected = current == level;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        context.read<ChartOfAccountsCubit>().filterByLevel(level);
      },
      selectedColor: colors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? colors.primary : colors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildSubjectTile(
    BuildContext context,
    AccountingSubjectEntity subject,
    KifinoColorsExtension colors,
  ) {
    Color levelColor;
    switch (subject.level) {
      case AccountingSubjectLevel.group:
        levelColor = Colors.brown;
        break;
      case AccountingSubjectLevel.kol:
        levelColor = Colors.indigo;
        break;
      case AccountingSubjectLevel.moein:
        levelColor = Colors.teal;
        break;
      case AccountingSubjectLevel.tafsili:
        levelColor = Colors.purple;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: levelColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  subject.formattedCode,
                  style: TextStyle(
                    color: levelColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            subject.level.titleFa,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: subject.isPermanent
                                ? Colors.blue.withValues(alpha: 0.1)
                                : Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            subject.isPermanent
                                ? 'دائمی (ترازنامه‌ای)'
                                : 'موقت (سود و زیانی)',
                            style: TextStyle(
                              fontSize: 10,
                              color: subject.isPermanent
                                  ? Colors.blue.shade700
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: subject.type == AccountingSubjectType.debtor
                      ? Colors.red.withValues(alpha: 0.1)
                      : subject.type == AccountingSubjectType.creditor
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subject.type == AccountingSubjectType.debtor
                      ? 'بدهکار'
                      : subject.type == AccountingSubjectType.creditor
                      ? 'بستانکار'
                      : 'شناور',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: subject.type == AccountingSubjectType.debtor
                        ? Colors.red
                        : subject.type == AccountingSubjectType.creditor
                        ? Colors.green
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSubjectDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    AccountingSubjectType type = AccountingSubjectType.both;
    AccountingSubjectLevel level = AccountingSubjectLevel.moein;
    bool isPermanent = true;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('تعریف سرفصل حسابداری جدید'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'کد حساب (مثال: 011003)',
                      hintText: 'کد سرفصل',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'نام سرفصل',
                      hintText: 'مثال: صندوق فروشگاه شماره ۲',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AccountingSubjectLevel>(
                    initialValue: level,
                    decoration: const InputDecoration(labelText: 'سطح حساب'),
                    items: AccountingSubjectLevel.values.map((l) {
                      return DropdownMenuItem(value: l, child: Text(l.titleFa));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => level = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AccountingSubjectType>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'ماهیت حساب'),
                    items: AccountingSubjectType.values.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t.titleFa));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => type = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('حساب دائمی (ترازنامه‌ای)'),
                    subtitle: Text(
                      isPermanent
                          ? 'مانده به سال بعد منتقل می‌شود'
                          : 'حساب موقت سود و زیانی',
                    ),
                    value: isPermanent,
                    onChanged: (val) => setDialogState(() => isPermanent = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('انصراف'),
              ),
              ElevatedButton(
                onPressed: () {
                  final code = codeCtrl.text.trim();
                  final name = nameCtrl.text.trim();
                  if (code.isEmpty || name.isEmpty) return;

                  final now = DateTime.now();
                  final newSubject = AccountingSubjectEntity(
                    id: '',
                    code: code,
                    name: name,
                    type: type,
                    level: level,
                    isPermanent: isPermanent,
                    createdAt: now,
                    updatedAt: now,
                  );

                  context.read<ChartOfAccountsCubit>().addSubject(newSubject);
                  Navigator.pop(dialogCtx);
                },
                child: const Text('ثبت سرفصل'),
              ),
            ],
          );
        },
      ),
    );
  }
}
