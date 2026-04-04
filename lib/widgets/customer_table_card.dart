import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/vivid_theme.dart';
import '../services/query_result_service.dart';

// ─────────────────────────────────────────────────────────────
// Compact preview card shown inline in the chat.
// Tapping "View Full Table" opens the fullscreen popup.
// ─────────────────────────────────────────────────────────────
class CustomerTableCard extends StatelessWidget {
  final QueryResultData data;
  final void Function(String prefill)? onSendOffer;

  const CustomerTableCard({
    super.key,
    required this.data,
    this.onSendOffer,
  });

  String _capitalize(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _toTsv() {
    final buf = StringBuffer();
    buf.writeln(data.columns.join('\t'));
    for (final row in data.rows) {
      final cells = List.generate(row.length, (i) {
        final val = row[i].toString();
        final col = i < data.columns.length ? data.columns[i].toLowerCase() : '';
        if (col == 'phone' || col == 'number') return '="$val"';
        return val;
      });
      buf.writeln(cells.join('\t'));
    }
    return buf.toString().trimRight();
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _toTsv()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied! Paste into Excel or Google Sheets'),
        duration: Duration(seconds: 3),
        backgroundColor: VividColors.cyan,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openFullTable(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _FullTableDialog(
        data: data,
        onSendOffer: onSendOffer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final title = _capitalize(data.title);
    final previewRows = data.rows.take(3).toList();

    return LayoutBuilder(builder: (context, constraints) {
      final width =
          constraints.maxWidth.isFinite ? constraints.maxWidth : 340.0;
      return Container(
        width: width,
        decoration: BoxDecoration(
          color: vc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: vc.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF065E80), Color(0xFF054D73)],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.people_alt_rounded,
                        size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${data.totalCustomers} customers · ${data.totalVisits} visits',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Copy icon in header
                  GestureDetector(
                    onTap: () => _copyToClipboard(context),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.content_copy_rounded,
                          size: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // ── Column headers ────────────────────────────────
            if (data.columns.isNotEmpty)
              _HeaderRow(columns: data.columns, vc: vc),

            // ── Preview rows (max 3) ──────────────────────────
            if (data.rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('No results',
                    style: TextStyle(color: vc.textMuted, fontSize: 12),
                    textAlign: TextAlign.center),
              )
            else
              for (int i = 0; i < previewRows.length; i++)
                _DataRow(
                  cells: previewRows[i],
                  columns: data.columns,
                  isEven: i.isEven,
                  vc: vc,
                  compact: true,
                ),

            // ── View Full Table button ────────────────────────
            if (data.rows.length > 3)
              InkWell(
                onTap: () => _openFullTable(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: VividColors.cyan.withValues(alpha: 0.1),
                    border: Border(
                        top: BorderSide(
                            color: VividColors.cyan.withValues(alpha: 0.25))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.table_chart_rounded,
                          size: 14, color: VividColors.cyan),
                      const SizedBox(width: 6),
                      Text(
                        'View Full Table  (${data.rows.length} rows)',
                        style: const TextStyle(
                          color: VividColors.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.open_in_full_rounded,
                          size: 12, color: VividColors.cyan),
                    ],
                  ),
                ),
              )
            else if (data.rows.isNotEmpty)
              InkWell(
                onTap: () => _openFullTable(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: VividColors.cyan.withValues(alpha: 0.07),
                    border: Border(
                        top: BorderSide(
                            color: VividColors.cyan.withValues(alpha: 0.2))),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.table_chart_rounded,
                          size: 14, color: VividColors.cyan),
                      SizedBox(width: 6),
                      Text(
                        'View Full Table',
                        style: TextStyle(
                          color: VividColors.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────
// Fullscreen dialog with all rows + action buttons
// ─────────────────────────────────────────────────────────────
class _FullTableDialog extends StatelessWidget {
  final QueryResultData data;
  final void Function(String)? onSendOffer;

  const _FullTableDialog({required this.data, this.onSendOffer});

  String _capitalize(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _toTsv() {
    final buf = StringBuffer();
    buf.writeln(data.columns.join('\t'));
    for (final row in data.rows) {
      final cells = List.generate(row.length, (i) {
        final val = row[i].toString();
        final col = i < data.columns.length ? data.columns[i].toLowerCase() : '';
        if (col == 'phone' || col == 'number') return '="$val"';
        return val;
      });
      buf.writeln(cells.join('\t'));
    }
    return buf.toString().trimRight();
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _toTsv()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied! Paste into Excel or Google Sheets'),
        duration: Duration(seconds: 3),
        backgroundColor: VividColors.cyan,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isPhoneCol(String col) =>
      col.toLowerCase() == 'phone' || col.toLowerCase() == 'number';

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final screen = MediaQuery.of(context).size;
    final title = _capitalize(data.title);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width * 0.075,
        vertical: screen.height * 0.1,
      ),
      child: Container(
        width: screen.width * 0.85,
        height: screen.height * 0.8,
        decoration: BoxDecoration(
          color: vc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: vc.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF065E80), Color(0xFF054D73)],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.people_alt_rounded,
                        size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            )),
                        Text(
                          '${data.totalCustomers} customers · ${data.totalVisits} visits',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Send Offer
                  _HeaderAction(
                    icon: Icons.campaign_rounded,
                    label: 'Send Offer',
                    onTap: () {
                      Navigator.of(context).pop();
                      onSendOffer?.call('send offer to ${data.title} customers');
                    },
                  ),
                  const SizedBox(width: 6),
                  // Copy
                  _HeaderAction(
                    icon: Icons.content_copy_rounded,
                    label: 'Copy',
                    onTap: () => _copy(context),
                  ),
                  const SizedBox(width: 6),
                  // Close
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // ── Column headers ────────────────────────────────
            Container(
              color: vc.surfaceAlt,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: _buildHeaderCells(data.columns, vc),
              ),
            ),

            // ── Scrollable rows ───────────────────────────────
            Expanded(
              child: ListView.builder(
                itemCount: data.rows.length,
                itemBuilder: (_, i) => Container(
                  color: i.isEven
                      ? vc.background.withValues(alpha: 0.6)
                      : vc.surfaceAlt.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  child: Row(
                    children: _buildDataCells(
                        data.rows[i], data.columns, vc),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHeaderCells(List<String> cols, VividColorScheme vc) {
    final cells = <Widget>[];
    for (int i = 0; i < cols.length; i++) {
      cells.add(Expanded(
        flex: _flex(cols[i]),
        child: Text(
          cols[i],
          style: const TextStyle(
            color: VividColors.cyan,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ));
      if (i < cols.length - 1) cells.add(const SizedBox(width: 6));
    }
    return cells;
  }

  List<Widget> _buildDataCells(
      List<dynamic> row, List<String> cols, VividColorScheme vc) {
    final cells = <Widget>[];
    for (int i = 0; i < cols.length; i++) {
      final val = i < row.length ? row[i].toString() : '';
      cells.add(Expanded(
        flex: _flex(cols[i]),
        child: Text(
          val,
          style: TextStyle(
            color: vc.textPrimary,
            fontSize: 13,
            fontFamily: _isPhoneCol(cols[i]) ? 'monospace' : null,
            letterSpacing: _isPhoneCol(cols[i]) ? 0.4 : 0,
          ),
        ),
      ));
      if (i < cols.length - 1) cells.add(const SizedBox(width: 6));
    }
    return cells;
  }

  int _flex(String col) {
    final lc = col.toLowerCase();
    if (lc == '#') return 1;
    if (lc == 'times' || lc == 'count') return 1;
    if (lc == 'phone') return 3;
    if (lc == 'last visit' || lc == 'date') return 2;
    return 2;
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(7),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared table row/header helpers
// ─────────────────────────────────────────────────────────────
class _HeaderRow extends StatelessWidget {
  final List<String> columns;
  final VividColorScheme vc;

  const _HeaderRow({required this.columns, required this.vc});

  int _flex(String col) {
    final lc = col.toLowerCase();
    if (lc == '#') return 1;
    if (lc == 'times' || lc == 'count') return 1;
    if (lc == 'phone') return 3;
    if (lc == 'last visit' || lc == 'date') return 2;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: vc.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          for (int i = 0; i < columns.length; i++) ...[
            Expanded(
              flex: _flex(columns[i]),
              child: Text(
                columns[i],
                style: const TextStyle(
                  color: VividColors.cyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (i < columns.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final List<dynamic> cells;
  final List<String> columns;
  final bool isEven;
  final VividColorScheme vc;
  final bool compact;

  const _DataRow({
    required this.cells,
    required this.columns,
    required this.isEven,
    required this.vc,
    this.compact = false,
  });

  bool _isPhoneCol(String col) =>
      col.toLowerCase() == 'phone' || col.toLowerCase() == 'number';

  int _flex(String col) {
    final lc = col.toLowerCase();
    if (lc == '#') return 1;
    if (lc == 'times' || lc == 'count') return 1;
    if (lc == 'phone') return 3;
    if (lc == 'last visit' || lc == 'date') return 2;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isEven
          ? vc.background.withValues(alpha: 0.6)
          : vc.surfaceAlt.withValues(alpha: 0.4),
      padding: EdgeInsets.symmetric(
          horizontal: 10, vertical: compact ? 5 : 7),
      child: Row(
        children: [
          for (int i = 0; i < columns.length; i++) ...[
            Expanded(
              flex: _flex(columns[i]),
              child: Text(
                i < cells.length ? cells[i].toString() : '',
                style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: compact ? 11 : 12,
                  fontFamily:
                      _isPhoneCol(columns[i]) ? 'monospace' : null,
                  letterSpacing: _isPhoneCol(columns[i]) ? 0.4 : 0,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (i < columns.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}
