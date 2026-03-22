import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/financial_models.dart';
import '../models/models.dart';
import '../providers/financials_provider.dart';
import '../providers/admin_provider.dart';
import '../theme/vivid_theme.dart';

class FinancialsTab extends StatefulWidget {
  const FinancialsTab({super.key});

  @override
  State<FinancialsTab> createState() => _FinancialsTabState();
}

class _FinancialsTabState extends State<FinancialsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinancialsProvider>().fetchAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<FinancialsProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final padding = isMobile ? 12.0 : 24.0;

        return RefreshIndicator(
          onRefresh: () => provider.fetchAll(),
          color: VividColors.cyan,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Financials',
                            style: TextStyle(
                              color: vc.textPrimary,
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track revenue, expenses, and profit',
                            style: TextStyle(color: vc.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showAddTransactionDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(isMobile ? 'Add' : 'Add Transaction'),
                      style: FilledButton.styleFrom(
                        backgroundColor: VividColors.cyan,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Summary cards
                _SummaryCards(
                  revenue: provider.totalRevenue,
                  outstanding: provider.outstanding,
                  expenses: provider.totalExpenses,
                  netProfit: provider.netProfit,
                  isMobile: isMobile,
                ),
                const SizedBox(height: 20),

                // Filter bar
                _FilterBar(isMobile: isMobile),
                const SizedBox(height: 16),

                // Content
                if (provider.isLoading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: CircularProgressIndicator(color: VividColors.cyan),
                    ),
                  )
                else if (provider.transactions.isEmpty)
                  _EmptyState(vc: vc)
                else if (isMobile)
                  _TransactionCards(transactions: provider.transactions)
                else
                  _TransactionTable(transactions: provider.transactions),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================
// SUMMARY CARDS
// ============================================

class _SummaryCards extends StatelessWidget {
  final double revenue;
  final double outstanding;
  final double expenses;
  final double netProfit;
  final bool isMobile;

  const _SummaryCards({
    required this.revenue,
    required this.outstanding,
    required this.expenses,
    required this.netProfit,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryData('Total Revenue', revenue, VividColors.statusSuccess, Icons.trending_up),
      _SummaryData('Outstanding', outstanding, VividColors.statusWarning, Icons.schedule),
      _SummaryData('Total Expenses', expenses, VividColors.statusUrgent, Icons.trending_down),
      _SummaryData('Net Profit', netProfit, VividColors.cyan, Icons.account_balance),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: cards.map((d) => _SummaryCard(data: d, compact: true)).toList(),
      );
    }

    return Row(
      children: cards
          .map((d) => Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _SummaryCard(data: d, compact: false),
              )))
          .toList(),
    );
  }
}

class _SummaryData {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  _SummaryData(this.label, this.amount, this.color, this.icon);
}

class _SummaryCard extends StatelessWidget {
  final _SummaryData data;
  final bool compact;

  const _SummaryCard({required this.data, required this.compact});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final formatter = NumberFormat('#,##0.000', 'en_US');

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, size: 16, color: data.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.label,
                  style: TextStyle(
                    color: vc.textMuted,
                    fontSize: compact ? 11 : 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            '${formatter.format(data.amount)} BHD',
            style: TextStyle(
              color: data.color,
              fontSize: compact ? 16 : 20,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ============================================
// FILTER BAR
// ============================================

class _FilterBar extends StatelessWidget {
  final bool isMobile;

  const _FilterBar({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<FinancialsProvider>();
    final clients = context.watch<AdminProvider>().clients;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vc.border),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          // Type filter
          _FilterChip(
            label: provider.typeFilter?.label ?? 'All Types',
            isActive: provider.typeFilter != null,
            onTap: () => _showTypeMenu(context, provider),
          ),

          // Status filter
          _FilterChip(
            label: provider.statusFilter?.label ?? 'All Statuses',
            isActive: provider.statusFilter != null,
            onTap: () => _showStatusMenu(context, provider),
          ),

          // Client filter
          _FilterChip(
            label: provider.clientFilter != null
                ? clients.where((c) => c.id == provider.clientFilter).firstOrNull?.name ?? 'Client'
                : 'All Clients',
            isActive: provider.clientFilter != null,
            onTap: () => _showClientMenu(context, provider, clients),
          ),

          // Date preset
          _FilterChip(
            label: provider.datePreset.label,
            isActive: provider.datePreset != DateRangePreset.allTime,
            onTap: () => _showDateMenu(context, provider),
          ),

          // Search
          SizedBox(
            width: isMobile ? double.infinity : 220,
            height: 36,
            child: TextField(
              onChanged: provider.setSearch,
              style: TextStyle(color: vc.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: vc.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 18, color: vc.textMuted),
                filled: true,
                fillColor: vc.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: vc.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: vc.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: VividColors.cyan),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTypeMenu(BuildContext context, FinancialsProvider provider) {
    final vc = context.vividColors;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      button.localToGlobal(Offset.zero) & button.size,
      Offset.zero & overlay.size,
    );
    showMenu<TransactionType?>(
      context: context,
      position: position,
      color: vc.surface,
      items: [
        PopupMenuItem(value: null, child: Text('All Types', style: TextStyle(color: vc.textPrimary, fontSize: 13))),
        ...TransactionType.values.map((t) => PopupMenuItem(
              value: t,
              child: Text(t.label, style: TextStyle(color: vc.textPrimary, fontSize: 13)),
            )),
      ],
    ).then((v) {
      if (v != provider.typeFilter) provider.setTypeFilter(v);
    });
  }

  void _showStatusMenu(BuildContext context, FinancialsProvider provider) {
    final vc = context.vividColors;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      button.localToGlobal(Offset.zero) & button.size,
      Offset.zero & overlay.size,
    );
    showMenu<PaymentStatus?>(
      context: context,
      position: position,
      color: vc.surface,
      items: [
        PopupMenuItem(value: null, child: Text('All Statuses', style: TextStyle(color: vc.textPrimary, fontSize: 13))),
        ...PaymentStatus.values.map((s) => PopupMenuItem(
              value: s,
              child: Text(s.label, style: TextStyle(color: vc.textPrimary, fontSize: 13)),
            )),
      ],
    ).then((v) {
      if (v != provider.statusFilter) provider.setStatusFilter(v);
    });
  }

  void _showClientMenu(BuildContext context, FinancialsProvider provider, List<Client> clients) {
    final vc = context.vividColors;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      button.localToGlobal(Offset.zero) & button.size,
      Offset.zero & overlay.size,
    );
    showMenu<String?>(
      context: context,
      position: position,
      color: vc.surface,
      items: [
        PopupMenuItem(value: null, child: Text('All Clients', style: TextStyle(color: vc.textPrimary, fontSize: 13))),
        ...clients.map((c) => PopupMenuItem(
              value: c.id,
              child: Text(c.name, style: TextStyle(color: vc.textPrimary, fontSize: 13)),
            )),
      ],
    ).then((v) {
      if (v != provider.clientFilter) provider.setClientFilter(v);
    });
  }

  void _showDateMenu(BuildContext context, FinancialsProvider provider) {
    final vc = context.vividColors;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      button.localToGlobal(Offset.zero) & button.size,
      Offset.zero & overlay.size,
    );
    showMenu<DateRangePreset>(
      context: context,
      position: position,
      color: vc.surface,
      items: DateRangePreset.values
          .where((p) => p != DateRangePreset.custom)
          .map((p) => PopupMenuItem(
                value: p,
                child: Text(p.label, style: TextStyle(color: vc.textPrimary, fontSize: 13)),
              ))
          .toList(),
    ).then((v) {
      if (v != null) provider.setDatePreset(v);
    });
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? VividColors.cyan.withOpacity(0.1) : vc.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? VividColors.cyan.withOpacity(0.3) : vc.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? VividColors.cyan : vc.textSecondary,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: isActive ? VividColors.cyan : vc.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// TRANSACTION TABLE (desktop)
// ============================================

class _TransactionTable extends StatelessWidget {
  final List<FinancialTransaction> transactions;

  const _TransactionTable({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Container(
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vc.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 60),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(vc.background),
              dataRowColor: WidgetStateProperty.resolveWith((states) {
                final index = states.contains(WidgetState.selected) ? 0 : -1;
                return index % 2 == 0 ? vc.surface : vc.surfaceAlt;
              }),
              columnSpacing: 24,
              horizontalMargin: 16,
              columns: [
                DataColumn(label: Text('Date', style: TextStyle(color: vc.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Type', style: TextStyle(color: vc.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Category', style: TextStyle(color: vc.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Client', style: TextStyle(color: vc.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Description', style: TextStyle(color: vc.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Amount', style: TextStyle(color: vc.textMuted, fontSize: 12, fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('Status', style: TextStyle(color: vc.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Actions', style: TextStyle(color: vc.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
              ],
              rows: List.generate(transactions.length, (index) {
                final t = transactions[index];
                final rowColor = index % 2 == 0 ? vc.surface : vc.surfaceAlt;
                return DataRow(
                  color: WidgetStatePropertyAll(rowColor),
                  cells: [
                    DataCell(Text(dateFormat.format(t.createdAt), style: TextStyle(color: vc.textSecondary, fontSize: 13))),
                    DataCell(_TypeBadge(type: t.type)),
                    DataCell(Text(t.category ?? '—', style: TextStyle(color: vc.textSecondary, fontSize: 13))),
                    DataCell(Text(t.clientName ?? '—', style: TextStyle(color: vc.textSecondary, fontSize: 13))),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          t.description ?? '—',
                          style: TextStyle(color: vc.textPrimary, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(
                      '${NumberFormat('#,##0.000', 'en_US').format(t.amount)} ${t.currency}',
                      style: TextStyle(
                        color: t.type == TransactionType.income ? VividColors.statusSuccess : VividColors.statusUrgent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    )),
                    DataCell(_StatusBadge(status: t.paymentStatus)),
                    DataCell(_ActionButtons(transaction: t)),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// TRANSACTION CARDS (mobile)
// ============================================

class _TransactionCards extends StatelessWidget {
  final List<FinancialTransaction> transactions;

  const _TransactionCards({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: transactions.map((t) => _TransactionCard(transaction: t)).toList(),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final FinancialTransaction transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final t = transaction;
    final dateFormat = DateFormat('dd MMM yyyy');
    final amountFormat = NumberFormat('#,##0.000', 'en_US');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TypeBadge(type: t.type),
              const SizedBox(width: 8),
              _StatusBadge(status: t.paymentStatus),
              const Spacer(),
              Text(
                dateFormat.format(t.createdAt),
                style: TextStyle(color: vc.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (t.description != null && t.description!.isNotEmpty)
            Text(
              t.description!,
              style: TextStyle(color: vc.textPrimary, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (t.category != null)
                Text(
                  t.category!,
                  style: TextStyle(color: vc.textMuted, fontSize: 12),
                ),
              if (t.clientName != null) ...[
                Text(' · ', style: TextStyle(color: vc.textMuted)),
                Text(t.clientName!, style: TextStyle(color: vc.textMuted, fontSize: 12)),
              ],
              const Spacer(),
              Text(
                '${amountFormat.format(t.amount)} ${t.currency}',
                style: TextStyle(
                  color: t.type == TransactionType.income ? VividColors.statusSuccess : VividColors.statusUrgent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ActionButtons(transaction: t),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================
// SHARED WIDGETS
// ============================================

class _TypeBadge extends StatelessWidget {
  final TransactionType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: type.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.label,
        style: TextStyle(color: type.color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PaymentStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: status.color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final FinancialTransaction transaction;

  const _ActionButtons({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.read<FinancialsProvider>();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (transaction.paymentStatus == PaymentStatus.pending ||
            transaction.paymentStatus == PaymentStatus.overdue)
          IconButton(
            icon: Icon(Icons.check_circle_outline, size: 18, color: VividColors.statusSuccess),
            tooltip: 'Mark as Paid',
            onPressed: () async {
              final err = await provider.markAsPaid(transaction.id);
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $err'), backgroundColor: VividColors.statusUrgent),
                );
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        IconButton(
          icon: Icon(Icons.edit_outlined, size: 18, color: vc.textMuted),
          tooltip: 'Edit',
          onPressed: () => _showEditDialog(context, transaction),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, size: 18, color: VividColors.statusUrgent.withOpacity(0.7)),
          tooltip: 'Delete',
          onPressed: () => _confirmDelete(context, transaction),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

// ============================================
// EMPTY STATE
// ============================================

class _EmptyState extends StatelessWidget {
  final VividColorScheme vc;

  const _EmptyState({required this.vc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 48, color: vc.textMuted.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No transactions found', style: TextStyle(color: vc.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Add your first transaction to get started', style: TextStyle(color: vc.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ============================================
// ADD / EDIT TRANSACTION DIALOG
// ============================================

void _showAddTransactionDialog(BuildContext context) {
  _showTransactionDialog(context, null);
}

void _showEditDialog(BuildContext context, FinancialTransaction transaction) {
  _showTransactionDialog(context, transaction);
}

void _showTransactionDialog(BuildContext context, FinancialTransaction? existing) {
  final vc = context.vividColors;
  final provider = context.read<FinancialsProvider>();
  final clients = context.read<AdminProvider>().clients;
  final isEdit = existing != null;

  var type = existing?.type ?? TransactionType.income;
  var category = existing?.category;
  var clientId = existing?.clientId;
  var paymentStatus = existing?.paymentStatus ?? PaymentStatus.pending;
  var recurring = existing?.recurring ?? false;
  var recurringInterval = existing?.recurringInterval;
  DateTime? dueDate = existing?.dueDate;

  final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toString() : '');
  final descCtrl = TextEditingController(text: existing?.description ?? '');
  final invoiceCtrl = TextEditingController(text: existing?.invoiceNumber ?? '');

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final categories = type == TransactionType.income
            ? FinancialCategories.income
            : FinancialCategories.expense;

        // Reset category if it doesn't belong to current type
        if (category != null && !categories.contains(category)) {
          category = null;
        }

        return AlertDialog(
          backgroundColor: vc.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit : Icons.add_circle_outline,
                color: VividColors.cyan,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isEdit ? 'Edit Transaction' : 'Add Transaction',
                style: TextStyle(color: vc.textPrimary, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type toggle
                  Text('Type', style: TextStyle(color: vc.textMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  SegmentedButton<TransactionType>(
                    segments: TransactionType.values
                        .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                        .toList(),
                    selected: {type},
                    onSelectionChanged: (s) => setDialogState(() => type = s.first),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return type == TransactionType.income
                              ? VividColors.statusSuccess.withOpacity(0.2)
                              : VividColors.statusUrgent.withOpacity(0.2);
                        }
                        return vc.background;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return type == TransactionType.income
                              ? VividColors.statusSuccess
                              : VividColors.statusUrgent;
                        }
                        return vc.textMuted;
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category
                  _DialogDropdown<String>(
                    label: 'Category',
                    value: category,
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setDialogState(() => category = v),
                    vc: vc,
                  ),
                  const SizedBox(height: 12),

                  // Client (optional)
                  _DialogDropdown<String>(
                    label: 'Client (optional)',
                    value: clientId,
                    items: [
                      DropdownMenuItem(value: null, child: Text('None', style: TextStyle(color: vc.textMuted))),
                      ...clients.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) => setDialogState(() => clientId = v),
                    vc: vc,
                  ),
                  const SizedBox(height: 12),

                  // Amount
                  _DialogTextField(
                    label: 'Amount (BHD)',
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    vc: vc,
                  ),
                  const SizedBox(height: 12),

                  // Description
                  _DialogTextField(
                    label: 'Description',
                    controller: descCtrl,
                    vc: vc,
                  ),
                  const SizedBox(height: 12),

                  // Invoice number
                  _DialogTextField(
                    label: 'Invoice Number (optional)',
                    controller: invoiceCtrl,
                    vc: vc,
                  ),
                  const SizedBox(height: 12),

                  // Due Date
                  Text('Due Date', style: TextStyle(color: vc.textMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: dueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setDialogState(() => dueDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: vc.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: vc.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: vc.textMuted),
                          const SizedBox(width: 8),
                          Text(
                            dueDate != null ? DateFormat('dd MMM yyyy').format(dueDate!) : 'Select date',
                            style: TextStyle(color: dueDate != null ? vc.textPrimary : vc.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment Status
                  _DialogDropdown<PaymentStatus>(
                    label: 'Payment Status',
                    value: paymentStatus,
                    items: PaymentStatus.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => paymentStatus = v);
                    },
                    vc: vc,
                  ),
                  const SizedBox(height: 12),

                  // Recurring
                  Row(
                    children: [
                      Switch(
                        value: recurring,
                        onChanged: (v) => setDialogState(() => recurring = v),
                        activeColor: VividColors.cyan,
                      ),
                      const SizedBox(width: 8),
                      Text('Recurring', style: TextStyle(color: vc.textPrimary, fontSize: 13)),
                    ],
                  ),
                  if (recurring) ...[
                    const SizedBox(height: 8),
                    _DialogDropdown<String>(
                      label: 'Interval',
                      value: recurringInterval,
                      items: ['monthly', 'quarterly', 'yearly']
                          .map((i) => DropdownMenuItem(
                                value: i,
                                child: Text(i[0].toUpperCase() + i.substring(1)),
                              ))
                          .toList(),
                      onChanged: (v) => setDialogState(() => recurringInterval = v),
                      vc: vc,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: vc.textMuted)),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('Enter a valid amount'), backgroundColor: VividColors.statusUrgent),
                  );
                  return;
                }

                Navigator.of(ctx).pop();

                if (isEdit) {
                  final updates = <String, dynamic>{
                    'type': type.dbValue,
                    'category': category,
                    'client_id': clientId,
                    'amount': amount,
                    'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    'invoice_number': invoiceCtrl.text.trim().isEmpty ? null : invoiceCtrl.text.trim(),
                    'payment_status': paymentStatus.dbValue,
                    'due_date': dueDate?.toIso8601String(),
                    'recurring': recurring,
                    'recurring_interval': recurring ? recurringInterval : null,
                  };
                  final err = await provider.update(existing.id, updates);
                  if (err != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $err'), backgroundColor: VividColors.statusUrgent),
                    );
                  }
                } else {
                  final transaction = FinancialTransaction(
                    id: '',
                    type: type,
                    category: category,
                    clientId: clientId,
                    amount: amount,
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    invoiceNumber: invoiceCtrl.text.trim().isEmpty ? null : invoiceCtrl.text.trim(),
                    paymentStatus: paymentStatus,
                    dueDate: dueDate,
                    recurring: recurring,
                    recurringInterval: recurring ? recurringInterval : null,
                    createdBy: ClientConfig.currentUser?.name,
                    createdAt: DateTime.now(),
                  );
                  final err = await provider.create(transaction);
                  if (err != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $err'), backgroundColor: VividColors.statusUrgent),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: VividColors.cyan,
                foregroundColor: Colors.white,
              ),
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        );
      },
    ),
  );
}

void _confirmDelete(BuildContext context, FinancialTransaction transaction) {
  final vc = context.vividColors;
  final provider = context.read<FinancialsProvider>();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: vc.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Delete Transaction?', style: TextStyle(color: vc.textPrimary)),
      content: Text(
        'This will permanently delete this ${transaction.type.label.toLowerCase()} transaction of ${NumberFormat('#,##0.000', 'en_US').format(transaction.amount)} BHD.',
        style: TextStyle(color: vc.textSecondary, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Cancel', style: TextStyle(color: vc.textMuted)),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            final err = await provider.delete(transaction.id);
            if (err != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $err'), backgroundColor: VividColors.statusUrgent),
              );
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: VividColors.statusUrgent,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

// ============================================
// DIALOG HELPERS
// ============================================

class _DialogTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final VividColorScheme vc;

  const _DialogTextField({
    required this.label,
    required this.controller,
    this.keyboardType,
    required this.vc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: vc.textMuted, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: vc.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: vc.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: vc.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: vc.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: VividColors.cyan),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final VividColorScheme vc;

  const _DialogDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.vc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: vc.textMuted, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: vc.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: vc.border),
          ),
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: vc.surface,
            style: TextStyle(color: vc.textPrimary, fontSize: 14),
            iconEnabledColor: vc.textMuted,
          ),
        ),
      ],
    );
  }
}
