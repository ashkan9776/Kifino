import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/design_system/tokens/colors.dart';
import '../../../../core/design_system/tokens/motion.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/parsed_transaction_draft.dart';
import '../bloc/ai_assistant_bloc.dart';
import '../bloc/ai_assistant_event.dart';
import '../bloc/ai_assistant_state.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasText = false;

  late final List<(IconData, String)> _quickPrompts;

  @override
  void initState() {
    super.initState();
    context.read<AiAssistantBloc>().add(const AiAssistantContextRefreshed());
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });

    final isFa = context.l10n.isPersian;
    _quickPrompts = [
      (
        Icons.insights_rounded,
        isFa ? 'وضعیت مالیم چطوره؟' : 'How is my finances?',
      ),
      (
        Icons.shopping_bag_rounded,
        isFa ? '۳۵۰ هزار تومن خرید سوپرمارکت' : '350K groceries',
      ),
      (
        Icons.timer_outlined,
        isFa ? 'چقدر دوام میارم؟' : 'How long can I last?',
      ),
      (
        Icons.pie_chart_rounded,
        isFa ? 'کجاها زیاد خرج کردم؟' : 'Biggest expenses?',
      ),
      (Icons.local_taxi_rounded, isFa ? '۴۵ هزار تومن اسنپ' : '45K taxi'),
      (
        Icons.account_balance_wallet_rounded,
        isFa ? 'الان چقدر پول دارم؟' : 'How much money now?',
      ),
    ];
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: KifinoMotion.medium,
          curve: KifinoMotion.easeOut,
        );
      }
    });
  }

  void _handleSend(String text) {
    final query = text.trim();
    if (query.isEmpty) return;

    _textController.clear();
    final l10n = context.l10n;
    context.read<AiAssistantBloc>().add(
      AiAssistantQuerySubmitted(query, isPersian: l10n.isPersian),
    );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                const _AiAvatar(size: 34),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.isPersian
                          ? 'دستیار مالی هوشمند'
                          : 'Financial AI Assistant',
                      style: AppTypography.titleSmall,
                    ),
                    Text(
                      l10n.isPersian
                          ? 'همیشه آنلاین • آفلاین هم کار می‌کند'
                          : 'Always here • works offline',
                      style: AppTypography.labelMedium.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              BlocBuilder<AiAssistantBloc, AiAssistantState>(
                builder: (context, state) {
                  if (state.summary != null) {
                    final score = state.summary!.healthScore;
                    final color = score >= 70
                        ? AppColors.income
                        : (score >= 45 ? AppColors.warning : AppColors.danger);
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 10,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.health_and_safety_outlined,
                            size: 16,
                            color: color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            TextNormalizer.auto('سلامت: $score'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Chat Messages List
              Expanded(
                child: BlocConsumer<AiAssistantBloc, AiAssistantState>(
                  listener: (context, state) {
                    _scrollToBottom();
                  },
                  builder: (context, state) {
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount:
                          state.messages.length + (state.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == state.messages.length && state.isLoading) {
                          return const _TypingIndicator();
                        }

                        final message = state.messages[index];
                        // ValueKey keeps each _DraftTransactionCard stateful across
                        // rebuilds — picking an account never resets on new messages.
                        return KeyedSubtree(
                          key: ValueKey(message.id),
                          child: _buildMessageBubble(context, message, isDark),
                        );
                      },
                    );
                  },
                ),
              ),

              // Quick Prompt Suggestions
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  itemCount: _quickPrompts.length,
                  itemBuilder: (context, index) {
                    final (icon, prompt) = _quickPrompts[index];
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.xs,
                      ),
                      child: ActionChip(
                        avatar: Icon(
                          icon,
                          size: 15,
                          color: theme.colorScheme.primary,
                        ),
                        label: Text(
                          prompt,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        onPressed: () => _handleSend(prompt),
                      ),
                    );
                  },
                ),
              ),

              // Input Bar
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: _handleSend,
                          decoration: InputDecoration(
                            hintText: l10n.isPersian
                                ? 'مثلاً: ۳۵۰ تومن اسنپ، یا وضعیت مالیم چطوره؟'
                                : 'Ask anything or type a transaction...',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _textController,
                        builder: (context, value, _) {
                          final canSend = value.text.trim().isNotEmpty;
                          return _SendButton(
                            enabled: canSend,
                            onTap: canSend
                                ? () => _handleSend(_textController.text)
                                : null,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    AiChatMessage msg,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    final bubble = msg.isUser
        ? Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: KifinoPalette.actionLight,
                borderRadius: const BorderRadiusDirectional.only(
                  bottomStart: Radius.circular(16),
                  topStart: Radius.circular(16),
                  topEnd: Radius.circular(16),
                  bottomEnd: Radius.circular(4),
                ),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
          )
        : Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _AiAvatar(size: 30),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceVariant
                                : AppColors.lightSurfaceVariant,
                            borderRadius: const BorderRadiusDirectional.only(
                              bottomStart: Radius.circular(4),
                              bottomEnd: Radius.circular(16),
                              topStart: Radius.circular(16),
                              topEnd: Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            msg.text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.55,
                            ),
                          ),
                        ),
                        if (msg.draftTransaction != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _DraftTransactionCard(draft: msg.draftTransaction!),
                        ],
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: AppSpacing.xs,
                            top: 3,
                          ),
                          child: Text(
                            TextNormalizer.auto(
                              AppDateFormatter.formatTime(
                                msg.timestamp,
                                locale: 'fa',
                              ),
                            ),
                            style: AppTypography.labelMedium.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

    // Subtle entrance — fade + slight rise, always quick.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: KifinoMotion.normal,
      curve: KifinoMotion.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: bubble,
      ),
    );
  }
}

/// Brand-gradient AI avatar ( AI design language: blue → cyan).
class _AiAvatar extends StatelessWidget {
  final double size;

  const _AiAvatar({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: KifinoPalette.actionLight,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x3320C8E8),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }
}

/// Three staggered bouncing dots — far more premium than a spinner.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = Theme.of(context).colorScheme.primary;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const _AiAvatar(size: 30),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
                borderRadius: const BorderRadiusDirectional.only(
                  bottomStart: Radius.circular(4),
                  bottomEnd: Radius.circular(16),
                  topStart: Radius.circular(16),
                  topEnd: Radius.circular(16),
                ),
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final t = (_controller.value * 3 - i).clamp(0.0, 1.0);
                      final lift = (t < 0.5 ? t : 1 - t) * 4;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Transform.translate(
                          offset: Offset(0, -lift),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: dotColor.withValues(
                                alpha:
                                    0.35 + 0.65 * (1 - (t < 0.5 ? t : 1 - t)),
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;

  const _SendButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'ارسال',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: KifinoMotion.fast,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [KifinoPalette.blue600, KifinoPalette.cyan500],
                  )
                : null,
            color: enabled
                ? null
                : Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_upward_rounded,
            color: enabled
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.4),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _DraftTransactionCard extends StatefulWidget {
  final ParsedTransactionDraft draft;
  const _DraftTransactionCard({required this.draft});

  @override
  State<_DraftTransactionCard> createState() => _DraftTransactionCardState();
}

class _DraftTransactionCardState extends State<_DraftTransactionCard> {
  String? _selectedAccountId;
  bool _submitted = false;

  /// Loaded directly from the repository instead of the app-level
  /// AccountsBloc: the card must render reliably the moment the bot replies,
  /// regardless of what state the shared bloc happens to be in. (Same
  /// pattern FastAddTransactionPage uses.)
  List<AccountEntity>? _accounts;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final result = await sl<AccountRepository>().getAccounts();
    if (!mounted) return;
    setState(() => _accounts = result.dataOrNull ?? const <AccountEntity>[]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final draft = widget.draft;
    final isIncome = draft.type == TransactionType.income;
    final typeColor = isIncome ? AppColors.income : AppColors.expense;

    final accounts = _accounts;
    if (accounts == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: AppSkeleton(height: 120),
      );
    }

    if (accounts.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'برای ثبت این تراکنش اول یک حساب بساز:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'ساخت حساب',
              icon: const Icon(Icons.add_rounded, size: 18),
              onPressed: () => context.push('/accounts'),
            ),
          ],
        ),
      );
    }

    _selectedAccountId ??= accounts.first.id;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: typeColor.withValues(alpha: 0.12),
                      child: Icon(
                        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 16,
                        color: typeColor,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        draft.description,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppMoneyText(
                money: draft.amount,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: typeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (draft.suggestedCategory != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'دسته‌بندی: ${draft.suggestedCategory}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkSubtext
                      : AppColors.lightSubtext,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _selectedAccountId,
            decoration: const InputDecoration(
              labelText: 'برداشت / واریز به حساب',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: accounts.map((acc) {
              return DropdownMenuItem(value: acc.id, child: Text(acc.name));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedAccountId = val);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: _submitted ? 'ثبت شد ✓' : 'تایید و ثبت تراکنش',
            isLoading: false,
            onPressed: _submitted
                ? null
                : () {
                    if (_selectedAccountId != null) {
                      setState(() => _submitted = true);
                      context.read<AiAssistantBloc>().add(
                        AiAssistantDraftConfirmed(
                          draft: draft,
                          accountId: _selectedAccountId!,
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }
}
