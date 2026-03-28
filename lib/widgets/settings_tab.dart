import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/admin_provider.dart';
import '../services/supabase_service.dart';
import '../theme/vivid_theme.dart';
import '../utils/toast_service.dart';

/// Settings tab for Vivid super admins.
/// Provides Meta API config, per-client overview, table health, and system health.
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  // Meta API values (display only — edited via dialog)
  Map<String, String> _settings = {};
  bool _isLoadingSettings = false;

  // Table status cache: tableName → row count (null = missing)
  Map<String, int?> _tableStatus = {};
  bool _isCheckingTables = false;

  // System health
  bool _supabaseOk = false;
  bool _isCheckingHealth = false;
  DateTime? _lastActivityTimestamp;
  Map<String, int> _tableCounts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAll();
    });
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadSettings(),
      _checkTables(),
      _checkSystemHealth(),
    ]);
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoadingSettings = true);
    try {
      _settings = await SupabaseService.instance.fetchSystemSettings();
    } catch (_) {}
    if (mounted) setState(() => _isLoadingSettings = false);
  }

  /// Compute expected tables per client based on enabled features + stored table names.
  static List<(String label, String tableName)> _getExpectedTables(Client client) {
    final tables = <(String, String)>[];
    final features = client.enabledFeatures;

    if (features.contains('conversations') && client.messagesTable != null) {
      tables.add(('Messages', client.messagesTable!));
    }
    if (features.contains('broadcasts')) {
      if (client.broadcastsTable != null) tables.add(('Broadcasts', client.broadcastsTable!));
      if (client.broadcastRecipientsTable != null) tables.add(('Recipients', client.broadcastRecipientsTable!));
    }
    if (features.contains('manager_chat') && client.managerChatsTable != null) {
      tables.add(('Manager Chats', client.managerChatsTable!));
    }
    if (features.contains('whatsapp_templates') && client.templatesTable != null) {
      tables.add(('Templates', client.templatesTable!));
    }
    if (features.contains('predictive_intelligence') && client.customerPredictionsTable != null) {
      tables.add(('Predictions', client.customerPredictionsTable!));
    }
    return tables;
  }

  static const _systemTables = [
    ('Core', 'clients'),
    ('Core', 'users'),
    ('Core', 'activity_logs'),
    ('Core', 'ai_chat_settings'),
    ('Core', 'system_settings'),
    ('Core', 'password_reset_codes'),
    ('Core', 'label_trigger_words'),
    ('Outreach', 'vivid_outreach_contacts'),
    ('Outreach', 'vivid_outreach_messages'),
    ('Outreach', 'vivid_outreach_broadcasts'),
    ('Outreach', 'vivid_outreach_broadcast_recipients'),
    ('Outreach', 'vivid_outreach_whatsapp_templates'),
    ('Finance', 'vivid_financials'),
  ];

  Future<void> _checkTables() async {
    setState(() => _isCheckingTables = true);
    final clients = context.read<AdminProvider>().clients;

    // Collect all table names to check
    final allTables = <String>[];
    for (final c in clients) {
      for (final (_, tableName) in _getExpectedTables(c)) {
        if (!allTables.contains(tableName)) allTables.add(tableName);
      }
    }
    for (final (_, tableName) in _systemTables) {
      if (!allTables.contains(tableName)) allTables.add(tableName);
    }

    final status = await SupabaseService.instance.checkTablesStatus(allTables);
    if (mounted) setState(() { _tableStatus = status; _isCheckingTables = false; });
  }

  Future<void> _checkSystemHealth() async {
    setState(() => _isCheckingHealth = true);
    try {
      // Supabase connection
      await SupabaseService.client.from('clients').select('id').limit(1);
      _supabaseOk = true;
    } catch (_) {
      _supabaseOk = false;
    }

    // Last activity
    try {
      final logs = await SupabaseService.instance.fetchActivityLogs(limit: 1);
      if (logs.isNotEmpty) _lastActivityTimestamp = logs.first.createdAt;
    } catch (_) {}

    // Table row counts for key tables
    final countTables = ['clients', 'users', 'activity_logs'];
    for (final t in countTables) {
      _tableCounts[t] = await SupabaseService.instance.getTableRowCount(t);
    }

    if (mounted) setState(() => _isCheckingHealth = false);
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final padding = isMobile ? 16.0 : 32.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(vc, Icons.settings, 'Settings', isMobile),
              SizedBox(height: isMobile ? 16 : 24),
              _buildMetaApiSection(vc, isMobile),
              SizedBox(height: isMobile ? 16 : 24),
              _buildOutreachConfigSection(vc, isMobile),
              SizedBox(height: isMobile ? 16 : 24),
              _buildClientConfigOverview(vc, isMobile),
              SizedBox(height: isMobile ? 16 : 24),
              _buildDatabaseTablesSection(vc, isMobile),
              SizedBox(height: isMobile ? 16 : 24),
              _buildSystemHealthSection(vc, isMobile),
            ],
          ),
        );
      },
    );
  }

  // ── Section Header ──────────────────────────────────

  Widget _buildSectionHeader(VividColorScheme vc, IconData icon, String title, bool isMobile) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: VividColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: VividColors.cyan.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: isMobile ? 18 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'System-wide configuration',
                style: TextStyle(color: vc.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loadAll,
          icon: Icon(Icons.refresh, color: vc.textMuted),
          tooltip: 'Refresh all',
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // SECTION A: Meta WhatsApp API
  // ═══════════════════════════════════════════════════════

  Widget _buildMetaApiSection(VividColorScheme vc, bool isMobile) {
    return _sectionContainer(
      vc,
      icon: Icons.api,
      title: 'Meta WhatsApp API',
      trailing: TextButton.icon(
        onPressed: () => _showMetaApiDialog(vc),
        icon: const Icon(Icons.edit, size: 16, color: VividColors.cyan),
        label: const Text('Edit', style: TextStyle(color: VividColors.cyan, fontSize: 13)),
      ),
      child: _isLoadingSettings
          ? const _LoadingIndicator()
          : Column(
              children: [
                _settingRow(vc, 'API Version', _effectiveValue('meta_api_version', SupabaseService.metaApiVersion)),
                _settingRow(vc, 'Access Token', _maskToken(_effectiveValue('meta_access_token', SupabaseService.metaAccessToken))),
                _settingRow(vc, 'WABA ID', _effectiveValue('meta_waba_id', SupabaseService.metaWabaId)),
                _settingRow(vc, 'App ID', _effectiveValue('meta_app_id', SupabaseService.metaAppId)),
              ],
            ),
    );
  }

  String _effectiveValue(String settingsKey, String fallback) {
    final v = _settings[settingsKey];
    return (v != null && v.isNotEmpty) ? v : fallback;
  }

  String _maskToken(String token) {
    if (token.length <= 8) return token;
    return '${'*' * 16}${token.substring(token.length - 8)}';
  }

  Widget _settingRow(VividColorScheme vc, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: vc.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: vc.textPrimary, fontSize: 13, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  void _showMetaApiDialog(VividColorScheme vc) {
    final apiVersionCtrl = TextEditingController(text: _effectiveValue('meta_api_version', SupabaseService.metaApiVersion));
    final tokenCtrl = TextEditingController(text: _effectiveValue('meta_access_token', SupabaseService.metaAccessToken));
    final wabaCtrl = TextEditingController(text: _effectiveValue('meta_waba_id', SupabaseService.metaWabaId));
    final appIdCtrl = TextEditingController(text: _effectiveValue('meta_app_id', SupabaseService.metaAppId));

    showDialog(
      context: context,
      builder: (ctx) {
        final vc = ctx.vividColors;
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final screenWidth = MediaQuery.of(ctx).size.width;
            final isMobileDialog = screenWidth < 600;
            return AlertDialog(
              backgroundColor: vc.surface,
              insetPadding: isMobileDialog
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24)
                  : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              title: Row(
                children: [
                  const Icon(Icons.api, color: VividColors.cyan, size: 20),
                  const SizedBox(width: 8),
                  Flexible(child: Text('Meta API Settings', style: TextStyle(color: vc.textPrimary, fontSize: 16))),
                ],
              ),
              content: SizedBox(
                width: isMobileDialog ? screenWidth : 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(vc, apiVersionCtrl, 'API Version', 'e.g., v21.0'),
                    const SizedBox(height: 12),
                    _dialogField(vc, tokenCtrl, 'Access Token', 'Meta access token'),
                    const SizedBox(height: 12),
                    _dialogField(vc, wabaCtrl, 'WABA ID', 'WhatsApp Business Account ID'),
                    const SizedBox(height: 12),
                    _dialogField(vc, appIdCtrl, 'App ID', 'Meta App ID'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: vc.textMuted)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final svc = SupabaseService.instance;
                          await svc.updateSystemSetting('meta_api_version', apiVersionCtrl.text.trim());
                          await svc.updateSystemSetting('meta_access_token', tokenCtrl.text.trim());
                          await svc.updateSystemSetting('meta_waba_id', wabaCtrl.text.trim());
                          await svc.updateSystemSetting('meta_app_id', appIdCtrl.text.trim());
                          // Apply immediately
                          await svc.loadAndApplySystemSettings();
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadSettings();
                          if (mounted) {
                            VividToast.show(context,
                              message: 'Meta API settings saved',
                              type: ToastType.success,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: VividColors.brightBlue),
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dialogField(VividColorScheme vc, TextEditingController controller, String label, String hint) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: vc.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: vc.textMuted),
        hintStyle: TextStyle(color: vc.textMuted.withOpacity(0.5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: vc.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: VividColors.cyan),
        ),
        filled: true,
        fillColor: vc.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SECTION: Outreach Configuration
  // ═══════════════════════════════════════════════════════

  Widget _buildOutreachConfigSection(VividColorScheme vc, bool isMobile) {
    return _sectionContainer(
      vc,
      icon: Icons.rocket_launch,
      title: 'Outreach Configuration',
      trailing: TextButton.icon(
        onPressed: () => _showOutreachConfigDialog(vc),
        icon: const Icon(Icons.edit, size: 16, color: VividColors.cyan),
        label: const Text('Edit', style: TextStyle(color: VividColors.cyan, fontSize: 13)),
      ),
      child: _isLoadingSettings
          ? const _LoadingIndicator()
          : Column(
              children: [
                _settingRow(vc, 'Phone', _effectiveValue('outreach_phone', SupabaseService.outreachPhone)),
                _settingRow(vc, 'WABA ID', _effectiveValue('outreach_waba_id', SupabaseService.outreachWabaId)),
                _settingRow(vc, 'Meta Access Token', _maskToken(_effectiveValue('outreach_meta_access_token', SupabaseService.outreachMetaAccessToken))),
                _settingRow(vc, 'Send Webhook', _effectiveValue('outreach_send_webhook', SupabaseService.outreachSendWebhook)),
                _settingRow(vc, 'Broadcast Webhook', _effectiveValue('outreach_broadcast_webhook', SupabaseService.outreachBroadcastWebhook)),
              ],
            ),
    );
  }

  void _showOutreachConfigDialog(VividColorScheme vc) {
    final phoneCtrl = TextEditingController(text: _effectiveValue('outreach_phone', SupabaseService.outreachPhone));
    final wabaCtrl = TextEditingController(text: _effectiveValue('outreach_waba_id', SupabaseService.outreachWabaId));
    final tokenCtrl = TextEditingController(text: _effectiveValue('outreach_meta_access_token', SupabaseService.outreachMetaAccessToken));
    final sendCtrl = TextEditingController(text: _effectiveValue('outreach_send_webhook', SupabaseService.outreachSendWebhook));
    final broadcastCtrl = TextEditingController(text: _effectiveValue('outreach_broadcast_webhook', SupabaseService.outreachBroadcastWebhook));

    showDialog(
      context: context,
      builder: (ctx) {
        final vc = ctx.vividColors;
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final screenWidth = MediaQuery.of(ctx).size.width;
            final isMobileDialog = screenWidth < 600;
            return AlertDialog(
              backgroundColor: vc.surface,
              insetPadding: isMobileDialog
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24)
                  : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              title: Row(
                children: [
                  const Icon(Icons.rocket_launch, color: VividColors.cyan, size: 20),
                  const SizedBox(width: 8),
                  Flexible(child: Text('Outreach Configuration', style: TextStyle(color: vc.textPrimary, fontSize: 16))),
                ],
              ),
              content: SizedBox(
                width: isMobileDialog ? screenWidth : 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(vc, phoneCtrl, 'Outreach Phone', 'e.g., 97334653659'),
                    const SizedBox(height: 12),
                    _dialogField(vc, wabaCtrl, 'WABA ID', 'Meta WhatsApp Business Account ID'),
                    const SizedBox(height: 12),
                    _dialogField(vc, tokenCtrl, 'Meta Access Token', 'Permanent access token for outreach WABA'),
                    const SizedBox(height: 12),
                    _dialogField(vc, sendCtrl, 'Send Webhook URL', 'n8n webhook for sending messages'),
                    const SizedBox(height: 12),
                    _dialogField(vc, broadcastCtrl, 'Broadcast Webhook URL', 'n8n webhook for broadcast campaigns'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: vc.textMuted)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final svc = SupabaseService.instance;
                          await svc.updateSystemSetting('outreach_phone', phoneCtrl.text.trim());
                          await svc.updateSystemSetting('outreach_waba_id', wabaCtrl.text.trim());
                          await svc.updateSystemSetting('outreach_meta_access_token', tokenCtrl.text.trim());
                          await svc.updateSystemSetting('outreach_send_webhook', sendCtrl.text.trim());
                          await svc.updateSystemSetting('outreach_broadcast_webhook', broadcastCtrl.text.trim());
                          // Reload outreach config immediately
                          await svc.loadOutreachConfig();
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadSettings();
                          if (mounted) {
                            VividToast.show(context,
                              message: 'Outreach configuration saved',
                              type: ToastType.success,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: VividColors.brightBlue),
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // SECTION B: Per-Client Configuration Overview
  // ═══════════════════════════════════════════════════════

  Widget _buildClientConfigOverview(VividColorScheme vc, bool isMobile) {
    final clients = context.watch<AdminProvider>().clients;

    return _sectionContainer(
      vc,
      icon: Icons.list_alt,
      title: 'Per-Client Configuration',
      child: clients.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No clients found.', style: TextStyle(color: vc.textMuted)),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(vc.surfaceAlt),
                dataRowColor: WidgetStateProperty.resolveWith<Color?>((states) => null),
                columnSpacing: 16,
                horizontalMargin: 12,
                columns: [
                  DataColumn(label: Text('Client', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600, fontSize: 12))),
                  DataColumn(label: Text('Features', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600, fontSize: 12))),
                  DataColumn(label: Text('Msg Table', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600, fontSize: 12))),
                  DataColumn(label: Text('Bcast Table', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600, fontSize: 12))),
                  DataColumn(label: Text('Conv. Phone', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600, fontSize: 12))),
                  DataColumn(label: Text('Bcast Phone', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600, fontSize: 12))),
                  DataColumn(label: Text('Webhooks', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600, fontSize: 12))),
                  DataColumn(label: Text('', style: TextStyle(fontSize: 0))),
                ],
                rows: clients.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final c = entry.value;
                  final rowColor = idx.isOdd ? vc.surfaceAlt : null;
                  return DataRow(
                    color: rowColor != null ? WidgetStateProperty.all(rowColor) : null,
                    cells: [
                      DataCell(Text(c.name, style: TextStyle(color: vc.textPrimary, fontSize: 12))),
                      DataCell(_featureChips(vc, c)),
                      DataCell(Text('${c.slug}_messages', style: TextStyle(color: vc.textSecondary, fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text('${c.slug}_broadcasts', style: TextStyle(color: vc.textSecondary, fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(c.conversationsPhone ?? '-', style: TextStyle(color: vc.textSecondary, fontSize: 11))),
                      DataCell(Text(c.broadcastsPhone ?? '-', style: TextStyle(color: vc.textSecondary, fontSize: 11))),
                      DataCell(_webhookSummary(vc, c)),
                      DataCell(
                        IconButton(
                          icon: Icon(Icons.edit, size: 16, color: VividColors.cyan),
                          tooltip: 'Edit client',
                          onPressed: () => _openClientEditDialog(c),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _featureChips(VividColorScheme vc, Client c) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: c.enabledFeatures.map((f) {
        final status = _featureConfigStatus(c, f);
        final dotColor = status == _ConfigStatus.full
            ? VividColors.statusSuccess
            : status == _ConfigStatus.partial
                ? VividColors.statusWarning
                : VividColors.statusUrgent;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: dotColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                f.replaceAll('_', ' '),
                style: TextStyle(color: vc.textSecondary, fontSize: 10),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  _ConfigStatus _featureConfigStatus(Client c, String feature) {
    switch (feature) {
      case 'conversations':
        final hasPhone = c.conversationsPhone != null && c.conversationsPhone!.isNotEmpty;
        final hasWebhook = c.conversationsWebhookUrl != null && c.conversationsWebhookUrl!.isNotEmpty;
        if (hasPhone && hasWebhook) return _ConfigStatus.full;
        if (hasPhone || hasWebhook) return _ConfigStatus.partial;
        return _ConfigStatus.none;
      case 'broadcasts':
        final hasPhone = c.broadcastsPhone != null && c.broadcastsPhone!.isNotEmpty;
        final hasWebhook = c.broadcastsWebhookUrl != null && c.broadcastsWebhookUrl!.isNotEmpty;
        if (hasPhone && hasWebhook) return _ConfigStatus.full;
        if (hasPhone || hasWebhook) return _ConfigStatus.partial;
        return _ConfigStatus.none;
      case 'manager_chat':
        final hasWebhook = c.managerChatWebhookUrl != null && c.managerChatWebhookUrl!.isNotEmpty;
        return hasWebhook ? _ConfigStatus.full : _ConfigStatus.none;
      case 'analytics':
        return _ConfigStatus.full; // No config needed
      case 'predictive_intelligence':
        final hasTable = c.customerPredictionsTable != null && c.customerPredictionsTable!.isNotEmpty;
        return hasTable ? _ConfigStatus.full : _ConfigStatus.none;
      default:
        return _ConfigStatus.none;
    }
  }

  Widget _webhookSummary(VividColorScheme vc, Client c) {
    int configured = 0;
    int total = 0;
    if (c.enabledFeatures.contains('conversations')) {
      total++;
      if (c.conversationsWebhookUrl != null && c.conversationsWebhookUrl!.isNotEmpty) configured++;
    }
    if (c.enabledFeatures.contains('broadcasts')) {
      total++;
      if (c.broadcastsWebhookUrl != null && c.broadcastsWebhookUrl!.isNotEmpty) configured++;
    }
    if (c.enabledFeatures.contains('manager_chat')) {
      total++;
      if (c.managerChatWebhookUrl != null && c.managerChatWebhookUrl!.isNotEmpty) configured++;
    }
    if (total == 0) return Text('-', style: TextStyle(color: vc.textMuted, fontSize: 11));
    final color = configured == total
        ? VividColors.statusSuccess
        : configured > 0
            ? VividColors.statusWarning
            : VividColors.statusUrgent;
    return Text(
      '$configured/$total',
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    );
  }

  void _openClientEditDialog(Client client) {
    // We reuse the existing _ClientDialog from admin_panel.dart.
    // Since _ClientDialog is private to admin_panel.dart, we navigate via AdminProvider to show edit.
    // Instead, show a full dialog inline here with the same fields.
    showDialog(
      context: context,
      builder: (context) => _SettingsClientEditDialog(client: client),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SECTION C: Database Tables
  // ═══════════════════════════════════════════════════════

  Widget _buildDatabaseTablesSection(VividColorScheme vc, bool isMobile) {
    final clients = context.watch<AdminProvider>().clients;

    // Count missing across all clients
    int totalMissing = 0;
    for (final c in clients) {
      for (final (_, tableName) in _getExpectedTables(c)) {
        if (_tableStatus.containsKey(tableName) && _tableStatus[tableName] == null) {
          totalMissing++;
        }
      }
    }

    return _sectionContainer(
      vc,
      icon: Icons.storage,
      title: 'Database Tables',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (totalMissing > 0 && !_isCheckingTables)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: VividColors.statusUrgent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$totalMissing missing',
                style: const TextStyle(color: VividColors.statusUrgent, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          if (_isCheckingTables)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: VividColors.cyan))
          else
            IconButton(
              onPressed: _checkTables,
              icon: Icon(Icons.refresh, size: 18, color: vc.textMuted),
              tooltip: 'Re-check tables',
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Per-client tables ──
          if (clients.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No clients configured.', style: TextStyle(color: vc.textMuted)),
            )
          else
            ...clients.map((client) => _buildClientTablesCard(vc, client, isMobile)),

          const SizedBox(height: 20),

          // ── System tables ──
          _buildSystemTablesCard(vc, isMobile),
        ],
      ),
    );
  }

  Widget _buildClientTablesCard(VividColorScheme vc, Client client, bool isMobile) {
    final expectedTables = _getExpectedTables(client);
    if (expectedTables.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: vc.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: vc.border),
          ),
          child: Row(
            children: [
              _clientAvatar(client.name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name, style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('No table-backed features enabled', style: TextStyle(color: vc.textMuted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final missingCount = expectedTables.where((t) {
      final status = _tableStatus[t.$2];
      return _tableStatus.containsKey(t.$2) && status == null;
    }).length;
    final allChecked = expectedTables.every((t) => _tableStatus.containsKey(t.$2));
    final allOk = allChecked && missingCount == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: vc.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !allChecked ? vc.border : (allOk ? VividColors.statusSuccess.withValues(alpha: 0.3) : VividColors.statusUrgent.withValues(alpha: 0.3)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _clientAvatar(client.name),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.name, style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(client.slug, style: TextStyle(color: vc.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                if (allChecked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: allOk
                          ? VividColors.statusSuccess.withValues(alpha: 0.12)
                          : VividColors.statusUrgent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          allOk ? Icons.check_circle : Icons.warning_amber_rounded,
                          size: 14,
                          color: allOk ? VividColors.statusSuccess : VividColors.statusUrgent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          allOk ? 'All OK' : '$missingCount missing',
                          style: TextStyle(
                            color: allOk ? VividColors.statusSuccess : VividColors.statusUrgent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Table grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: expectedTables.map((entry) {
                final (label, tableName) = entry;
                return _buildTableChip(vc, label, tableName);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableChip(VividColorScheme vc, String label, String tableName) {
    final status = _tableStatus[tableName]; // null if not checked yet, int? if checked
    final checked = _tableStatus.containsKey(tableName);
    final exists = checked && status != null;
    final missing = checked && status == null;
    final rowCount = status ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: missing
            ? VividColors.statusUrgent.withValues(alpha: 0.06)
            : vc.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: !checked
              ? vc.border
              : exists
                  ? VividColors.statusSuccess.withValues(alpha: 0.4)
                  : VividColors.statusUrgent.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status icon
          if (!checked)
            SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: vc.textMuted),
            )
          else
            Icon(
              exists ? Icons.check_circle : Icons.cancel,
              size: 14,
              color: exists ? VividColors.statusSuccess : VividColors.statusUrgent,
            ),
          const SizedBox(width: 6),

          // Label + table name
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: vc.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
              Text(
                tableName,
                style: TextStyle(color: vc.textMuted, fontSize: 10, fontFamily: 'monospace'),
              ),
            ],
          ),

          // Row count badge or MISSING label
          if (checked) ...[
            const SizedBox(width: 8),
            if (exists)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: VividColors.statusSuccess.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$rowCount rows',
                  style: const TextStyle(color: VividColors.statusSuccess, fontSize: 9, fontWeight: FontWeight.w600),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: VividColors.statusUrgent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'MISSING',
                  style: TextStyle(color: VividColors.statusUrgent, fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemTablesCard(VividColorScheme vc, bool isMobile) {
    // Group system tables by category
    final categories = <String, List<String>>{};
    for (final (cat, tableName) in _systemTables) {
      categories.putIfAbsent(cat, () => []).add(tableName);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: vc.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dns, size: 18, color: VividColors.brightBlue),
              const SizedBox(width: 8),
              Text('System Tables', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),

          ...categories.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key, style: TextStyle(color: vc.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entry.value.map((tableName) {
                      return _buildTableChip(vc, tableName, tableName);
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _clientAvatar(String name) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [VividColors.brightBlue, VividColors.cyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SECTION D: System Health
  // ═══════════════════════════════════════════════════════

  Widget _buildSystemHealthSection(VividColorScheme vc, bool isMobile) {
    return _sectionContainer(
      vc,
      icon: Icons.monitor_heart,
      title: 'System Health',
      trailing: _isCheckingHealth
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: VividColors.cyan))
          : IconButton(
              onPressed: _checkSystemHealth,
              icon: Icon(Icons.refresh, size: 18, color: vc.textMuted),
              tooltip: 'Re-check health',
            ),
      child: Column(
        children: [
          _healthRow(vc, 'Supabase', _supabaseOk ? 'Connected' : 'Disconnected', _supabaseOk),
          _healthRow(
            vc,
            'Last Activity',
            _lastActivityTimestamp != null ? _formatTimestamp(_lastActivityTimestamp!) : 'N/A',
            _lastActivityTimestamp != null,
          ),
          const SizedBox(height: 8),
          if (_tableCounts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Record Counts', style: TextStyle(color: vc.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            ),
            ..._tableCounts.entries.map((e) {
              return _countRow(vc, e.key, e.value);
            }),
          ],
        ],
      ),
    );
  }

  Widget _healthRow(VividColorScheme vc, String label, String value, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: ok ? VividColors.statusSuccess : VividColors.statusUrgent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (ok ? VividColors.statusSuccess : VividColors.statusUrgent).withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: vc.textMuted, fontSize: 13))),
          Expanded(
            child: Text(value, style: TextStyle(color: vc.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _countRow(VividColorScheme vc, String table, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 18),
          SizedBox(width: 110, child: Text(table, style: TextStyle(color: vc.textMuted, fontSize: 12, fontFamily: 'monospace'))),
          Text(
            count >= 0 ? count.toString() : 'error',
            style: TextStyle(
              color: count >= 0 ? vc.textPrimary : VividColors.statusUrgent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════════════════════
  // SHARED SECTION CONTAINER
  // ═══════════════════════════════════════════════════════

  Widget _sectionContainer(
    VividColorScheme vc, {
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: VividColors.cyan, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: vc.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Config status enum
// ══════════════════════════════════════════════════════════

enum _ConfigStatus { full, partial, none }

// ══════════════════════════════════════════════════════════
// Small loading indicator
// ══════════════════════════════════════════════════════════

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator(color: VividColors.cyan)),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Client Edit Dialog (standalone, since _ClientDialog is
// private to admin_panel.dart)
// ══════════════════════════════════════════════════════════

class _SettingsClientEditDialog extends StatefulWidget {
  final Client client;
  const _SettingsClientEditDialog({required this.client});

  @override
  State<_SettingsClientEditDialog> createState() => _SettingsClientEditDialogState();
}

class _SettingsClientEditDialogState extends State<_SettingsClientEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _slugCtrl;
  late final TextEditingController _convPhoneCtrl;
  late final TextEditingController _convWebhookCtrl;
  late final TextEditingController _bcastPhoneCtrl;
  late final TextEditingController _bcastWebhookCtrl;
  late final TextEditingController _remPhoneCtrl;
  late final TextEditingController _remWebhookCtrl;
  late final TextEditingController _mgrWebhookCtrl;
  late List<String> _features;
  late bool _hasAi;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _nameCtrl = TextEditingController(text: c.name);
    _slugCtrl = TextEditingController(text: c.slug);
    _convPhoneCtrl = TextEditingController(text: c.conversationsPhone ?? '');
    _convWebhookCtrl = TextEditingController(text: c.conversationsWebhookUrl ?? '');
    _bcastPhoneCtrl = TextEditingController(text: c.broadcastsPhone ?? '');
    _bcastWebhookCtrl = TextEditingController(text: c.broadcastsWebhookUrl ?? '');
    _remPhoneCtrl = TextEditingController(text: c.remindersPhone ?? '');
    _remWebhookCtrl = TextEditingController(text: c.remindersWebhookUrl ?? '');
    _mgrWebhookCtrl = TextEditingController(text: c.managerChatWebhookUrl ?? '');
    _features = List.from(c.enabledFeatures);
    _hasAi = c.hasAiConversations;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _convPhoneCtrl.dispose();
    _convWebhookCtrl.dispose();
    _bcastPhoneCtrl.dispose();
    _bcastWebhookCtrl.dispose();
    _remPhoneCtrl.dispose();
    _remWebhookCtrl.dispose();
    _mgrWebhookCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return AlertDialog(
      backgroundColor: vc.surface,
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      title: Text(
        'Edit ${widget.client.name}',
        style: TextStyle(color: vc.textPrimary),
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: isMobile ? screenWidth : 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(vc, _nameCtrl, 'Client Name', 'Name'),
                const SizedBox(height: 10),
                _field(vc, _slugCtrl, 'Slug', 'Slug'),
                const SizedBox(height: 10),
                Text('Features', style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['conversations', 'broadcasts', 'analytics', 'manager_chat'].map((f) {
                    final sel = _features.contains(f);
                    return FilterChip(
                      label: Text(f.replaceAll('_', ' '), style: TextStyle(color: sel ? VividColors.cyan : vc.textMuted, fontSize: 12)),
                      selected: sel,
                      onSelected: (v) => setState(() => v ? _features.add(f) : _features.remove(f)),
                      selectedColor: VividColors.brightBlue.withOpacity(0.3),
                      checkmarkColor: VividColors.cyan,
                      backgroundColor: vc.surfaceAlt,
                    );
                  }).toList(),
                ),
                if (_features.contains('conversations')) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('AI Conversations', style: TextStyle(color: vc.textPrimary, fontSize: 13)),
                    value: _hasAi,
                    onChanged: (v) => setState(() => _hasAi = v),
                    activeTrackColor: VividColors.cyan.withOpacity(0.3),
                  ),
                  _field(vc, _convPhoneCtrl, 'Conv. Phone', 'Phone', required: false),
                  const SizedBox(height: 8),
                  _field(vc, _convWebhookCtrl, 'Conv. Webhook', 'Webhook URL', required: false),
                ],
                if (_features.contains('broadcasts')) ...[
                  const SizedBox(height: 12),
                  _field(vc, _bcastPhoneCtrl, 'Broadcast Phone', 'Phone', required: false),
                  const SizedBox(height: 8),
                  _field(vc, _bcastWebhookCtrl, 'Broadcast Webhook', 'Webhook URL', required: false),
                ],
                if (_features.contains('manager_chat')) ...[
                  const SizedBox(height: 12),
                  _field(vc, _mgrWebhookCtrl, 'Manager Chat Webhook', 'Webhook URL', required: false),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: vc.textMuted))),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: VividColors.brightBlue),
          child: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _field(VividColorScheme vc, TextEditingController ctrl, String label, String hint, {bool required = true}) {
    return TextFormField(
      controller: ctrl,
      style: TextStyle(color: vc.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: vc.textMuted, fontSize: 12),
        hintStyle: TextStyle(color: vc.textMuted.withOpacity(0.5), fontSize: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: vc.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: VividColors.cyan)),
        filled: true,
        fillColor: vc.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      validator: required ? (v) => v?.isEmpty == true ? 'Required' : null : null,
    );
  }

  String? _trimOrNull(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final provider = context.read<AdminProvider>();
    final ok = await provider.updateClient(
      clientId: widget.client.id,
      name: _nameCtrl.text.trim(),
      slug: _slugCtrl.text.trim(),
      enabledFeatures: _features,
      hasAiConversations: _hasAi,
      conversationsPhone: _trimOrNull(_convPhoneCtrl),
      conversationsWebhookUrl: _trimOrNull(_convWebhookCtrl),
      broadcastsPhone: _trimOrNull(_bcastPhoneCtrl),
      broadcastsWebhookUrl: _trimOrNull(_bcastWebhookCtrl),
      remindersPhone: _trimOrNull(_remPhoneCtrl),
      remindersWebhookUrl: _trimOrNull(_remWebhookCtrl),
      managerChatWebhookUrl: _trimOrNull(_mgrWebhookCtrl),
    );
    setState(() => _isSaving = false);
    if (ok && mounted) Navigator.pop(context);
  }
}
