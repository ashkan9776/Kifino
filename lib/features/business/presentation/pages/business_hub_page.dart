import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_constants.dart';
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
import '../../../debts/domain/entities/debt_entity.dart';
import '../../../debts/presentation/bloc/debt_bloc.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/entities/inventory_log_entity.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../bloc/business_bloc.dart';
import '../bloc/business_event.dart';
import '../bloc/business_state.dart';
import '../services/invoice_pdf_generator.dart';
import '../widgets/edit_contact_sheet.dart';
import '../widgets/edit_invoice_sheet.dart';
import '../widgets/edit_product_sheet.dart';

class BusinessHubPage extends StatefulWidget {
  const BusinessHubPage({super.key});

  @override
  State<BusinessHubPage> createState() => _BusinessHubPageState();
}

class _BusinessHubPageState extends State<BusinessHubPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            title: Text(l10n.isPersian ? 'مدیریت کسب‌وکار' : 'Business Hub'),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.income,
              labelColor: AppColors.income,
              unselectedLabelColor: isDark
                  ? AppColors.darkSubtext
                  : AppColors.lightSubtext,
              tabs: [
                Tab(
                  text: l10n.invoices,
                  icon: const Icon(Icons.receipt_long_outlined, size: 20),
                ),
                Tab(
                  text: l10n.isPersian ? 'انبار و محصولات' : 'Inventory',
                  icon: const Icon(Icons.inventory_2_outlined, size: 20),
                ),
                Tab(
                  text: l10n.customers,
                  icon: const Icon(Icons.people_outline, size: 20),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              if (_tabController.index == 0) {
                _showAddInvoiceSheet(context);
              } else if (_tabController.index == 1) {
                _showAddProductSheet(context);
              } else {
                _showAddContactSheet(context);
              }
            },
            icon: const Icon(Icons.add),
            label: Text(_getFabLabel(l10n)),
          ),
          body: BlocBuilder<BusinessBloc, BusinessState>(
            builder: (context, state) {
              if (state is BusinessLoading) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      AppSkeleton(
                        height: 110,
                        borderRadius: AppSpacing.borderRadiusLg,
                      ),
                      SizedBox(height: AppSpacing.md),
                      AppSkeleton(
                        height: 70,
                        borderRadius: AppSpacing.borderRadiusMd,
                      ),
                      SizedBox(height: AppSpacing.md),
                      AppSkeleton(
                        height: 70,
                        borderRadius: AppSpacing.borderRadiusMd,
                      ),
                    ],
                  ),
                );
              }

              if (state is! BusinessLoaded) {
                return AppEmptyState(
                  icon: Icons.storefront_outlined,
                  title: l10n.isPersian
                      ? 'کسب‌وکار شما آماده راه‌اندازی است'
                      : 'Business OS Ready',
                  description: l10n.isPersian
                      ? 'فاکتورها، موجودی انبار و مشتریان خود را با نظم حرفه‌ای ثبت و مدیریت کنید.'
                      : 'Track invoices, inventory stock, and customer relationships in one place.',
                  actionLabel: l10n.isPersian
                      ? 'ثبت اولین مشتری'
                      : 'Add your first customer',
                  onAction: () {
                    _showAddContactSheet(context);
                  },
                );
              }

              final metrics = state.metrics;

              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            // KPI Cards
                            Row(
                              children: [
                                Expanded(
                                  child: AppCard(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.trending_up,
                                              color: AppColors.income,
                                              size: 18,
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.xs,
                                            ),
                                            Text(
                                              l10n.isPersian
                                                  ? 'مجموع فروش'
                                                  : 'Total Sales',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: isDark
                                                        ? AppColors.darkSubtext
                                                        : AppColors
                                                              .lightSubtext,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        AppMoneyText(
                                          money: metrics.totalSales,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.income,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: AppCard(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.pending_actions_outlined,
                                              color: AppColors.warning,
                                              size: 18,
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.xs,
                                            ),
                                            Text(
                                              l10n.isPersian
                                                  ? 'مطالبات فاکتور'
                                                  : 'Unpaid Invoices',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: isDark
                                                        ? AppColors.darkSubtext
                                                        : AppColors
                                                              .lightSubtext,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        AppMoneyText(
                                          money: metrics.unpaidReceivables,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.warning,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Low stock alert banner
                            if (metrics.lowStockCount > 0) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: AppSpacing.borderRadiusMd,
                                  border: Border.all(
                                    color: AppColors.danger.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: AppColors.danger,
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        l10n.isPersian
                                            ? TextNormalizer.auto(
                                                '${metrics.lowStockCount} کالا به حداقل موجودی انبار رسیده‌اند!',
                                              )
                                            : '${metrics.lowStockCount} items have reached low stock limit!',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: AppColors.danger,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInvoicesTab(
                      context,
                      state.invoices,
                      state.contacts,
                      state.products,
                    ),
                    _buildProductsTab(context, state.products),
                    _buildContactsTab(context, state.contacts),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _getFabLabel(AppLocalizations l10n) {
    if (_tabController.index == 0) {
      return l10n.isPersian ? 'فاکتور جدید' : 'New Invoice';
    }
    if (_tabController.index == 1) {
      return l10n.isPersian ? 'کالای جدید' : 'New Product';
    }
    return l10n.isPersian ? 'مخاطب جدید' : 'New Contact';
  }

  // ----------------------------------------------------
  // INVOICES TAB
  // ----------------------------------------------------
  Widget _buildInvoicesTab(
    BuildContext context,
    List<InvoiceEntity> invoices,
    List<ContactEntity> contacts,
    List<ProductEntity> products,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    if (invoices.isEmpty) {
      return AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: l10n.isPersian ? 'فاکتوری ثبت نشده' : 'No invoices yet',
        description: l10n.isPersian
            ? 'اولین فاکتور فروش یا پیش‌فاکتور خود را ثبت و صادر کنید.'
            : 'Create your first sales or purchase invoice with automated PDF generation.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        final contact = contacts
            .where((c) => c.id == invoice.contactId)
            .firstOrNull;

        final isPaid = invoice.status == InvoiceStatus.paid;
        final isCancelled = invoice.status == InvoiceStatus.cancelled;
        // Editing a fully-paid or cancelled invoice is forbidden — payments
        // and status are separate flows.
        final canEdit = !invoice.isFullyPaid && !isCancelled;
        final statusColor = isPaid
            ? AppColors.income
            : (invoice.isOverdue ? AppColors.danger : AppColors.warning);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: statusColor.withValues(alpha: 0.12),
                          child: Icon(
                            Icons.receipt_outlined,
                            size: 18,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoice.invoiceNumber,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              contact?.name ??
                                  invoice.contactName ??
                                  (l10n.isPersian ? 'مشتری آزاد' : 'Guest'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.darkSubtext
                                    : AppColors.lightSubtext,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppMoneyText(
                          money: invoice.total,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            invoice.status.titleFa,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l10n.dueDate}: ${AppDateFormatter.formatShort(invoice.dueDate, locale: l10n.localeName)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: invoice.isOverdue
                            ? AppColors.danger
                            : (isDark
                                  ? AppColors.darkSubtext
                                  : AppColors.lightSubtext),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canEdit)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: l10n.isPersian
                                ? 'اصلاح فاکتور'
                                : 'Edit invoice',
                            onPressed: () => EditInvoiceSheet.show(
                              context,
                              invoice,
                              contacts: contacts,
                              products: products,
                            ),
                          ),
                        // PDF Preview & Print button
                        IconButton(
                          icon: const Icon(Icons.print_outlined, size: 20),
                          tooltip: l10n.isPersian
                              ? 'چاپ یا اشتراک PDF'
                              : 'Print PDF',
                          onPressed: () {
                            InvoicePdfGenerator.printOrShareInvoice(
                              invoice: invoice,
                              contact: contact,
                              isPersian: l10n.isPersian,
                            );
                          },
                        ),
                        if (!isPaid)
                          TextButton.icon(
                            icon: const Icon(Icons.payment_outlined, size: 16),
                            label: Text(l10n.isPersian ? 'ثبت پرداخت' : 'Pay'),
                            onPressed: () =>
                                _showPaymentSheet(context, invoice),
                          ),
                        if (invoice.type == InvoiceType.sale && !isPaid)
                          TextButton.icon(
                            icon: const Icon(
                              Icons.handshake_outlined,
                              size: 16,
                            ),
                            label: Text(
                              l10n.isPersian ? 'تبدیل به طلب' : 'To receivable',
                            ),
                            onPressed: () =>
                                _convertInvoiceToReceivable(context, invoice),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------
  // PRODUCTS TAB
  // ----------------------------------------------------
  Widget _buildProductsTab(BuildContext context, List<ProductEntity> products) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    if (products.isEmpty) {
      return AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: l10n.isPersian ? 'کالایی ثبت نشده' : 'No products',
        description: l10n.isPersian
            ? 'محصولات، خدمات و قیمت‌های خرید و فروش خود را ثبت کنید.'
            : 'Add products with inventory count, purchase cost, and selling price.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: product.isLowStock
                              ? AppColors.danger.withValues(alpha: 0.12)
                              : AppColors.income.withValues(alpha: 0.12),
                          child: Icon(
                            Icons.layers_outlined,
                            size: 18,
                            color: product.isLowStock
                                ? AppColors.danger
                                : AppColors.income,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (product.sku != null)
                              Text(
                                'SKU: ${product.sku}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppColors.darkSubtext
                                      : AppColors.lightSubtext,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppMoneyText(
                          money: product.sellingPrice,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.income,
                          ),
                        ),
                        Text(
                          '${l10n.isPersian ? "سود:" : "Margin:"} ${TextNormalizer.auto(product.marginPercentage.toStringAsFixed(0))}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isDark
                                ? AppColors.darkSubtext
                                : AppColors.lightSubtext,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: product.isLowStock
                                ? AppColors.danger.withValues(alpha: 0.12)
                                : (isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${TextNormalizer.auto(product.currentStock.toStringAsFixed(0))} ${product.unit}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: product.isLowStock
                                  ? AppColors.danger
                                  : null,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (product.isLowStock) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            l10n.isPersian ? 'موجودی اندک' : 'Low stock',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: l10n.isPersian ? 'ویرایش' : 'Edit',
                          onPressed: () =>
                              EditProductSheet.show(context, product),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.receipt_long_outlined,
                            size: 18,
                          ),
                          tooltip: l10n.isPersian ? 'کاردکس' : 'Stock card',
                          onPressed: () => context.push(
                            '/business/products/card',
                            extra: product.id,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.swap_vert_outlined, size: 16),
                          label: Text(
                            l10n.isPersian ? 'تغییر موجودی' : 'Adjust Stock',
                          ),
                          onPressed: () =>
                              _showAdjustStockSheet(context, product),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------
  // CONTACTS TAB
  // ----------------------------------------------------
  Widget _buildContactsTab(BuildContext context, List<ContactEntity> contacts) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    if (contacts.isEmpty) {
      return AppEmptyState(
        icon: Icons.people_outline,
        title: l10n.isPersian ? 'مخاطبی ثبت نشده' : 'No contacts',
        description: l10n.isPersian
            ? 'مشتریان و تأمین‌کنندگان خود را برای صدور فاکتور و پیگیری حساب‌ها وارد کنید.'
            : 'Add customers and suppliers to manage balances and send invoices.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: Text(
                        contact.name.isNotEmpty ? contact.name[0] : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (contact.companyName != null)
                          Text(
                            contact.companyName!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkSubtext
                                  : AppColors.lightSubtext,
                            ),
                          ),
                        if (contact.phone != null)
                          Text(
                            contact.phone!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkSubtext
                                  : AppColors.lightSubtext,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            contact.type.titleFa,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: l10n.isPersian ? 'ویرایش' : 'Edit',
                          onPressed: () =>
                              EditContactSheet.show(context, contact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (contact.outstandingBalance.minorUnits > 0)
                      AppMoneyText(
                        money: contact.outstandingBalance,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------
  // ACTION MODALS
  // ----------------------------------------------------
  void _showAddProductSheet(BuildContext context) {
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final purchasePriceController = TextEditingController();
    final sellingPriceController = TextEditingController();
    final stockController = TextEditingController(text: '10');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return AppBottomSheet(
          child: Padding(
            padding: const EdgeInsets.only(
              bottom: AppSpacing.md,
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSheetHeader(title: 'ثبت کالای جدید'),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'نام کالا یا خدمت',
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: skuController,
                  decoration: const InputDecoration(
                    labelText: 'کد کالا (SKU)',
                    prefixIcon: Icon(Icons.qr_code_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: purchasePriceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          PersianThousandsSeparatorTextInputFormatter(
                            enabled: isFaLocale(context),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'قیمت خرید (ریال)',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: sellingPriceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          PersianThousandsSeparatorTextInputFormatter(
                            enabled: isFaLocale(context),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'قیمت فروش (ریال)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    PersianDigitsTextInputFormatter(
                      enabled: isFaLocale(context),
                    ),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'موجودی اولیه انبار',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'ذخیره کالا',
                  onPressed: () {
                    final name = nameController.text.trim();
                    final pPrice =
                        int.tryParse(
                          normalizeNumericInput(purchasePriceController.text),
                        ) ??
                        0;
                    final sPrice =
                        int.tryParse(
                          normalizeNumericInput(sellingPriceController.text),
                        ) ??
                        0;
                    final stock =
                        double.tryParse(
                          normalizeDecimalInput(stockController.text),
                        ) ??
                        0.0;

                    if (name.isNotEmpty && sPrice > 0) {
                      final cur = Currency.fromCode(
                        AppConstants.defaultCurrencyCode,
                      );
                      final now = DateTime.now();

                      context.read<BusinessBloc>().add(
                        BusinessProductCreateSubmitted(
                          ProductEntity(
                            id: '',
                            name: name,
                            sku: skuController.text.trim().isNotEmpty
                                ? skuController.text.trim()
                                : null,
                            purchasePrice: Money.fromMinor(pPrice, cur),
                            sellingPrice: Money.fromMinor(sPrice, cur),
                            currentStock: stock,
                            createdAt: now,
                            updatedAt: now,
                          ),
                        ),
                      );
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddContactSheet(BuildContext context) {
    final nameController = TextEditingController();
    final companyController = TextEditingController();
    final phoneController = TextEditingController();
    ContactType selectedType = ContactType.customer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AppBottomSheet(
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.md,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  top: AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSheetHeader(title: 'ثبت طرف حساب جدید'),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'نام و نام خانوادگی',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: companyController,
                      decoration: const InputDecoration(
                        labelText: 'نام شرکت یا فروشگاه (اختیاری)',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        PersianDigitsTextInputFormatter(
                          enabled: isFaLocale(context),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'شماره تماس',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<ContactType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'نوع مخاطب'),
                      items: ContactType.values.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(t.titleFa),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'ثبت مخاطب',
                      onPressed: () {
                        final name = nameController.text.trim();
                        if (name.isNotEmpty) {
                          final cur = Currency.fromCode(
                            AppConstants.defaultCurrencyCode,
                          );
                          final now = DateTime.now();

                          context.read<BusinessBloc>().add(
                            BusinessContactCreateSubmitted(
                              ContactEntity(
                                id: '',
                                name: name,
                                companyName:
                                    companyController.text.trim().isNotEmpty
                                    ? companyController.text.trim()
                                    : null,
                                phone: phoneController.text.trim().isNotEmpty
                                    ? phoneController.text.trim()
                                    : null,
                                type: selectedType,
                                outstandingBalance: Money.zero(cur),
                                createdAt: now,
                                updatedAt: now,
                              ),
                            ),
                          );
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAdjustStockSheet(BuildContext context, ProductEntity product) {
    final qtyController = TextEditingController();
    InventoryMovementType selectedType = InventoryMovementType.purchase;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AppBottomSheet(
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.md,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  top: AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSheetHeader(
                      title: 'اصلاح موجودی انبار: ${product.name}',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'موجودی فعلی: ${TextNormalizer.auto(product.currentStock.toStringAsFixed(0))} ${product.unit}',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<InventoryMovementType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'نوع تغییر موجودی',
                      ),
                      items: InventoryMovementType.values.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(t.titleFa),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        PersianDigitsTextInputFormatter(
                          enabled: isFaLocale(context),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'مقدار تغییر (تعداد)',
                        prefixIcon: Icon(Icons.numbers_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'ثبت در کارتکس انبار',
                      onPressed: () {
                        final rawQty =
                            double.tryParse(
                              normalizeDecimalInput(qtyController.text),
                            ) ??
                            0.0;
                        if (rawQty > 0) {
                          final change =
                              (selectedType == InventoryMovementType.sale ||
                                  selectedType == InventoryMovementType.loss)
                              ? -rawQty
                              : rawQty;

                          context.read<BusinessBloc>().add(
                            BusinessStockAdjustSubmitted(
                              productId: product.id,
                              changeQuantity: change,
                              type: selectedType,
                            ),
                          );
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddInvoiceSheet(BuildContext context) {
    final state = context.read<BusinessBloc>().state;
    if (state is! BusinessLoaded || state.contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ابتدا حداقل یک مخاطب یا مشتری ثبت کنید.'),
        ),
      );
      return;
    }

    final invoiceNumberController = TextEditingController(
      text: 'INV-${DateTime.now().millisecondsSinceEpoch % 100000}',
    );
    final descController = TextEditingController(text: 'کالای فروش');
    final priceController = TextEditingController(text: '5000000');
    final qtyController = TextEditingController(text: '1');
    String selectedContactId = state.contacts.first.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AppBottomSheet(
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.md,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  top: AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSheetHeader(title: 'صدور فاکتور فروش سریع'),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: invoiceNumberController,
                      decoration: const InputDecoration(
                        labelText: 'شماره فاکتور',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      initialValue: selectedContactId,
                      decoration: const InputDecoration(
                        labelText: 'مشتری / طرف حساب',
                      ),
                      items: state.contacts.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedContactId = val);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'شرح کالا یا خدمات',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              PersianDigitsTextInputFormatter(
                                enabled: isFaLocale(context),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'تعداد',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              PersianThousandsSeparatorTextInputFormatter(
                                enabled: isFaLocale(context),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'قیمت واحد (ریال)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'صدور و ثبت فاکتور',
                      onPressed: () {
                        final price =
                            int.tryParse(
                              normalizeNumericInput(priceController.text),
                            ) ??
                            0;
                        final qty =
                            double.tryParse(
                              normalizeDecimalInput(qtyController.text),
                            ) ??
                            1.0;
                        final cur = Currency.fromCode(
                          AppConstants.defaultCurrencyCode,
                        );
                        final now = DateTime.now();

                        final item = InvoiceItemEntity.calculate(
                          id: '',
                          invoiceId: '',
                          description: descController.text.trim(),
                          quantity: qty,
                          unitPrice: Money.fromMinor(price, cur),
                          taxRate: 0.10, // 10% VAT
                        );

                        final invoice = InvoiceEntity(
                          id: '',
                          invoiceNumber: invoiceNumberController.text.trim(),
                          contactId: selectedContactId,
                          type: InvoiceType.sale,
                          status: InvoiceStatus.sent,
                          issueDate: now,
                          dueDate: now.add(const Duration(days: 14)),
                          subtotal: item.unitPrice * item.quantity,
                          discount: item.discount,
                          tax: item.tax,
                          total: item.total,
                          paidAmount: Money.zero(cur),
                          items: [item],
                          createdAt: now,
                          updatedAt: now,
                        );

                        context.read<BusinessBloc>().add(
                          BusinessInvoiceCreateSubmitted(invoice),
                        );
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Links an unpaid sale invoice into the debts module as a receivable
  /// (Phase 2 payment-status integration). Notes marker 'INV:{id}' makes the
  /// link detectable and prevents duplicates.
  void _convertInvoiceToReceivable(
    BuildContext context,
    InvoiceEntity invoice,
  ) {
    final debtBloc = context.read<DebtBloc>();
    final already =
        debtBloc.state is DebtLoaded &&
        (debtBloc.state as DebtLoaded).debts.any(
          (d) => d.notes == 'INV:${invoice.id}',
        );
    final l10n = context.l10n;
    if (already) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isPersian
                ? 'این فاکتور قبلاً به طلب تبدیل شده است.'
                : 'Already converted to a receivable.',
          ),
        ),
      );
      return;
    }
    debtBloc.add(
      DebtCreateSubmitted(
        DebtEntity(
          id: const Uuid().v4(),
          contactName:
              invoice.contactName ?? (l10n.isPersian ? 'مشتری' : 'Customer'),
          type: DebtType.receivable,
          totalAmount: invoice.remainingBalance,
          paidAmount: Money.fromMinor(0, invoice.remainingBalance.currency),
          status: DebtStatus.active,
          notes: 'INV:${invoice.id}',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.isPersian
              ? 'طلب در ماژول بدهی و طلب ثبت شد.'
              : 'Receivable created in the debts module.',
        ),
      ),
    );
  }

  void _showPaymentSheet(BuildContext context, InvoiceEntity invoice) {
    final payController = TextEditingController(
      text: formatNumberWithSeparators(
        invoice.remainingBalance.minorUnits,
        toPersian: isFaLocale(context),
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return AppBottomSheet(
          child: Padding(
            padding: const EdgeInsets.only(
              bottom: AppSpacing.md,
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSheetHeader(title: 'ثبت تسویه / دریافت وجه فاکتور'),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'فاکتور: ${invoice.invoiceNumber} | مانده: ${invoice.remainingBalance.formatted}',
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: payController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    PersianThousandsSeparatorTextInputFormatter(
                      enabled: isFaLocale(context),
                    ),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'مبلغ پرداختی (ریال)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'ثبت تسویه',
                  onPressed: () {
                    final amount =
                        int.tryParse(
                          normalizeNumericInput(payController.text),
                        ) ??
                        0;
                    if (amount > 0) {
                      context.read<BusinessBloc>().add(
                        BusinessInvoicePaymentSubmitted(
                          invoiceId: invoice.id,
                          paymentAmount: Money.fromMinor(
                            amount,
                            invoice.total.currency,
                          ),
                        ),
                      );
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
