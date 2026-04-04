import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/admin_analytics_provider.dart';
import '../theme/vivid_theme.dart';

// ─── Public entry point ───────────────────────────────────────────────────────

class VividInsightsPanel extends StatefulWidget {
  final Client client;

  const VividInsightsPanel({super.key, required this.client});

  @override
  State<VividInsightsPanel> createState() => _VividInsightsPanelState();
}

class _VividInsightsPanelState extends State<VividInsightsPanel> {
  bool _loading = true;
  OptimalTimingResult? _timing;
  BroadcastROIResult? _roi;
  ResponseTimeResult? _responseTime;
  CustomerReturnRateResult? _returnRate;
  ConversationEngagementResult? _engagement;

  Client get client => widget.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(VividInsightsPanel old) {
    super.didUpdateWidget(old);
    if (old.client.id != client.id) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = context.read<AdminAnalyticsProvider>();
    final futures = <Future>[];

    // Use same fallback logic as the provider: slug is enough when table name is null
    final hasMessagesTable = client.messagesTable != null || client.slug.isNotEmpty;
    final hasBroadcastsTable = client.broadcastsTable != null || client.slug.isNotEmpty;

    // Optimal Timing = when customers respond to broadcasts → needs broadcasts feature
    if (client.hasFeature('broadcasts') && hasBroadcastsTable) {
      futures.add(p.fetchOptimalTiming(client).then((v) => _timing = v));
      futures.add(p.fetchBroadcastROI(client).then((v) => _roi = v));
    }
    if (client.hasFeature('conversations') && hasMessagesTable) {
      futures.add(p.fetchResponseTime(client).then((v) => _responseTime = v));
      futures.add(
          p.fetchConversationEngagement(client).then((v) => _engagement = v));
    }
    if (client.hasFeature('predictive_intelligence') &&
        client.customerPredictionsTable != null) {
      futures
          .add(p.fetchCustomerReturnRate(client).then((v) => _returnRate = v));
    }

    try {
      await Future.wait(futures);
    } catch (e) {
      debugPrint('VividInsightsPanel load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    if (_loading) return _buildSkeleton(vc);

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 800;
      final cards = _buildCards(vc, wide);
      if (cards.isEmpty) {
        return _emptyState(vc,
            'No insights yet — this client needs more activity data.');
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: wide
            ? _twoColumnGrid(cards)
            : Column(
                children: cards
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: c,
                        ))
                    .toList(),
              ),
      );
    });
  }

  List<Widget> _buildCards(VividColorScheme vc, bool wide) {
    final cards = <Widget>[];

    if (_timing != null && client.hasFeature('broadcasts')) {
      cards.add(_TimingCard(result: _timing!));
    }
    if (_roi != null && client.hasFeature('broadcasts')) {
      cards.add(_ROICard(result: _roi!));
    }
    if (_responseTime != null && client.hasFeature('conversations')) {
      cards.add(_ResponseTimeCard(result: _responseTime!));
    }
    if (_returnRate != null && client.hasFeature('predictive_intelligence')) {
      cards.add(_ReturnRateCard(result: _returnRate!));
    }
    if (_engagement != null && client.hasFeature('conversations')) {
      cards.add(_EngagementCard(result: _engagement!));
    }
    // Card 6: Feature Adoption — always shown
    cards.add(_FeatureAdoptionCard(client: client));

    return cards;
  }

  Widget _twoColumnGrid(List<Widget> cards) {
    final rows = <Widget>[];
    for (int i = 0; i < cards.length; i += 2) {
      final hasSecond = i + 1 < cards.length;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[i]),
              const SizedBox(width: 16),
              Expanded(child: hasSecond ? cards[i + 1] : const SizedBox()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _buildSkeleton(VividColorScheme vc) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: List.generate(
            3,
            (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: vc.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                )),
      ),
    );
  }

  Widget _emptyState(VividColorScheme vc, String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insights, size: 48, color: vc.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: vc.textMuted, fontSize: 14)),
        ],
      ),
    );
  }
}

// ─── Shared card shell ────────────────────────────────────────────────────────

class _InsightCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String tooltip;
  final Widget child;

  const _InsightCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.child,
  });

  @override
  State<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<_InsightCard> {
  bool _expanded = true;

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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, size: 16, color: widget.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: vc.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: widget.tooltip,
                    child: Icon(Icons.help_outline,
                        size: 15, color: vc.textMuted),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: vc.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: vc.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: widget.child,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

String _fmtDuration(Duration d) {
  if (d.inMinutes < 1) return '< 1 min';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  final hrs = d.inMinutes / 60;
  return '${hrs.toStringAsFixed(1)} hrs';
}

Widget _emptyDataNote(VividColorScheme vc, String note) {
  return Row(
    children: [
      Icon(Icons.hourglass_empty, size: 16, color: vc.textMuted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(note,
            style: TextStyle(
                color: vc.textMuted,
                fontSize: 12,
                fontStyle: FontStyle.italic)),
      ),
    ],
  );
}

Widget _miniMetric(VividColorScheme vc, String label, String value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: vc.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

// ─── CARD 1: Optimal Broadcast Timing ────────────────────────────────────────

class _TimingCard extends StatelessWidget {
  final OptimalTimingResult result;
  const _TimingCard({required this.result});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return _InsightCard(
      title: 'Optimal Broadcast Timing',
      icon: Icons.access_time_rounded,
      color: Colors.orange,
      tooltip:
          'Based on when customers actually send messages — the best time to reach them.',
      child: !result.hasEnoughData
          ? _emptyDataNote(vc,
              'Not enough data yet — need at least 50 customer messages to determine optimal timing (${result.totalMessages} so far).')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Heatmap
                _HeatmapWidget(heatmap: result.heatmap),
                const SizedBox(height: 14),
                // Best time callout
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(children: [
                            TextSpan(
                              text: 'Best time: ',
                              style: TextStyle(
                                  color: vc.textMuted, fontSize: 13),
                            ),
                            TextSpan(
                              text:
                                  '${_days[result.peakDay]} at ${result.peakHour}:00',
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Based on ${result.totalMessages.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')} customer responses (last 90 days)',
                  style: TextStyle(color: vc.textMuted, fontSize: 11),
                ),
              ],
            ),
    );
  }
}

class _HeatmapWidget extends StatelessWidget {
  final List<List<int>> heatmap; // [day][hour]
  const _HeatmapWidget({required this.heatmap});

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _cellSize = 16.0;
  static const _cellGap = 1.0;
  static const _labelWidth = 16.0;

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    int maxVal = 1;
    for (final row in heatmap) {
      for (final v in row) {
        if (v > maxVal) maxVal = v;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hour labels top (every 3h)
          Row(
            children: [
              const SizedBox(width: _labelWidth + 4),
              ...List.generate(24, (h) {
                return SizedBox(
                  width: _cellSize + _cellGap,
                  child: h % 3 == 0
                      ? Text(
                          '$h',
                          style: TextStyle(color: vc.textMuted, fontSize: 8),
                          textAlign: TextAlign.center,
                        )
                      : const SizedBox.shrink(),
                );
              }),
            ],
          ),
          const SizedBox(height: 3),
          // Day rows
          ...List.generate(7, (day) {
            return Padding(
              padding: const EdgeInsets.only(bottom: _cellGap),
              child: Row(
                children: [
                  SizedBox(
                    width: _labelWidth,
                    child: Text(
                      _dayLabels[day],
                      style: TextStyle(color: vc.textMuted, fontSize: 9),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 4),
                  ...List.generate(24, (hour) {
                    final val = heatmap[day][hour];
                    final intensity = val == 0 ? 0.05 : 0.15 + (val / maxVal) * 0.85;
                    return Container(
                      width: _cellSize,
                      height: _cellSize,
                      margin: const EdgeInsets.only(right: _cellGap),
                      decoration: BoxDecoration(
                        color: VividColors.cyan.withValues(alpha: intensity),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── CARD 2: Broadcast ROI ────────────────────────────────────────────────────

class _ROICard extends StatelessWidget {
  final BroadcastROIResult result;
  const _ROICard({required this.result});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final rateColor = result.avgResponseRate >= 10
        ? Colors.green
        : result.avgResponseRate >= 5
            ? Colors.amber.shade600
            : Colors.red.shade400;

    return _InsightCard(
      title: 'Broadcast ROI',
      icon: Icons.campaign,
      color: Colors.orange,
      tooltip:
          'Response rate = customers who messaged back within 72h of receiving a broadcast.',
      child: result.totalCampaigns == 0
          ? _emptyDataNote(vc, 'No campaigns sent yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trend line chart — shown ABOVE the metric boxes
                if (result.campaignResponseRates.length >= 2) ...[
                  Text('Response rate trend',
                      style: TextStyle(color: vc.textMuted, fontSize: 11)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 120,
                    child: CustomPaint(
                      painter: _SparklinePainter(
                        values: result.campaignResponseRates
                            .map((v) => v.round())
                            .toList(),
                        maxVal: 100,
                        color: Colors.orange,
                        drawDots: true,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                // 4 metric boxes
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _miniMetric(vc, 'Campaigns',
                        result.totalCampaigns.toString(), Colors.blueGrey),
                    _miniMetric(
                        vc,
                        'Avg Response',
                        '${result.avgResponseRate.toStringAsFixed(1)}%',
                        rateColor),
                    _miniMetric(
                        vc,
                        'Revenue',
                        result.totalRevenueBhd > 0
                            ? '${result.totalRevenueBhd.toStringAsFixed(0)} BHD'
                            : '—',
                        Colors.teal),
                    _miniMetric(
                        vc,
                        'Cost/Response',
                        result.costPerResponse > 0
                            ? '${result.costPerResponse.toStringAsFixed(1)} recip'
                            : '—',
                        Colors.purple.shade300),
                  ],
                ),
              ],
            ),
    );
  }
}

// ─── CARD 3: Response Time Signal ────────────────────────────────────────────

class _ResponseTimeCard extends StatelessWidget {
  final ResponseTimeResult result;
  const _ResponseTimeCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final medMins = result.median.inMinutes;
    final color = medMins < 15
        ? Colors.green
        : medMins < 60
            ? Colors.amber.shade600
            : medMins < 240
                ? Colors.orange
                : Colors.red.shade400;

    return _InsightCard(
      title: 'Response Time Signal',
      icon: Icons.timer_outlined,
      color: VividColors.cyan,
      tooltip:
          'Median time between a customer message and the next reply from the team or AI.',
      child: result.totalPaired < 10
          ? _emptyDataNote(
              vc, 'Need more conversation data (${result.totalPaired} paired so far).')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _fmtDuration(result.median),
                      style: TextStyle(
                          color: color,
                          fontSize: 32,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text('median response',
                          style: TextStyle(
                              color: vc.textMuted, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Avg: ${_fmtDuration(result.average)}   ·   ${result.slowConversations} conversations over 4 hrs',
                  style: TextStyle(color: vc.textMuted, fontSize: 12),
                ),
                if (result.weeklyAvgMinutes.any((v) => v > 0)) ...[
                  const SizedBox(height: 12),
                  Text('8-week trend (avg minutes/week)',
                      style:
                          TextStyle(color: vc.textMuted, fontSize: 11)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 50,
                    child: CustomPaint(
                      painter: _SparklinePainter(
                        values: result.weeklyAvgMinutes
                            .map((v) => v.round())
                            .toList(),
                        maxVal: math.max(
                                1,
                                result.weeklyAvgMinutes
                                    .fold<double>(0, (a, b) => a > b ? a : b))
                            .round(),
                        color: color,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ],
                if (result.slowConversations > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 15, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        '${result.slowConversations} conversations over 4hr response time',
                        style: const TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ],
                  ),
                ],
                if (result.agentStats.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('By agent',
                      style: TextStyle(
                          color: vc.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  // Header row
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text('Agent', style: TextStyle(color: vc.textMuted, fontSize: 10, fontWeight: FontWeight.w600))),
                        SizedBox(width: 80, child: Text('Avg Response', style: TextStyle(color: vc.textMuted, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                        SizedBox(width: 55, child: Text('Messages', style: TextStyle(color: vc.textMuted, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: vc.border),
                  const SizedBox(height: 4),
                  ...(() {
                    final sorted = result.agentStats.entries.toList()
                      ..sort((a, b) => b.value.$2.compareTo(a.value.$2));
                    return sorted.take(10).map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(e.key,
                                      style: TextStyle(
                                          color: vc.textPrimary,
                                          fontSize: 12),
                                      overflow: TextOverflow.ellipsis)),
                              SizedBox(
                                width: 80,
                                child: Text(
                                    '${e.value.$1.round()} min',
                                    style: TextStyle(
                                        color: e.value.$1 >= 240 ? Colors.orange : vc.textMuted,
                                        fontSize: 12),
                                    textAlign: TextAlign.right)),
                              SizedBox(
                                width: 55,
                                child: Text('${e.value.$2}',
                                    style: TextStyle(
                                        color: vc.textMuted,
                                        fontSize: 12),
                                    textAlign: TextAlign.right)),
                            ],
                          ),
                        ));
                  })(),
                ],
              ],
            ),
    );
  }
}

// ─── CARD 4: Customer Return Rate ────────────────────────────────────────────

class _ReturnRateCard extends StatelessWidget {
  final CustomerReturnRateResult result;
  const _ReturnRateCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final color = result.saveRate >= 30
        ? Colors.green
        : result.saveRate >= 15
            ? Colors.amber.shade600
            : Colors.red.shade400;
    final lost = result.atRiskTotal - result.returned - result.pending;

    return _InsightCard(
      title: 'Customer Return Rate',
      icon: Icons.person_add_alt_1_rounded,
      color: Colors.teal,
      tooltip:
          'Of all at-risk / lapsed customers, how many actually messaged back after their predicted visit date.',
      child: result.atRiskTotal == 0
          ? _emptyDataNote(vc,
              'No at-risk customers yet — Predictive Intelligence needs more visit history.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${result.saveRate.toStringAsFixed(0)}%',
                      style: TextStyle(
                          color: color,
                          fontSize: 34,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('saved',
                          style: TextStyle(
                              color: vc.textMuted, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Donut
                SizedBox(
                  height: 100,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CustomPaint(
                          painter: _DonutPainter(
                            returned: result.returned,
                            lost: lost < 0 ? 0 : lost,
                            pending: result.pending,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _donutLegend(
                              Colors.green, 'Returned', result.returned),
                          const SizedBox(height: 6),
                          _donutLegend(Colors.red.shade400, 'Lost',
                              lost < 0 ? 0 : lost),
                          const SizedBox(height: 6),
                          _donutLegend(
                              Colors.grey, 'Pending', result.pending),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${result.returned} of ${result.atRiskTotal} at-risk returned'
                  '${result.avgDaysSaved > 0 ? ' · avg ${result.avgDaysSaved.toStringAsFixed(0)} days after prediction' : ''}',
                  style: TextStyle(color: vc.textMuted, fontSize: 12),
                ),
              ],
            ),
    );
  }

  Widget _donutLegend(Color color, String label, int count) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label: $count',
            style:
                const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final int returned;
  final int lost;
  final int pending;

  const _DonutPainter(
      {required this.returned, required this.lost, required this.pending});

  @override
  void paint(Canvas canvas, Size size) {
    final total = returned + lost + pending;
    if (total == 0) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = math.min(cx, cy) - 4;
    final innerR = outerR * 0.55;
    final rect =
        Rect.fromCircle(center: Offset(cx, cy), radius: outerR);
    const startAngle = -math.pi / 2;

    final segments = [
      (returned / total * math.pi * 2, Colors.green),
      (lost / total * math.pi * 2, Colors.red.shade400),
      (pending / total * math.pi * 2, Colors.grey),
    ];

    double current = startAngle;
    for (final (sweep, color) in segments) {
      if (sweep <= 0) continue;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(cx + innerR * math.cos(current),
            cy + innerR * math.sin(current))
        ..lineTo(cx + outerR * math.cos(current),
            cy + outerR * math.sin(current))
        ..arcTo(rect, current, sweep, false)
        ..lineTo(cx + innerR * math.cos(current + sweep),
            cy + innerR * math.sin(current + sweep))
        ..arcTo(
            Rect.fromCircle(center: Offset(cx, cy), radius: innerR),
            current + sweep,
            -sweep,
            false)
        ..close();
      canvas.drawPath(path, paint);
      current += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─── CARD 5: Conversation Engagement ─────────────────────────────────────────

class _EngagementCard extends StatelessWidget {
  final ConversationEngagementResult result;
  const _EngagementCard({required this.result});

  static const _bucketLabels = ['1 msg', '2 msgs', '3–5', '6–10', '10+'];

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final total = result.depthBuckets.fold(0, (a, b) => a + b);

    return _InsightCard(
      title: 'Conversation Engagement',
      icon: Icons.forum_outlined,
      color: VividColors.cyan,
      tooltip:
          'How deep conversations go — sessions split by 2-hour gaps between messages.',
      child: result.totalSessions < 20
          ? _emptyDataNote(vc,
              'Need more data to analyze engagement (${result.totalSessions} sessions so far).')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _miniMetric(
                        vc,
                        'Avg msgs/session',
                        result.avgMessagesPerSession.toStringAsFixed(1),
                        VividColors.cyan),
                    _miniMetric(
                        vc,
                        'Deep (3+ msgs)',
                        '${result.deepConversationPct.toStringAsFixed(0)}%',
                        Colors.teal),
                    _miniMetric(
                        vc,
                        'Broadcast-initiated',
                        '${result.broadcastInitiatedPct.toStringAsFixed(0)}%',
                        Colors.orange),
                  ],
                ),
                if (total > 0) ...[
                  const SizedBox(height: 14),
                  Text('Conversation depth',
                      style: TextStyle(
                          color: vc.textMuted, fontSize: 11)),
                  const SizedBox(height: 8),
                  ...List.generate(5, (i) {
                    final count = result.depthBuckets[i];
                    final pct = total > 0 ? count / total : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 38,
                            child: Text(_bucketLabels[i],
                                style: TextStyle(
                                    color: vc.textMuted, fontSize: 10)),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 12,
                                backgroundColor:
                                    vc.surfaceAlt,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                  VividColors.cyan.withValues(
                                      alpha: 0.4 + pct * 0.6),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('$count',
                              style: TextStyle(
                                  color: vc.textMuted, fontSize: 10)),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
    );
  }
}

// ─── CARD 6: Feature Adoption (always shown) ─────────────────────────────────

class _FeatureAdoptionCard extends StatelessWidget {
  final Client client;
  const _FeatureAdoptionCard({required this.client});

  static const _allFeatures = [
    ('conversations', Icons.forum, VividColors.cyan, 'Conversations'),
    ('broadcasts', Icons.campaign, Colors.orange, 'Broadcasts'),
    ('manager_chat', Icons.smart_toy, Colors.purple, 'Vivid AI'),
    ('labels', Icons.label, Colors.amber, 'Labels'),
    ('analytics', Icons.analytics, Colors.blueGrey, 'Analytics'),
    ('predictive_intelligence', Icons.auto_graph, Colors.teal,
        'Predictions'),
  ];

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final enabled = _allFeatures
        .where((f) => client.hasFeature(f.$1))
        .toList();
    final disabled = _allFeatures
        .where((f) => !client.hasFeature(f.$1))
        .toList();

    return _InsightCard(
      title: 'Feature Adoption',
      icon: Icons.layers_outlined,
      color: Colors.blueGrey,
      tooltip: 'Which Vivid features are active for this client.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (enabled.isNotEmpty) ...[
            Text('Active (${enabled.length})',
                style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: enabled
                  .map((f) => _featureChip(vc, f.$1, f.$2, f.$3, f.$4, true))
                  .toList(),
            ),
          ],
          if (disabled.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Not enabled (${disabled.length})',
                style: TextStyle(
                    color: vc.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: disabled
                  .map((f) => _featureChip(vc, f.$1, f.$2, f.$3, f.$4, false))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: enabled.length / _allFeatures.length,
              minHeight: 8,
              backgroundColor: vc.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${enabled.length} of ${_allFeatures.length} features active',
            style: TextStyle(color: vc.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _featureChip(VividColorScheme vc, String key, IconData icon,
      Color color, String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? color.withValues(alpha: 0.12)
            : vc.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? color.withValues(alpha: 0.35)
              : vc.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13,
              color: active ? color : vc.textMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: active ? color : vc.textMuted,
              fontSize: 11,
              fontWeight:
                  active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared painters ─────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<int> values;
  final int maxVal;
  final Color color;
  final bool drawDots;

  const _SparklinePainter(
      {required this.values, required this.maxVal, required this.color, this.drawDots = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || maxVal == 0) return;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final fill = Path();
    final step =
        values.length > 1 ? size.width / (values.length - 1) : 0.0;

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = i * step;
      final y =
          size.height - (values[i].clamp(0, maxVal) / maxVal * size.height);
      points.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo((values.length - 1) * step, size.height);
    fill.close();
    canvas.drawPath(fill, fillPaint);
    canvas.drawPath(path, linePaint);

    if (drawDots) {
      for (final pt in points) {
        canvas.drawCircle(pt, 3.5, dotPaint);
        canvas.drawCircle(pt, 3.5, Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
