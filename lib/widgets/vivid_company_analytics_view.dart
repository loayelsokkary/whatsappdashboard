import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/admin_analytics_provider.dart';
import '../providers/admin_provider.dart';
import '../theme/vivid_theme.dart';

/// Vivid company-wide analytics — 8 business KPIs
class VividCompanyAnalyticsView extends StatefulWidget {
  const VividCompanyAnalyticsView({super.key});

  @override
  State<VividCompanyAnalyticsView> createState() => _VividCompanyAnalyticsViewState();
}

class _VividCompanyAnalyticsViewState extends State<VividCompanyAnalyticsView> {
  String _period = 'this_month';

  static const _periodOptions = [
    ('this_month', 'This Month'),
    ('last_30', 'Last 30 Days'),
    ('last_90', 'Last 90 Days'),
    ('all_time', 'All Time'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final clients = context.read<AdminProvider>().clients;
    context.read<AdminAnalyticsProvider>().fetchKpiAnalytics(clients, period: _period);
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      color: vc.background,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Consumer<AdminAnalyticsProvider>(
              builder: (context, provider, _) {
                if (provider.isLoadingKpi && provider.kpiAnalytics == null) {
                  return const Center(child: CircularProgressIndicator(color: VividColors.cyan, strokeWidth: 2));
                }
                final kpi = provider.kpiAnalytics;
                if (kpi == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics_outlined, size: 64, color: vc.textMuted.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('No data available', style: TextStyle(color: vc.textMuted)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                return _buildContent(context, kpi, provider.isLoadingKpi);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      decoration: BoxDecoration(
        color: vc.surface,
        border: Border(bottom: BorderSide(color: vc.border)),
      ),
      child: Row(
        children: [
          Image.asset('assets/images/vivid_icon.png', width: 30, height: 30),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vivid Analytics',
                  style: TextStyle(color: vc.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
              Text('Business KPIs across all clients',
                  style: TextStyle(color: vc.textMuted, fontSize: 13)),
            ],
          ),
          const Spacer(),
          // Period selector
          _PeriodSelector(
            selected: _period,
            options: _periodOptions,
            onChanged: (p) {
              setState(() => _period = p);
              _load();
            },
          ),
          const SizedBox(width: 12),
          Consumer<AdminAnalyticsProvider>(
            builder: (_, provider, __) => IconButton(
              onPressed: provider.isLoadingKpi ? null : _load,
              icon: provider.isLoadingKpi
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: VividColors.cyan))
                  : const Icon(Icons.refresh, size: 20),
              color: vc.textMuted,
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, VividKpiAnalytics kpi, bool isLoading) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 640;
      final pad = isMobile ? 16.0 : 28.0;

      return SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(color: VividColors.cyan, backgroundColor: Colors.transparent),
              ),

            // ── Row 1: 4 large KPI cards ──────────────────────────
            _buildRow([
              _ActiveClientsCard(kpi: kpi),
              _BroadcastVolumeCard(kpi: kpi),
              _ResponseRateCard(kpi: kpi),
              _RevenueCard(kpi: kpi),
            ], isMobile: isMobile),

            SizedBox(height: isMobile ? 12 : 20),

            // ── Row 2: 4 medium KPI cards ─────────────────────────
            _buildRow([
              _CustomerReachCard(kpi: kpi),
              _ClientHealthCard(kpi: kpi),
              _ChurnRiskCard(kpi: kpi),
              _TimeToFirstBroadcastCard(kpi: kpi),
            ], isMobile: isMobile),

            const SizedBox(height: 32),
          ],
        ),
      );
    });
  }

  Widget _buildRow(List<Widget> cards, {required bool isMobile}) {
    if (isMobile) {
      return Column(
        children: cards.expand((c) => [c, const SizedBox(height: 12)]).toList()..removeLast(),
      );
    }
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: cards[i]),
        ],
      ],
    ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PERIOD SELECTOR
// ═══════════════════════════════════════════════════════════════════

class _PeriodSelector extends StatelessWidget {
  final String selected;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  const _PeriodSelector({required this.selected, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: vc.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: vc.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = opt.$1 == selected;
          return GestureDetector(
            onTap: () => onChanged(opt.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? VividColors.cyan.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                opt.$2,
                style: TextStyle(
                  color: isSelected ? VividColors.cyan : vc.textMuted,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BASE KPI CARD
// ═══════════════════════════════════════════════════════════════════

class _KpiCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String? subtitle;
  final Color valueColor;
  final Widget? chart;
  final List<_DrillRow>? drillDown;
  final String? trendLabel;
  final Color? trendColor;

  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.subtitle,
    this.valueColor = Colors.white,
    this.chart,
    this.drillDown,
    this.trendLabel,
    this.trendColor,
  });

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.iconColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(widget.icon, color: widget.iconColor, size: 18),
                      ),
                      const Spacer(),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: vc.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(widget.value,
                      style: TextStyle(color: widget.valueColor, fontSize: 28, fontWeight: FontWeight.w700)),
                  if (widget.trendLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(widget.trendLabel!,
                        style: TextStyle(color: widget.trendColor ?? vc.textMuted, fontSize: 12)),
                  ],
                  const SizedBox(height: 4),
                  Text(widget.title,
                      style: TextStyle(color: vc.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(widget.subtitle!,
                        style: TextStyle(color: vc.textMuted.withValues(alpha: 0.6), fontSize: 11)),
                  ],
                ],
              ),
            ),
          ),

          // Chart area
          if (widget.chart != null) ...[
            Divider(height: 1, color: vc.border),
            Padding(padding: const EdgeInsets.all(16), child: widget.chart!),
          ],

          // Drill-down list
          if (_expanded) ...[
            Divider(height: 1, color: vc.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: widget.drillDown != null && widget.drillDown!.isNotEmpty
                  ? Column(
                      children: widget.drillDown!.map((row) => _buildDrillRow(context, row)).toList(),
                    )
                  : Text('No breakdown available',
                      style: TextStyle(color: vc.textMuted, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrillRow(BuildContext context, _DrillRow row) {
    final vc = context.vividColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          if (row.dot != null)
            Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: row.dot, shape: BoxShape.circle),
            ),
          Expanded(child: Text(row.label, style: TextStyle(color: vc.textPrimary, fontSize: 12))),
          Text(row.value, style: TextStyle(color: row.valueColor ?? vc.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DrillRow {
  final String label;
  final String value;
  final Color? dot;
  final Color? valueColor;
  const _DrillRow(this.label, this.value, {this.dot, this.valueColor});
}

// ═══════════════════════════════════════════════════════════════════
// KPI 1 — MONTHLY ACTIVE CLIENTS
// ═══════════════════════════════════════════════════════════════════

class _ActiveClientsCard extends StatelessWidget {
  final VividKpiAnalytics kpi;
  const _ActiveClientsCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final pct = kpi.totalClients > 0 ? kpi.activeClientsThisPeriod / kpi.totalClients : 0.0;
    final color = pct >= 1.0 ? Colors.green : pct >= 0.5 ? Colors.amber : Colors.redAccent;
    final trend = _trend(kpi.activeClientsThisPeriod, kpi.activeClientsLastPeriod);

    return _KpiCard(
      icon: Icons.people_alt_outlined,
      iconColor: color,
      title: 'Active Clients',
      value: kpi.activeClientsThisPeriod.toString(),
      subtitle: 'of ${kpi.totalClients} total',
      valueColor: color,
      trendLabel: trend.$1,
      trendColor: trend.$2,
      chart: _ActivityBar(active: kpi.activeClientsThisPeriod, total: kpi.totalClients, color: color),
      drillDown: kpi.clientActivityBreakdown.map((r) => _DrillRow(
        r.name, r.value, dot: r.color, valueColor: r.color,
      )).toList(),
    );
  }
}

class _ActivityBar extends StatelessWidget {
  final int active;
  final int total;
  final Color color;
  const _ActivityBar({required this.active, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final pct = total > 0 ? active / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: vc.surfaceAlt,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 6),
        Text('${(pct * 100).toStringAsFixed(0)}% active this period',
            style: TextStyle(color: vc.textMuted, fontSize: 11)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// KPI 2 — BROADCAST VOLUME TREND
// ═══════════════════════════════════════════════════════════════════

class _BroadcastVolumeCard extends StatelessWidget {
  final VividKpiAnalytics kpi;
  const _BroadcastVolumeCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final cur = kpi.broadcastsThisPeriod;
    final prev = kpi.broadcastsLastPeriod;
    String trendLabel;
    Color trendColor;
    if (cur == 0 && prev == 0) {
      trendLabel = 'No data';
      trendColor = Colors.blueGrey;
    } else if (prev == 0) {
      trendLabel = 'This period: $cur vs last: 0 (new)';
      trendColor = Colors.green;
    } else {
      final diff = cur - prev;
      final pct = (diff / prev * 100).round();
      final sign = diff >= 0 ? '+' : '';
      trendLabel = 'This period: $cur vs last: $prev ($sign$pct%)';
      trendColor = diff >= 0 ? Colors.green : Colors.redAccent;
    }
    return _KpiCard(
      icon: Icons.campaign_outlined,
      iconColor: VividColors.brightBlue,
      title: 'Broadcast Volume',
      value: NumberFormat('#,###').format(kpi.broadcastsThisPeriod),
      subtitle: 'this period',
      trendLabel: trendLabel,
      trendColor: trendColor,
      chart: _BarChart(
        values: kpi.weeklyBroadcastVolume.map((v) => v.toDouble()).toList(),
        color: VividColors.brightBlue,
        label: '12-week trend',
      ),
      drillDown: kpi.clientBroadcastBreakdown.map((r) => _DrillRow(
        r.name,
        NumberFormat('#,###').format(int.tryParse(r.value) ?? 0),
        dot: r.color, valueColor: r.color,
      )).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// KPI 3 — AVG RESPONSE RATE
// ═══════════════════════════════════════════════════════════════════

class _ResponseRateCard extends StatelessWidget {
  final VividKpiAnalytics kpi;
  const _ResponseRateCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final rate = kpi.avgResponseRatePct;
    final color = rate >= 10 ? Colors.green : rate >= 5 ? Colors.amber : Colors.redAccent;
    final label = rate >= 10 ? 'Good' : rate >= 5 ? 'Fair' : rate == 0 ? 'No data' : 'Low';

    return _KpiCard(
      icon: Icons.reply_outlined,
      iconColor: color,
      title: 'Avg Response Rate',
      value: '${rate.toStringAsFixed(1)}%',
      subtitle: '$label — last ${kpi.campaignResponseRates.length} campaigns',
      valueColor: color,
      chart: kpi.campaignResponseRates.isEmpty
          ? null
          : _Sparkline(
              values: kpi.campaignResponseRates,
              color: color,
              label: 'Campaign response rates (%)',
            ),
      drillDown: kpi.clientResponseRateBreakdown.map((r) => _DrillRow(
        r.name, r.value, dot: r.color, valueColor: r.color,
      )).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// KPI 4 — REVENUE
// ═══════════════════════════════════════════════════════════════════

class _RevenueCard extends StatelessWidget {
  final VividKpiAnalytics kpi;
  const _RevenueCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final trend = _trend(kpi.revenueThisPeriod.round(), kpi.revenueLastPeriod.round());
    return _KpiCard(
      icon: Icons.attach_money,
      iconColor: Colors.green,
      title: 'Revenue Generated',
      value: '${kpi.revenueThisPeriod.toStringAsFixed(0)} BHD',
      subtitle: 'from ${kpi.revenueCampaignCount} campaigns with responses',
      valueColor: Colors.green,
      trendLabel: trend.$1,
      trendColor: trend.$2,
      drillDown: kpi.clientRevenueBreakdown.map((r) => _DrillRow(
        r.name, r.value, dot: r.color, valueColor: r.color,
      )).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// KPI 5 — CUSTOMER REACH
// ═══════════════════════════════════════════════════════════════════

class _CustomerReachCard extends StatelessWidget {
  final VividKpiAnalytics kpi;
  const _CustomerReachCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final trend = _trend(kpi.reachThisPeriod, kpi.reachLastPeriod);
    return _KpiCard(
      icon: Icons.person_search_outlined,
      iconColor: VividColors.cyan,
      title: 'Customer Reach',
      value: NumberFormat('#,###').format(kpi.reachThisPeriod),
      subtitle: 'unique phones this period',
      trendLabel: trend.$1,
      trendColor: trend.$2,
      drillDown: kpi.clientReachBreakdown.map((r) => _DrillRow(
        r.name,
        NumberFormat('#,###').format(int.tryParse(r.value) ?? 0),
        dot: r.color, valueColor: r.color,
      )).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// KPI 6 — CLIENT HEALTH DISTRIBUTION
// ═══════════════════════════════════════════════════════════════════

class _ClientHealthCard extends StatelessWidget {
  final VividKpiAnalytics kpi;
  const _ClientHealthCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final grades = ['A', 'B', 'C', 'D', 'F'];
    final colors = [Colors.green, VividColors.cyan, Colors.amber, Colors.orange, Colors.redAccent];
    final total = kpi.totalClients;

    return _KpiCard(
      icon: Icons.health_and_safety_outlined,
      iconColor: Colors.teal,
      title: 'Client Health',
      value: '${kpi.healthGradeCounts['A'] ?? 0} A-grade',
      subtitle: '${kpi.lowHealthClients.length} need attention',
      chart: total == 0 ? null : Column(
        children: [
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: grades.asMap().entries.map((e) {
                final count = kpi.healthGradeCounts[e.value] ?? 0;
                final flex = total > 0 ? (count / total * 100).round() : 0;
                if (flex == 0) return const SizedBox.shrink();
                return Expanded(
                  flex: flex,
                  child: Container(height: 12, color: colors[e.key]),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: grades.asMap().entries.map((e) {
              final count = kpi.healthGradeCounts[e.value] ?? 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[e.key], shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('${e.value}: $count', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
      drillDown: kpi.lowHealthClients.isEmpty ? null : kpi.lowHealthClients.map((c) => _DrillRow(
        c.name,
        c.grade,
        dot: c.gradeColor,
        valueColor: c.gradeColor,
      )).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// KPI 7 — CHURN RISK
// ═══════════════════════════════════════════════════════════════════

class _ChurnRiskCard extends StatelessWidget {
  final VividKpiAnalytics kpi;
  const _ChurnRiskCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final color = kpi.churnRiskCount == 0 ? Colors.green : Colors.redAccent;
    return _KpiCard(
      icon: Icons.warning_amber_outlined,
      iconColor: color,
      title: 'Churn Risk',
      value: kpi.churnRiskCount.toString(),
      subtitle: 'clients — no activity in 30+ days',
      valueColor: color,
      drillDown: kpi.churnRiskClients.map((c) {
        final days = c.daysSinceLastBroadcast;
        final label = days == -1 ? 'Never broadcast' : '$days days ago';
        final dc = days == -1 || days > 60 ? Colors.redAccent : Colors.orange;
        return _DrillRow(c.name, label, dot: dc, valueColor: dc);
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// KPI 8 — TIME TO FIRST BROADCAST
// ═══════════════════════════════════════════════════════════════════

class _TimeToFirstBroadcastCard extends StatelessWidget {
  final VividKpiAnalytics kpi;
  const _TimeToFirstBroadcastCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final avg = kpi.avgDaysToFirstBroadcast;
    final color = avg == 0 ? Colors.blueGrey : avg <= 14 ? Colors.green : avg <= 30 ? Colors.amber : Colors.redAccent;
    return _KpiCard(
      icon: Icons.timer_outlined,
      iconColor: color,
      title: 'Time to First Broadcast',
      value: avg == 0 ? 'N/A' : '${avg.toStringAsFixed(1)} days',
      subtitle: 'avg from signup to first campaign',
      valueColor: color,
      drillDown: kpi.onboardingBreakdown.map((c) {
        final days = c.daysToFirstBroadcast;
        final label = days == -1 ? 'No broadcast yet' : '$days days';
        final dc = days == -1 ? Colors.blueGrey : days <= 14 ? Colors.green : days <= 30 ? Colors.amber : Colors.redAccent;
        return _DrillRow(c.name, label, dot: dc, valueColor: dc);
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CHART WIDGETS
// ═══════════════════════════════════════════════════════════════════

/// 12-bar bar chart
class _BarChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final String label;
  const _BarChart({required this.values, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final maxVal = values.isEmpty ? 1.0 : values.reduce(math.max).clamp(1.0, double.infinity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: values.map((v) {
              final h = (v / maxVal) * 50;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: h.clamp(2, 50),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('12 weeks ago', style: TextStyle(color: vc.textMuted, fontSize: 9)),
            Text(label, style: TextStyle(color: vc.textMuted, fontSize: 9)),
            Text('now', style: TextStyle(color: vc.textMuted, fontSize: 9)),
          ],
        ),
      ],
    );
  }
}

/// Sparkline
class _Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final String label;
  const _Sparkline({required this.values, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    if (values.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: CustomPaint(
            size: const Size(double.infinity, 40),
            painter: _SparklinePainter(values: values, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: vc.textMuted, fontSize: 10)),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  const _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce(math.max).clamp(0.001, double.infinity);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = size.height - (values[i] / maxV) * size.height;
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, paint);

    // Fill
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, paint..color = color.withValues(alpha: 0.12)..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}

// ═══════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════

/// Returns (trendLabel, trendColor)
(String, Color) _trend(num current, num previous) {
  if (previous == 0 && current == 0) return ('No data', Colors.blueGrey);
  if (previous == 0) return ('+${current.toStringAsFixed(0)} vs prev period', Colors.green);
  final diff = current - previous;
  final pct = (diff / previous * 100).round();
  if (diff > 0) return ('+$pct% vs last period', Colors.green);
  if (diff < 0) return ('$pct% vs last period', Colors.redAccent);
  return ('Same as last period', Colors.blueGrey);
}
