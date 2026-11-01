import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/design_system/components/financial/app_status_badge.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/persian_input.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../../core/widgets/app_skeleton.dart';

import '../../../../core/widgets/app_date_picker.dart';import '../../../accounts/presentation/bloc/accounts_bloc.dart';
import '../../domain/entities/check_entity.dart';
import '../bloc/check_bloc.dart';
import '../widgets/check_status_history_sheet.dart';

class ChecksPage extends StatefulWidget {
  const ChecksPage({super.key});

  @override
  State<ChecksPage> createState() => _ChecksPageState();

  // ----------------------------------------------------
  // STATUS SEMANTICS (badges, menu, confirmations)
  // ----------------------------------------------------

  /// (tone, icon) per status — pending=warning, cleared=success,
  /// bounced=danger, transferred=info, cancelled=neutral.
  static (AppStatusTone, IconData) _statusStyle(CheckStatus status) =>
      switch (status) {
        CheckStatus.pending => (AppStatusTone.warning, Icons.schedule_rounded),
        CheckStatus.cleared => (
          AppStatusTone.success,
          Icons.check_circle_rounded,
        ),
        CheckStatus.bounced => (AppStatusTone.danger, Icons.cancel_rounded),
        CheckStatus.transferred => (
          AppStatusTone.info,
          Icons.swap_horiz_rounded,
        ),
        CheckStatus.cancelled => (AppStatusTone.neutral, Icons.block_rounded),
      };

  /// Display order of the status menu; the current status is filtered out.
  static const List<CheckStatus> _statusMenuOrder = [
    CheckStatus.cleared,
    CheckStatus.transferred,
    CheckStatus.bounced,
    CheckStatus.cancelled,
    CheckStatus.pending,
  ];

  /// Menu entry: action phrase + one-line Persian explanation.
  static ({String title, String desc}) _statusMenuEntry(
    CheckStatus status,
    bool isFa,
  ) =>
      switch (status) {
        CheckStatus.cleared => (
          title: isFa ? 'وصول شد' : 'Mark as cleared',
          desc: isFa
              ? 'مبلغ چک واریز و سند حسابداری صادر می‌شود.'
              : 'The amount is deposited and an accounting voucher is issued.',
        ),
        CheckStatus.transferred => (
          title: isFa ? 'واگذار شد' : 'Transfer to bank',
          desc: isFa
              ? 'چک به بانک سپرده می‌شود و سند صادر می‌شود.'
              : 'The check is deposited at the bank and a voucher is issued.',
        ),
        CheckStatus.bounced => (
          title: isFa ? 'برگشت خورد' : 'Mark as bounced',
          desc: isFa
              ? 'چک به دلیل کسری موجودی برگشت می‌خورد.'
              : 'The check bounces due to insufficient funds.',
        ),
        CheckStatus.cancelled => (
          title: isFa ? 'باطل شد' : 'Cancel check',
          desc: isFa
              ? 'چک از جریان خارج می‌شود.'
              : 'The check is taken out of circulation.',
        ),
        CheckStatus.pending => (
          title: isFa ? 'در انتظار وصول' : 'Back to pending',
          desc: isFa
              ? 'چک به حالت در جریان برمی‌گردد.'
              : 'The check returns to the pending state.',
        ),
      };

  /// Consequence text for the confirmation dialog. [accountName] is the
  /// linked account display name (falls back to the check's bank).
  static String _consequenceText(
    CheckStatus target,
    String accountName,
    bool isFa,
  ) =>
      switch (target) {
        CheckStatus.cleared => isFa
            ? 'مبلغ چک به حساب «$accountName» واریز و سند حسابداری صادر می‌شود.'
            : 'The check amount is deposited into "$accountName" and an accounting voucher is issued.',
        CheckStatus.transferred => isFa
            ? 'چک به بانک سپرده می‌شود و سند صادر می‌شود.'
            : 'The check is deposited at the bank and a voucher is issued.',
        CheckStatus.bounced => isFa
            ? 'اگر چک قبلاً وصول/واگذار شده بود، سند آن باطل و اثر مالی برگردانده می‌شود.'
            : 'If the check was previously cleared or transferred, its voucher is voided and the financial effect is reverted.',
        CheckStatus.cancelled => isFa
            ? 'چک باطل می‌شود. اثر مالی قبلی برگردانده می‌شود.'
            : 'The check is cancelled. Any previous financial effect is reverted.',
        CheckStatus.pending => isFa
            ? 'چک به حالت «در انتظار وصول» برمی‌گردد.'
            : 'The check returns to the pending state.',
      };

  /// Failures are Persian already; only the framework wrapper needs stripping.
  static String _cleanFailureMessage(String raw) {
    var msg = raw.trim();
    const prefix = 'Bad state: ';
    if (msg.startsWith(prefix)) msg = msg.substring(prefix.length).trim();
    return msg;
  }
}

class _ChecksPageState extends State<ChecksPage> {
  int _selectedFilter = 0; // 0: All, 1: Issued, 2: Received

  void _showAddCheckDialog(BuildContext context) {
    final l10n = context.l10n;
    final numberController = TextEditingController();
    final sayadiController = TextEditingController();
    final bankController = TextEditingController();
    final partyController = TextEditingController();
    final amountController = TextEditingController();
    CheckType selectedType = _selectedFilter == 1 ? CheckType.issued : CheckType.received;
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return BlocBuilder<AccountsBloc, AccountsState>(
          builder: (context, accState) {
            String? selectedAccountId;
            if (accState is AccountsLoaded && accState.accounts.isNotEmpty) {
              selectedAccountId = accState.accounts.first.id;
            }

            return StatefulBuilder(
              builder: (context, setModalState) {
                return AppBottomSheet(
                  child: Container(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
                      top: AppSpacing.lg,
                      bottom: AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppSheetHeader(
                            title: l10n.isPersian ? 'ثبت چک صیادی جدید' : 'New Sayadi Check',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SegmentedButton<CheckType>(
                            segments: [
                              ButtonSegment(value: CheckType.received, label: Text(l10n.isPersian ? 'دریافتی' : 'Received')),
                              ButtonSegment(value: CheckType.issued, label: Text(l10n.isPersian ? 'صادره' : 'Issued')),
                            ],
                            selected: {selectedType},
                            onSelectionChanged: (val) {
                              setModalState(() => selectedType = val.first);
                            },
                            showSelectedIcon: false,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: partyController,
                            decoration: InputDecoration(
                              labelText: l10n.personName,
                              prefixIcon: const Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              PersianThousandsSeparatorTextInputFormatter(enabled: isFaLocale(context)),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.amount,
                              prefixIcon: const Icon(Icons.payments_outlined),
                              suffixText: l10n.isPersian ? 'تومان' : '',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: bankController,
                            decoration: InputDecoration(
                              labelText: l10n.bankName,
                              prefixIcon: const Icon(Icons.account_balance_rounded),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: numberController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              PersianDigitsTextInputFormatter(enabled: isFaLocale(context)),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.checkNumber,
                              prefixIcon: const Icon(Icons.confirmation_number_outlined),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: sayadiController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              PersianDigitsTextInputFormatter(enabled: isFaLocale(context)),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.isPersian ? 'شناسه صیادی (۱۶ رقمی)' : 'Sayadi ID (16 digits)',
                              prefixIcon: const Icon(Icons.qr_code_rounded),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          // Due Date Picker
                          InkWell(
                            onTap: () async {
                              final now = DateTime.now();
                              final picked = await showAppDatePicker(
                                context: context,
                                initialDate: dueDate,
                                firstDate: now.subtract(const Duration(days: 365)),
                                lastDate: now.add(const Duration(days: 3650)),
                              );
                              if (picked != null) {
                                setModalState(() => dueDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_month_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text(l10n.isPersian ? 'تاریخ سررسید چک' : 'Due date'),
                                    ],
                                  ),
                                  Text(
                                    AppDateFormatter.format(dueDate, locale: l10n.localeName),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.income,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (accState is AccountsLoaded && accState.accounts.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            DropdownButtonFormField<String>(
                              initialValue: selectedAccountId,
                              decoration: InputDecoration(
                                labelText: l10n.isPersian ? 'حساب بانکی متصل' : 'Linked Account',
                                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                              ),
                              items: accState.accounts.map((acc) {
                                return DropdownMenuItem(
                                  value: acc.id,
                                  child: Text('${acc.name} (${acc.bankName ?? ""})'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedAccountId = val);
                              },
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            label: l10n.save,
                            onPressed: () {
                              final party = partyController.text.trim();
                              final bank = bankController.text.trim();
                              final number = numberController.text.trim();
                              final amountVal = int.tryParse(normalizeNumericInput(amountController.text)) ?? 0;

                              if (party.isNotEmpty && amountVal > 0 && number.isNotEmpty) {
                                final now = DateTime.now();
                                context.read<CheckBloc>().add(
                                      CheckCreateSubmitted(
                                        CheckEntity(
                                          id: '',
                                          checkNumber: number,
                                          sayadiId: sayadiController.text.trim().isNotEmpty ? sayadiController.text.trim() : null,
                                          bankName: bank.isNotEmpty ? bank : 'بانک ملی',
                                          type: selectedType,
                                          amount: Money.fromMinor(amountVal, Currency.irr),
                                          partyName: party,
                                          dueDate: dueDate,
                                          accountId: selectedAccountId,
                                          createdAt: now,
                                          updatedAt: now,
                                        ),
                                      ),
                                    );
                                Navigator.pop(bottomSheetContext);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------
  // STATUS MENU + CONFIRMATION
  // ----------------------------------------------------

  /// Bottom sheet listing every valid target status with a one-line
  /// explanation; each pick goes through a consequence-aware confirm dialog.
  void _showStatusMenu(BuildContext context, CheckEntity check) {
    final l10n = context.l10n;
    final isFa = l10n.isPersian;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final targets =
        ChecksPage._statusMenuOrder.where((s) => s != check.status).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AppBottomSheet(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSheetHeader(
                  title: isFa ? 'تغییر وضعیت چک' : 'Change Check Status',
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${isFa ? 'وضعیت فعلی' : 'Current status'}: ${check.status.titleFa}'
                  '${isFa ? ' — چک ' : ' — check #'}${TextNormalizer.auto(check.checkNumber)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: targets.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final target = targets[index];
                      final entry = ChecksPage._statusMenuEntry(target, isFa);
                      final (tone, icon) = ChecksPage._statusStyle(target);

                      return InkWell(
                        borderRadius: AppSpacing.borderRadiusSm,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _confirmStatusChange(context, check, target);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm + 2,
                          ),
                          decoration: BoxDecoration(
                            color: (isDark
                                    ? AppColors.darkSurface
                                    : AppColors.lightSurfaceVariant)
                                .withValues(alpha: 0.55),
                            borderRadius: AppSpacing.borderRadiusSm,
                          ),
                          child: Row(
                            children: [
                              _ToneIcon(tone: tone, icon: icon),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.title,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      entry.desc,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        color: isDark
                                            ? AppColors.darkSubtext
                                            : AppColors.lightSubtext,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Icon(
                                Icons.chevron_left_rounded,
                                size: 18,
                                color: isDark
                                    ? AppColors.darkSubtext
                                    : AppColors.lightSubtext,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Confirm dialog spelling out the money/voucher consequence of the pick.
  /// Leaving «cleared» always warns that the previous financial effect is
  /// reverted (symmetric balance reconciliation).
  Future<void> _confirmStatusChange(
    BuildContext context,
    CheckEntity check,
    CheckStatus target,
  ) async {
    final l10n = context.l10n;
    final isFa = l10n.isPersian;
    final theme = Theme.of(context);

    // Resolve the linked account display name for the «وصول شد» text.
    var accountName = check.bankName;
    final accState = context.read<AccountsBloc>().state;
    if (accState is AccountsLoaded && check.accountId != null) {
      final account = accState.accounts
          .where((a) => a.id == check.accountId)
          .firstOrNull;
      if (account != null) accountName = account.name;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isFa ? 'تغییر وضعیت چک' : 'Change check status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ChecksPage._consequenceText(target, accountName, isFa)),
            if (check.isCleared) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: AppSpacing.borderRadiusSm,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isFa
                            ? 'اثر مالی قبلی برگردانده خواهد شد.'
                            : 'The previous financial effect will be reverted.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.confirm,
              style: TextStyle(
                color: (target == CheckStatus.bounced ||
                        target == CheckStatus.cancelled)
                    ? AppColors.danger
                    : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<CheckBloc>().add(
            CheckStatusUpdated(id: check.id, status: target),
          );
    }
  }

  // ----------------------------------------------------
  // COUNTDOWN CHIP (display-only)
  // ----------------------------------------------------

  ({String label, Color color, IconData icon}) _countdown(
    CheckEntity check,
    bool isFa,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      check.dueDate.year,
      check.dueDate.month,
      check.dueDate.day,
    );
    final days = due.difference(today).inDays;

    if (days == 0) {
      return (
        label: isFa ? 'امروز' : 'Due today',
        color: AppColors.warning,
        icon: Icons.today_rounded,
      );
    }
    if (days > 0) {
      return (
        label: isFa
            ? '${TextNormalizer.auto('$days')} روز مانده'
            : '$days days left',
        color: AppColors.primary,
        icon: Icons.schedule_rounded,
      );
    }
    return (
      label: isFa
          ? '${TextNormalizer.auto('${-days}')} روز گذشته'
          : '${-days} days overdue',
      color: AppColors.danger,
      icon: Icons.error_outline_rounded,
    );
  }

  // ----------------------------------------------------
  // SUMMARY CARD (per type: pending vs cleared, count + sum)
  // ----------------------------------------------------

  Widget _buildSummaryCard(BuildContext context, CheckLoaded state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final isFa = l10n.isPersian;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    Widget typeBlock(CheckType type) {
      final isReceived = type == CheckType.received;
      final typeColor = isReceived ? AppColors.income : AppColors.expense;
      final typeChecks =
          state.checks.where((c) => !c.isDeleted && c.type == type);
      final pendingList = typeChecks.where((c) => c.isPending);
      final clearedList = typeChecks.where((c) => c.isCleared);
      final pendingSum = Money.fromMinor(
        pendingList.fold<int>(0, (sum, c) => sum + c.amount.minorUnits),
        Currency.irr,
      );
      final clearedSum = Money.fromMinor(
        clearedList.fold<int>(0, (sum, c) => sum + c.amount.minorUnits),
        Currency.irr,
      );

      Widget statCell({
        required String label,
        required int count,
        required Money sum,
      }) {
        return Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFa
                    ? '$label · ${TextNormalizer.auto('$count')} فقره'
                    : '$label · $count checks',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              AppMoneyText(
                money: sum,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: typeColor,
                ),
              ),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReceived
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                size: 14,
                color: typeColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isReceived
                      ? (isFa ? 'چک‌های دریافتی' : 'Received checks')
                      : (isFa ? 'چک‌های صادره' : 'Issued checks'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              statCell(
                label: isFa ? 'در انتظار وصول' : 'Pending',
                count: pendingList.length,
                sum: pendingSum,
              ),
              Container(width: 1, height: 32, color: borderColor),
              const SizedBox(width: AppSpacing.md),
              statCell(
                label: isFa ? 'پاس‌شده' : 'Cleared',
                count: clearedList.length,
                sum: clearedSum,
              ),
            ],
          ),
        ],
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          typeBlock(CheckType.received),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Container(height: 1, color: borderColor),
          ),
          typeBlock(CheckType.issued),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // CHECK CARD
  // ----------------------------------------------------

  Widget _buildCheckCard(BuildContext context, CheckEntity check) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final isFa = l10n.isPersian;

    final isReceived = check.type == CheckType.received;
    final typeColor = isReceived ? AppColors.income : AppColors.expense;
    final countdown = _countdown(check, isFa);
    // Display-only overdue flag: past due date while still pending. The DB
    // is never written from here.
    final isOverdue = check.isPending && countdown.color == AppColors.danger;
    final (statusTone, statusIcon) = ChecksPage._statusStyle(check.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        // Danger-tinted border for overdue pending checks — display only.
        borderColor:
            isOverdue ? AppColors.danger.withValues(alpha: 0.45) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Party + bank/number on the left, amount + type badge on the
            // right. Title block flexes so long party names never overflow.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: typeColor.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.account_balance_rounded,
                    size: 18,
                    color: typeColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        check.partyName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${check.bankName} · ${isFa ? 'شماره' : 'No.'}: ${TextNormalizer.auto(check.checkNumber)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.lightSubtext,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (check.sayadiId != null &&
                          check.sayadiId!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${isFa ? 'شناسه صیادی' : 'Sayadi ID'}: ${TextNormalizer.auto(check.sayadiId!)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppMoneyText(
                      money: check.amount,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _typeBadge(check.type, isFa),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Status + due date + countdown — Wrap keeps it overflow-safe.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppStatusBadge(
                  label: check.status.titleFa,
                  icon: statusIcon,
                  tone: statusTone,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 12,
                      color: isOverdue
                          ? AppColors.danger
                          : (isDark
                              ? AppColors.darkSubtext
                              : AppColors.lightSubtext),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isFa ? 'سررسید' : 'Due'}: ${AppDateFormatter.formatShort(check.dueDate, locale: l10n.localeName)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isOverdue
                            ? AppColors.danger
                            : (isDark
                                ? AppColors.darkSubtext
                                : AppColors.lightSubtext),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                // Countdown chip only while the check is still in play —
                // red means past due AND still pending.
                if (check.isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: countdown.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(countdown.icon, size: 12, color: countdown.color),
                        const SizedBox(width: 4),
                        Text(
                          countdown.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: countdown.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // Overflow-safe action row: wraps instead of clipping.
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: 0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _showStatusMenu(context, check),
                  icon: const Icon(Icons.published_with_changes_rounded,
                      size: 16),
                  label: Text(isFa ? 'تغییر وضعیت' : 'Change status'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      CheckStatusHistorySheet.show(context, check),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: Text(isFa ? 'تاریخچه وضعیت' : 'Status history'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBadge(CheckType type, bool isFa) {
    final isReceived = type == CheckType.received;
    final color = isReceived ? AppColors.income : AppColors.expense;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isReceived ? Icons.south_west_rounded : Icons.north_east_rounded,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            isFa
                ? (isReceived ? 'دریافتی' : 'صادره')
                : (isReceived ? 'Received' : 'Issued'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // PAGE
  // ----------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocListener<CheckBloc, CheckState>(
      listener: (context, state) {
        if (state is CheckFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ChecksPage._cleanFailureMessage(state.message)),
            ),
          );
        }
      },
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          top: false,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.checks),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showAddCheckDialog(context),
              child: const Icon(Icons.add),
            ),
            body: BlocBuilder<CheckBloc, CheckState>(
              builder: (context, state) {
                if (state is CheckLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        AppSkeleton(height: 150, borderRadius: AppSpacing.borderRadiusLg),
                        SizedBox(height: AppSpacing.md),
                        AppSkeleton(height: 80, borderRadius: AppSpacing.borderRadiusMd),
                      ],
                    ),
                  );
                }

                if (state is! CheckLoaded) {
                  return AppEmptyState(
                    icon: Icons.fact_check_outlined,
                    title: l10n.checks,
                    description: l10n.isPersian
                        ? 'مدیریت و ثبت چک‌های صیادی صادره و دریافتی.'
                        : 'Track your issued and received Sayadi checks.',
                  );
                }

                final filteredChecks = state.checks.where((c) {
                  if (_selectedFilter == 1) return c.type == CheckType.issued;
                  if (_selectedFilter == 2) return c.type == CheckType.received;
                  return true;
                }).toList();

                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    // Summary: per type, pending vs cleared (count + sum).
                    _buildSummaryCard(context, state),
                    const SizedBox(height: AppSpacing.md),

                    // Filter Segments
                    SegmentedButton<int>(
                      segments: [
                        ButtonSegment(value: 0, label: Text(l10n.all)),
                        ButtonSegment(value: 1, label: Text(l10n.isPersian ? 'صادره' : 'Issued')),
                        ButtonSegment(value: 2, label: Text(l10n.isPersian ? 'دریافتی' : 'Received')),
                      ],
                      selected: {_selectedFilter},
                      onSelectionChanged: (val) {
                        setState(() => _selectedFilter = val.first);
                      },
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    if (filteredChecks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: AppEmptyState(
                          icon: Icons.fact_check_outlined,
                          title: l10n.isPersian ? 'چکی ثبت نشده است' : 'No checks found',
                          description: l10n.isPersian
                              ? 'برای ثبت چک صیادی، دکمه + را لمس کنید.'
                              : 'Tap + to register a check.',
                        ),
                      )
                    else
                      ...filteredChecks.map(
                        (check) => _buildCheckCard(context, check),
                      ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Small tinted icon square used by the status menu rows.
class _ToneIcon extends StatelessWidget {
  final AppStatusTone tone;
  final IconData icon;

  const _ToneIcon({required this.tone, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (color, bg) = switch ((tone, isDark)) {
      (AppStatusTone.success, false) => (const Color(0xFF25C997), const Color(0xFFE7FAF3)),
      (AppStatusTone.success, true) => (const Color(0xFF39E6A5), const Color(0xFF0B2E24)),
      (AppStatusTone.warning, false) => (const Color(0xFFFFB547), const Color(0xFFFFF4E0)),
      (AppStatusTone.warning, true) => (const Color(0xFFFFCA58), const Color(0xFF33230A)),
      (AppStatusTone.danger, false) => (const Color(0xFFFF5C6C), const Color(0xFFFFECEE)),
      (AppStatusTone.danger, true) => (const Color(0xFFFF7A87), const Color(0xFF3A1218)),
      (AppStatusTone.info, false) => (const Color(0xFF4C9AFF), const Color(0xFFEAF3FF)),
      (AppStatusTone.info, true) => (const Color(0xFF4C9AFF), const Color(0xFF0E2036)),
      (AppStatusTone.neutral, false) => (const Color(0xFF687386), const Color(0xFFF1F5F9)),
      (AppStatusTone.neutral, true) => (const Color(0xFF94A3B8), const Color(0xFF12243A)),
    };

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
