import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/vivid_theme.dart';
import '../utils/initials_helper.dart';
import '../utils/time_utils.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

class BroadcastSummary {
  final String campaignName;
  final DateTime sentAt;
  final bool responded;
  const BroadcastSummary({
    required this.campaignName,
    required this.sentAt,
    required this.responded,
  });
}

class CustomerNote {
  final String id;
  final String customerPhone;
  final String noteText;
  final String createdBy;
  final DateTime createdAt;

  const CustomerNote({
    required this.id,
    required this.customerPhone,
    required this.noteText,
    required this.createdBy,
    required this.createdAt,
  });

  factory CustomerNote.fromJson(Map<String, dynamic> json) => CustomerNote(
    id: json['id']?.toString() ?? '',
    customerPhone: json['customer_phone']?.toString() ?? '',
    noteText: json['note_text']?.toString() ?? '',
    createdBy: json['created_by']?.toString() ?? '',
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );
}

class SideProfileData {
  final DateTime? lastCustomerMessage;
  final DateTime? customerSince;
  final int totalMessages;
  final int receivedCount;
  final int sentCount;
  final List<String> distinctLabels;
  final String? latestLabel;
  final int broadcastTotal;
  final int broadcastResponded;
  final BroadcastSummary? lastBroadcast;
  final String? lastHandledBy;
  final int paymentCount;
  final DateTime? lastAppointment;
  final int? avgReplyTimeMinutes;

  const SideProfileData({
    this.lastCustomerMessage,
    this.customerSince,
    required this.totalMessages,
    required this.receivedCount,
    required this.sentCount,
    required this.distinctLabels,
    this.latestLabel,
    required this.broadcastTotal,
    required this.broadcastResponded,
    this.lastBroadcast,
    this.lastHandledBy,
    required this.paymentCount,
    this.lastAppointment,
    this.avgReplyTimeMinutes,
  });
}

// ─── Session-level cache ──────────────────────────────────────────────────────
final Map<String, SideProfileData> _profileCache = {};

/// Tracks which customer phones have notes — updated on load/add/delete.
/// Used by the conversation list to show note indicators.
final ValueNotifier<Set<String>> phonesWithNotes = ValueNotifier({});

bool _phonesWithNotesInitialized = false;

void invalidateSideProfileCache(String phone) => _profileCache.remove(phone);

// ─── Data fetcher ─────────────────────────────────────────────────────────────

Future<SideProfileData> fetchSideProfileData(String phone) async {
  if (_profileCache.containsKey(phone)) return _profileCache[phone]!;

  final client = SupabaseService.adminClient;
  final msgsTable = ClientConfig.messagesTableName;
  final broadcastsTable = ClientConfig.broadcastsTableName;
  final recipientsTable =
      broadcastsTable.replaceAll('broadcasts', 'broadcast_recipients');

  // Parallel: all messages + all recipients
  final results = await Future.wait([
    client
        .from(msgsTable)
        .select('customer_message, manager_response, sent_by, created_at, label, media_url, is_voice_message')
        .eq('customer_phone', phone)
        .order('created_at', ascending: true),
    client
        .from(recipientsTable)
        .select('broadcast_id')
        .eq('customer_phone', phone),
  ]);

  final msgs = results[0] as List<dynamic>;
  final recipientRows = results[1] as List<dynamic>;

  // Process messages
  DateTime? lastCustomerMsg;
  DateTime? customerSince;
  int received = 0;
  int sent = 0;
  final labelSet = <String>{};
  final customerMsgTimes = <DateTime>[];
  DateTime? lastAppointment;
  int paymentCount = 0;

  // Avg reply time
  final List<int> replyMinutes = [];
  DateTime? lastOutboundTs;

  for (final m in msgs) {
    final custMsg = m['customer_message'];
    final agentMsg = m['manager_response'];
    final sentBy = m['sent_by']?.toString() ?? '';
    final rawTs = m['created_at']?.toString();
    final ts = rawTs != null ? DateTime.tryParse(rawTs) : null;
    final label = m['label']?.toString();

    // Customer since = first message timestamp (msgs sorted ASC)
    if (ts != null && customerSince == null) customerSince = ts;

    final mediaUrl = m['media_url']?.toString() ?? '';
    final isVoiceRow = m['is_voice_message'] == true;
    final hasCustomerContent = (custMsg?.toString() ?? '').isNotEmpty ||
        isVoiceRow || mediaUrl.isNotEmpty;
    final isInbound = hasCustomerContent && sentBy != 'Broadcast';
    final isOutbound = agentMsg != null &&
        agentMsg.toString().isNotEmpty &&
        sentBy.isNotEmpty &&
        sentBy != 'Broadcast';

    if (isInbound) {
      received++;
      if (ts != null) {
        customerMsgTimes.add(ts);
        if (lastCustomerMsg == null || ts.isAfter(lastCustomerMsg)) {
          lastCustomerMsg = ts;
        }
        // Compute avg customer reply time after an outbound message
        if (lastOutboundTs != null) {
          final delta = ts.difference(lastOutboundTs);
          if (delta.inMinutes > 0 && delta.inDays < 7) {
            replyMinutes.add(delta.inMinutes);
          }
          lastOutboundTs = null;
        }
      }
    }

    if (isOutbound) {
      sent++;
      if (ts != null) lastOutboundTs = ts;
    }

    if (label != null && label.isNotEmpty) {
      labelSet.add(label);
      if (ts != null) {
        final lc = label.toLowerCase();
        if (lc == 'appointment booked') {
          if (lastAppointment == null || ts.isAfter(lastAppointment)) {
            lastAppointment = ts;
          }
        } else if (lc == 'payment done') {
          paymentCount++;
        }
      }
    }
  }

  // Last handled by + latest label: scan messages DESC for most recent values
  String? lastAgent;
  String? latestLabel;
  for (final m in msgs.reversed) {
    final agentMsg = m['manager_response'];
    final sentBy = m['sent_by']?.toString() ?? '';
    final rowLabel = m['label']?.toString();
    if (lastAgent == null && agentMsg != null &&
        agentMsg.toString().isNotEmpty &&
        sentBy.isNotEmpty && sentBy != 'Broadcast') {
      lastAgent = sentBy;
    }
    if (latestLabel == null && rowLabel != null && rowLabel.isNotEmpty) {
      latestLabel = rowLabel;
    }
    if (lastAgent != null && latestLabel != null) break;
  }

  int? avgReplyTimeMinutes;
  if (replyMinutes.isNotEmpty) {
    avgReplyTimeMinutes =
        (replyMinutes.reduce((a, b) => a + b) / replyMinutes.length).round();
  }

  // Fetch broadcast details
  List<dynamic> broadcastRows = [];
  if (recipientRows.isNotEmpty) {
    final ids = recipientRows
        .map<dynamic>((r) => r['broadcast_id'])
        .where((id) => id != null)
        .toList();
    if (ids.isNotEmpty) {
      broadcastRows = await client
          .from(broadcastsTable)
          .select('id, campaign_name, sent_at')
          .inFilter('id', ids)
          .order('sent_at', ascending: false);
    }
  }

  int broadcastResponded = 0;
  BroadcastSummary? lastBroadcast;

  for (var i = 0; i < broadcastRows.length; i++) {
    final b = broadcastRows[i];
    final rawSentAt = b['sent_at']?.toString();
    final broadcastSentAt =
        rawSentAt != null ? DateTime.tryParse(rawSentAt) : null;
    final responded = broadcastSentAt != null &&
        customerMsgTimes.any((t) => t.isAfter(broadcastSentAt));
    if (responded) broadcastResponded++;
    if (i == 0) {
      lastBroadcast = BroadcastSummary(
        campaignName: b['campaign_name']?.toString() ?? 'Untitled',
        sentAt: broadcastSentAt ?? DateTime.now(),
        responded: responded,
      );
    }
  }

  final data = SideProfileData(
    lastCustomerMessage: lastCustomerMsg,
    customerSince: customerSince,
    totalMessages: msgs.length,
    receivedCount: received,
    sentCount: sent,
    distinctLabels: labelSet.toList(),
    latestLabel: latestLabel,
    broadcastTotal: broadcastRows.length,
    broadcastResponded: broadcastResponded,
    lastBroadcast: lastBroadcast,
    lastHandledBy: lastAgent,
    paymentCount: paymentCount,
    lastAppointment: lastAppointment,
    avgReplyTimeMinutes: avgReplyTimeMinutes,
  );

  _profileCache[phone] = data;
  return data;
}

// ─── Notes CRUD ───────────────────────────────────────────────────────────────

Future<void> _ensurePhonesWithNotesInitialized() async {
  if (_phonesWithNotesInitialized) return;
  _phonesWithNotesInitialized = true;
  try {
    final client = SupabaseService.adminClient;
    final clientId = ClientConfig.currentClient?.id ?? '';
    final rows = await client
        .from('customer_notes')
        .select('customer_phone')
        .eq('client_id', clientId);
    final phones = (rows as List<dynamic>)
        .map<String>((r) => r['customer_phone']?.toString() ?? '')
        .where((p) => p.isNotEmpty)
        .toSet();
    phonesWithNotes.value = phones;
  } catch (_) {
    // Table doesn't exist yet — graceful degradation
  }
}

Future<List<CustomerNote>> fetchCustomerNotes(String phone) async {
  try {
    final client = SupabaseService.adminClient;
    final clientId = ClientConfig.currentClient?.id ?? '';
    final rows = await client
        .from('customer_notes')
        .select()
        .eq('client_id', clientId)
        .eq('customer_phone', phone)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((r) => CustomerNote.fromJson(r as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<CustomerNote?> saveCustomerNote(String phone, String text) async {
  try {
    final client = SupabaseService.adminClient;
    final clientId = ClientConfig.currentClient?.id ?? '';
    final row = await client.from('customer_notes').insert({
      'client_id': clientId,
      'customer_phone': phone,
      'note_text': text,
      'created_by': ClientConfig.currentUserName,
    }).select().single();
    return CustomerNote.fromJson(row);
  } catch (_) {
    return null;
  }
}

Future<void> deleteCustomerNote(String noteId) async {
  try {
    final client = SupabaseService.adminClient;
    await client.from('customer_notes').delete().eq('id', noteId);
  } catch (_) {}
}

// ─── Panel widget ─────────────────────────────────────────────────────────────

class SideProfilePanel extends StatefulWidget {
  final String customerPhone;
  final String customerName;
  final VoidCallback onClose;

  const SideProfilePanel({
    super.key,
    required this.customerPhone,
    required this.customerName,
    required this.onClose,
  });

  @override
  State<SideProfilePanel> createState() => _SideProfilePanelState();
}

class _SideProfilePanelState extends State<SideProfilePanel>
    with SingleTickerProviderStateMixin {
  SideProfileData? _data;
  bool _loading = true;
  late AnimationController _shimmerCtrl;

  // Notes state
  List<CustomerNote> _notes = [];
  bool _notesLoading = true;
  bool _addingNote = false;
  bool _savingNote = false;
  bool _showAllNotes = false;
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _load(widget.customerPhone);
    _ensurePhonesWithNotesInitialized();
  }

  @override
  void didUpdateWidget(SideProfilePanel old) {
    super.didUpdateWidget(old);
    if (old.customerPhone != widget.customerPhone) {
      setState(() {
        _loading = true;
        _data = null;
        _notes = [];
        _notesLoading = true;
        _addingNote = false;
        _showAllNotes = false;
        _noteCtrl.clear();
      });
      _load(widget.customerPhone);
    }
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load(String phone) async {
    try {
      final d = await fetchSideProfileData(phone);
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
    _loadNotes(phone);
  }

  Future<void> _loadNotes(String phone) async {
    final notes = await fetchCustomerNotes(phone);
    if (mounted) {
      setState(() { _notes = notes; _notesLoading = false; });
      // Update global indicator
      final updated = Set<String>.from(phonesWithNotes.value);
      if (notes.isNotEmpty) {
        updated.add(phone);
      } else {
        updated.remove(phone);
      }
      phonesWithNotes.value = updated;
    }
  }

  Future<void> _submitNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _savingNote = true);
    final note = await saveCustomerNote(widget.customerPhone, text);
    if (mounted) {
      if (note != null) {
        _noteCtrl.clear();
        final updated = [note, ..._notes];
        setState(() {
          _notes = updated;
          _addingNote = false;
          _savingNote = false;
        });
        // Update indicator
        final phones = Set<String>.from(phonesWithNotes.value)
          ..add(widget.customerPhone);
        phonesWithNotes.value = phones;
      } else {
        setState(() => _savingNote = false);
      }
    }
  }

  Future<void> _deleteNote(String noteId) async {
    await deleteCustomerNote(noteId);
    if (mounted) {
      final updated = _notes.where((n) => n.id != noteId).toList();
      setState(() => _notes = updated);
      final phones = Set<String>.from(phonesWithNotes.value);
      if (updated.isEmpty) phones.remove(widget.customerPhone);
      phonesWithNotes.value = phones;
    }
  }

  // ── label colour map ──────────────────────────────────────────────────────
  static const _kLabelColors = <String, (Color, Color)>{
    'General':            (Color(0x1F64748B), Color(0xFF94A3B8)),
    'Booking':            (Color(0x1A06B6D4), Color(0xFF22D3EE)),
    'Pricing':            (Color(0x1AA855F7), Color(0xFFC084FC)),
    'Enquiry':            (Color(0x14FBBF24), Color(0xFFFBBF24)),
    'Appointment Booked': (Color(0x1A34D399), Color(0xFF34D399)),
    'Payment Done':       (Color(0x1A34D399), Color(0xFF34D399)),
  };
  (Color, Color) _labelColor(String l) =>
      _kLabelColors[l] ?? (const Color(0x1F64748B), const Color(0xFF94A3B8));

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  String _shortRelTime(DateTime? utc) {
    if (utc == null) return '--';
    final s = TimeUtils.formatRelativeTime(utc);
    return s == 'Yesterday' ? '1d' : s;
  }

  String _formatDate(DateTime? utc) {
    if (utc == null) return 'None';
    final bt = TimeUtils.toBahrainTime(utc);
    return '${_months[bt.month - 1]} ${bt.day}, ${bt.year}';
  }

  String _formatNoteDate(DateTime utc) {
    final bt = TimeUtils.toBahrainTime(utc);
    return '${_months[bt.month - 1]} ${bt.day}';
  }

  String _shortDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    if (minutes < 1440) return '${(minutes / 60).round()}h';
    return '${(minutes / 1440).round()}d';
  }

  // ── shimmer ───────────────────────────────────────────────────────────────
  Widget _shimBox(double h, {double? w, double r = 6}) {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, __) => Container(
        height: h,
        width: w,
        decoration: BoxDecoration(
          color: Colors.white.withValues(
              alpha: 0.04 + _shimmerCtrl.value * 0.06),
          borderRadius: BorderRadius.circular(r),
        ),
      ),
    );
  }

  Widget _buildShimmer() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _shimBox(48, w: 48, r: 14),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _shimBox(14, w: 130),
          const SizedBox(height: 6),
          _shimBox(11, w: 90),
        ])),
      ]),
      const SizedBox(height: 24),
      _shimBox(64),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _shimBox(52)),
        const SizedBox(width: 8),
        Expanded(child: _shimBox(52)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _shimBox(52)),
        const SizedBox(width: 8),
        Expanded(child: _shimBox(52)),
      ]),
      const SizedBox(height: 16),
      _shimBox(8),
      const SizedBox(height: 16),
      Row(children: [
        _shimBox(24, w: 70, r: 12),
        const SizedBox(width: 8),
        _shimBox(24, w: 88, r: 12),
      ]),
    ]),
  );

  // ── helpers ───────────────────────────────────────────────────────────────
  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: const TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700,
      letterSpacing: 1.5, color: Color(0xFF3D5A80),
    )),
  );

  Widget _divider() => Container(
    height: 1, color: Colors.white.withValues(alpha: 0.04));

  // ── Section 1: Header ─────────────────────────────────────────────────────
  Widget _buildCustomerHeader() {
    final name = widget.customerName;
    final phone = widget.customerPhone;
    final initials = getInitials(name);
    final isAr = isArabicText(initials);
    const avatarColors = [
      Color(0xFF0550B8), Color(0xFF1E3A8A),
      Color(0xFF065E80), Color(0xFF054D73),
    ];
    final avatarColor = avatarColors[phone.hashCode.abs() % avatarColors.length];
    final topLabel = _data?.latestLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: avatarColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text(initials,
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(
            color: Color(0xFFE2E8F0), fontSize: 15, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis, maxLines: 1),
          const SizedBox(height: 3),
          Text(phone, style: const TextStyle(
            color: Color(0xFF4B6584), fontSize: 12)),
          if (topLabel != null) ...[
            const SizedBox(height: 6),
            _labelPill(topLabel, small: true),
          ],
        ])),
        _CloseButton(onTap: widget.onClose),
      ]),
    );
  }

  // ── Section 2: Stats ──────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final d = _data!;
    final lastTexted = _shortRelTime(d.lastCustomerMessage);
    final campaignsSubtitle = d.broadcastTotal > 0
        ? 'replied to ${d.broadcastResponded}' : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.025),
              Colors.white.withValues(alpha: 0.008),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IntrinsicHeight(
          child: Row(children: [
            _statCell('Last Texted', lastTexted),
            Container(width: 1, color: Colors.white.withValues(alpha: 0.06)),
            _statCell('Messages', '${d.totalMessages}'),
            Container(width: 1, color: Colors.white.withValues(alpha: 0.06)),
            _statCell('Campaigns', '${d.broadcastTotal}',
                subtitle: campaignsSubtitle),
          ]),
        ),
      ),
    );
  }

  Widget _statCell(String label, String value, {String? subtitle}) => Expanded(
    child: Container(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value,
            overflow: TextOverflow.ellipsis, maxLines: 1,
            style: const TextStyle(
              color: Color(0xFFE2E8F0), fontSize: 16,
              fontWeight: FontWeight.w700, height: 1)),
          const SizedBox(height: 5),
          Text(label,
            overflow: TextOverflow.ellipsis, maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF4B6584), fontSize: 10,
              fontWeight: FontWeight.w500, letterSpacing: 0.3),
            textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle,
              overflow: TextOverflow.ellipsis, maxLines: 1,
              style: const TextStyle(
                color: Color(0xFF3D5A80), fontSize: 9,
                fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
          ],
        ]),
      ),
    ),
  );

  // ── Section 3: Info grid (2×2) ────────────────────────────────────────────
  Widget _buildInfoGrid() {
    final d = _data!;
    final sinceStr = _formatDate(d.customerSince);
    final spendStr = d.paymentCount > 0
        ? '${d.paymentCount} payment${d.paymentCount == 1 ? '' : 's'}'
        : '0 payments';
    final apptStr = _formatDate(d.lastAppointment);
    final replyStr = d.avgReplyTimeMinutes != null
        ? _shortDuration(d.avgReplyTimeMinutes!) : '--';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(children: [
        Row(children: [
          Expanded(child: _infoCell('FIRST MESSAGE', sinceStr)),
          const SizedBox(width: 8),
          Expanded(child: _infoCell('TOTAL SPEND', spendStr)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _infoCell('LAST APPOINTMENT', apptStr)),
          const SizedBox(width: 8),
          Expanded(child: _infoCell('AVG REPLY TIME', replyStr)),
        ]),
      ]),
    );
  }

  Widget _infoCell(String label, String value) => Container(
    constraints: const BoxConstraints(minHeight: 52),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.02),
          Colors.white.withValues(alpha: 0.006),
        ],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(
          fontSize: 9, fontWeight: FontWeight.w600,
          letterSpacing: 1.2, color: Color(0xFF3D5A80))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(
          color: Color(0xFFE2E8F0), fontSize: 13, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis, maxLines: 1),
      ],
    ),
  );

  // ── Section 4: Messages bar ───────────────────────────────────────────────
  Widget _buildMessagesBar() {
    final d = _data!;
    final total = d.receivedCount + d.sentCount;
    final recvFrac = total > 0 ? d.receivedCount / total : 0.5;
    final sentFrac = total > 0 ? d.sentCount / total : 0.5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('MESSAGES'),
        LayoutBuilder(builder: (_, cons) {
          const gap = 3.0;
          final tw = cons.maxWidth;
          if (tw < 16) return const SizedBox.shrink();
          final maxBar = (tw - gap - 8.0).clamp(4.0, double.infinity);
          final rw = ((tw - gap) * recvFrac).clamp(4.0, maxBar);
          final sw = ((tw - gap) * sentFrac).clamp(4.0, maxBar);
          return Row(children: [
            Container(width: rw, height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF0EA5E9),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
              )),
            const SizedBox(width: gap),
            Container(width: sw, height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
              )),
          ]);
        }),
        const SizedBox(height: 12),
        Row(children: [
          const _Dot(color: Color(0xFF0EA5E9)),
          const SizedBox(width: 5),
          Text('${d.receivedCount} received',
            style: const TextStyle(color: Color(0xFF4B6584), fontSize: 11)),
          const Spacer(),
          Text('${d.sentCount} sent',
            style: const TextStyle(color: Color(0xFF4B6584), fontSize: 11)),
          const SizedBox(width: 5),
          _Dot(color: Colors.white.withValues(alpha: 0.25)),
        ]),
      ]),
    );
  }

  // ── Section 5: Topics ─────────────────────────────────────────────────────
  Widget _buildTopics() {
    final labels = _data!.distinctLabels;
    if (labels.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('TOPICS DISCUSSED'),
        Wrap(spacing: 8, runSpacing: 8,
          children: labels.map(_labelPill).toList()),
      ]),
    );
  }

  Widget _labelPill(String label, {bool small = false}) {
    final (bg, fg) = _labelColor(label);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 8 : 14, vertical: small ? 3 : 6),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(
        color: fg, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }

  // ── Section 6: Team Notes ─────────────────────────────────────────────────
  Widget _buildTeamNotes() {
    final displayNotes = _showAllNotes ? _notes : _notes.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('TEAM NOTES'),

        if (_notesLoading)
          Column(children: [
            _shimBox(40, r: 8),
            const SizedBox(height: 6),
            _shimBox(32, r: 8),
          ])
        else if (_notes.isEmpty && !_addingNote)
          _buildEmptyNotes()
        else ...[
          ...displayNotes.map(_buildNoteCard),
          if (_notes.length > 3 && !_showAllNotes) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _showAllNotes = true),
              child: Text(
                'Show all (${_notes.length})',
                style: const TextStyle(
                  color: Color(0xFF3B82F6), fontSize: 11,
                  fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],

        const SizedBox(height: 10),
        if (_addingNote)
          _buildAddNoteField()
        else
          _buildAddNoteButton(),
      ]),
    );
  }

  Widget _buildEmptyNotes() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 6),
    child: Text('No notes yet',
      style: TextStyle(color: Color(0xFF4B6584), fontSize: 12)),
  );

  Widget _buildNoteCard(CustomerNote note) {
    final isOwn = note.createdBy == ClientConfig.currentUserName;
    return _NoteCard(
      note: note,
      isOwn: isOwn,
      onDelete: () => _deleteNote(note.id),
      formatDate: _formatNoteDate,
    );
  }

  Widget _buildAddNoteButton() => GestureDetector(
    onTap: () => setState(() => _addingNote = true),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x0800D4AA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x4D00D4AA)),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add, size: 14, color: Color(0xFF00D4AA)),
        SizedBox(width: 6),
        Text('Add Note', style: TextStyle(
          color: Color(0xFF00D4AA), fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  Widget _buildAddNoteField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
        ),
        child: TextField(
          controller: _noteCtrl,
          autofocus: true,
          maxLines: 3,
          minLines: 2,
          style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Add a note about this customer...',
            hintStyle: TextStyle(color: Color(0xFF4B6584), fontSize: 12),
            contentPadding: EdgeInsets.all(10),
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _submitNote(),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        GestureDetector(
          onTap: _savingNote ? null : _submitNote,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _savingNote
                ? const SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                : const Text('Save', style: TextStyle(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() {
            _addingNote = false;
            _noteCtrl.clear();
          }),
          child: const Text('Cancel', style: TextStyle(
            color: Color(0xFF4B6584), fontSize: 11)),
        ),
      ]),
    ],
  );

  // ── Section 7: Last campaign ──────────────────────────────────────────────
  Widget _buildLastCampaign() {
    final d = _data!;
    if (d.broadcastTotal == 0 || d.lastBroadcast == null) {
      return const SizedBox.shrink();
    }
    final b = d.lastBroadcast!;
    final bt = TimeUtils.toBahrainTime(b.sentAt);
    final dateStr = '${bt.day} ${_months[bt.month - 1]}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('LAST CAMPAIGN'),
        RichText(text: TextSpan(style: const TextStyle(fontSize: 12), children: [
          TextSpan(text: '${d.broadcastTotal}',
            style: const TextStyle(
              color: Color(0xFFE2E8F0), fontWeight: FontWeight.w700)),
          TextSpan(
            text: ' broadcast${d.broadcastTotal == 1 ? "" : "s"} sent',
            style: const TextStyle(color: Color(0xFF4B6584))),
        ])),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(children: [
            Container(width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: b.responded
                    ? const Color(0xFF34D399) : const Color(0xFF4B6584),
                boxShadow: b.responded ? [
                  BoxShadow(color: const Color(0xFF34D399).withValues(alpha: 0.5),
                    blurRadius: 6),
                ] : null,
              )),
            const SizedBox(width: 10),
            Expanded(child: Text(b.campaignName,
              style: const TextStyle(
                color: Color(0xFFE2E8F0), fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis, maxLines: 1)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min, children: [
              Text(dateStr, style: const TextStyle(
                color: Color(0xFF4B6584), fontSize: 10)),
              const SizedBox(height: 2),
              Text(b.responded ? 'Replied' : 'No response',
                style: TextStyle(
                  color: b.responded
                      ? const Color(0xFF34D399) : const Color(0xFF4B6584),
                  fontSize: 10, fontWeight: FontWeight.w500)),
            ]),
          ]),
        ),
      ]),
    );
  }

  // ── Section 8: Last handled by ────────────────────────────────────────────
  Widget _buildLastHandledBy() {
    final agent = _data!.lastHandledBy;
    if (agent == null || agent.isEmpty) return const SizedBox.shrink();
    final initials = getInitials(agent);
    final isAr = isArabicText(initials);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('LAST HANDLED BY'),
        Row(children: [
          Container(width: 28, height: 28,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle),
            child: Center(child: Text(initials,
              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
              style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
          const SizedBox(width: 8),
          Expanded(child: Text(agent,
            style: const TextStyle(
              color: Color(0xFFE2E8F0), fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis)),
        ]),
      ]),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      width: 296,
      decoration: BoxDecoration(
        // Match the header/sidebar surface color, not the chat background
        color: vc.surface,
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: _loading ? _buildShimmer() : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_data == null) {
      return const Center(
        child: Text('Unable to load profile',
          style: TextStyle(color: Color(0xFF4B6584), fontSize: 13)));
    }
    final d = _data!;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildCustomerHeader(),
        _divider(),
        _buildStatsRow(),
        _buildInfoGrid(),
        const SizedBox(height: 16),
        _divider(),
        _buildMessagesBar(),
        if (d.distinctLabels.isNotEmpty) ...[
          _divider(),
          _buildTopics(),
        ],
        _divider(),
        _buildTeamNotes(),
        if (d.broadcastTotal > 0 && d.lastBroadcast != null) ...[
          _divider(),
          _buildLastCampaign(),
        ],
        if (d.lastHandledBy?.isNotEmpty == true) ...[
          _divider(),
          _buildLastHandledBy(),
        ],
      ]),
    );
  }
}

// ─── Note card with hover-delete ─────────────────────────────────────────────

class _NoteCard extends StatefulWidget {
  final CustomerNote note;
  final bool isOwn;
  final VoidCallback onDelete;
  final String Function(DateTime) formatDate;

  const _NoteCard({
    required this.note,
    required this.isOwn,
    required this.onDelete,
    required this.formatDate,
  });

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _hovered ? 0.04 : 0.025),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.notes_rounded, size: 12,
                color: Color(0xFF4B6584)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note.noteText,
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0), fontSize: 13, height: 1.5)),
                  const SizedBox(height: 4),
                  Text('— ${note.createdBy}, ${widget.formatDate(note.createdAt)}',
                    style: const TextStyle(
                      color: Color(0xFF4B6584), fontSize: 11)),
                ],
              ),
            ),
            if (widget.isOwn && _hovered) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: widget.onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.delete_outline_rounded,
                    size: 14, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Close button with hover ──────────────────────────────────────────────────

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 28, height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _hovered
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Icon(Icons.close_rounded, size: 15,
          color: _hovered ? Colors.white : const Color(0xFF4B6584)),
      ),
    ),
  );
}

// ─── Small helpers ────────────────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 6, height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
