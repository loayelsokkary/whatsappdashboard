import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/templates_provider.dart';
import '../theme/vivid_theme.dart';
import 'new_template_screen.dart';
import 'template_detail_screen.dart';
import '../utils/toast_service.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final provider = context.read<TemplatesProvider>();
      final clientId = ClientConfig.currentClient?.id ?? '';
      provider.fetchTemplates();
      provider.fetchTemplateDbStatuses(clientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<TemplatesProvider>();

    // Check if templates table is configured
    final table = ClientConfig.templatesTable;
    if (table == null || table.isEmpty) {
      return Container(
        color: vc.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, size: 64, color: vc.textMuted),
              const SizedBox(height: 16),
              Text('Templates Not Configured',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: vc.textPrimary)),
              const SizedBox(height: 8),
              Text('Please contact your administrator to set up the templates table.',
                  style: TextStyle(color: vc.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Container(
      color: vc.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, provider),
          Expanded(child: _buildBody(context, provider)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────

  Widget _buildHeader(BuildContext context, TemplatesProvider provider) {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      decoration: BoxDecoration(
        color: vc.surface,
        border: Border(
          bottom: BorderSide(color: vc.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message Templates',
                  style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your WhatsApp message templates',
                  style: TextStyle(
                    color: vc.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Refresh button
          OutlinedButton.icon(
            onPressed:
                provider.isLoading ? null : () => provider.fetchTemplates(),
            icon: provider.isLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: vc.textMuted),
                  )
                : const Icon(Icons.sync_rounded, size: 16),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: vc.textSecondary,
              side: BorderSide(
                  color: VividColors.tealBlue.withValues(alpha: 0.4)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          // Sync to AI + New Template — Vivid Admins, preview mode, and client Admins/Managers
          if (ClientConfig.isVividAdmin ||
              ClientConfig.isPreviewMode ||
              (ClientConfig.currentClient != null &&
                  ClientConfig.currentUserRole != UserRole.agent &&
                  ClientConfig.currentUserRole != UserRole.viewer)) ...[
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: provider.isSyncing
                  ? null
                  : () async {
                      final error =
                          await provider.syncTemplatesToSupabase();
                      if (!context.mounted) return;
                      VividToast.show(context,
                        message: error ?? 'Templates synced to AI',
                        type: error == null ? ToastType.success : ToastType.error,
                      );
                    },
              icon: provider.isSyncing
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: vc.textMuted),
                    )
                  : const Icon(Icons.cloud_upload_rounded, size: 16),
              label: const Text('Sync to AI'),
              style: OutlinedButton.styleFrom(
                foregroundColor: vc.textSecondary,
                side: BorderSide(
                    color: VividColors.tealBlue.withValues(alpha: 0.4)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: () => _openNewTemplate(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New Template'),
              style: FilledButton.styleFrom(
                backgroundColor: VividColors.cyan,
                foregroundColor: vc.background,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Body
  // ─────────────────────────────────────────

  Widget _buildBody(BuildContext context, TemplatesProvider provider) {
    final vc = context.vividColors;
    if (provider.isLoading && provider.templates.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
            strokeWidth: 2, color: VividColors.cyan),
      );
    }

    if (provider.error != null && provider.templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: VividColors.statusUrgent, size: 40),
            const SizedBox(height: 16),
            Text(
              'Failed to load templates',
              style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              provider.error!,
              style: TextStyle(
                  color: vc.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => provider.fetchTemplates(),
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                  backgroundColor: VividColors.brightBlue),
            ),
          ],
        ),
      );
    }

    if (provider.templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined,
                size: 56,
                color: vc.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No templates yet',
                style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Create your first WhatsApp message template',
                style:
                    TextStyle(color: vc.textMuted, fontSize: 13)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openNewTemplate(context),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New Template'),
              style: FilledButton.styleFrom(
                  backgroundColor: VividColors.cyan,
                  foregroundColor: vc.background),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final crossCount = w > 1400
          ? 4
          : w > 1000
              ? 3
              : w > 640
                  ? 2
                  : 1;

      return GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.0,
        ),
        itemCount: provider.templates.length,
        itemBuilder: (context, index) {
          final t = provider.templates[index];
          return _TemplateCard(
            template: t,
            dbStatus: provider.templateDbStatuses[t.id],
            onDelete: (name, id) => _confirmDelete(context, provider, name, id),
            onTap: () => _openDetail(context, t),
          );
        },
      );
    });
  }

  // ─────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────

  void _openNewTemplate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<TemplatesProvider>(),
          child: const NewTemplateScreen(),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, WhatsAppTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<TemplatesProvider>(),
          child: TemplateDetailScreen(template: template),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, TemplatesProvider provider, String name, String id) async {
    final vc = context.vividColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: vc.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Template',
            style: TextStyle(
                color: vc.textPrimary,
                fontWeight: FontWeight.w600)),
        content: Text(
          'Delete "$name"? This action cannot be undone and will remove it from your Meta account.',
          style:
              TextStyle(color: vc.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: vc.textMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: VividColors.statusUrgent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final err = await provider.deleteTemplate(name, id);
    if (!context.mounted) return;
    if (err != null) {
      VividToast.show(context,
        message: 'Delete failed: $err',
        type: ToastType.error,
      );
    } else {
      VividToast.show(context,
        message: 'Template deleted successfully',
        type: ToastType.success,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEMPLATE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final WhatsAppTemplate template;
  final Map<String, dynamic>? dbStatus;
  final void Function(String name, String id) onDelete;
  final VoidCallback onTap;
  const _TemplateCard({
    required this.template,
    required this.onDelete,
    required this.onTap,
    this.dbStatus,
  });

  // Compute validation state from DB status
  // Returns 0=none, 1=green, 2=yellow, 3=red
  int _validationLevel() {
    if (dbStatus == null) return 0;
    final varCount = (dbStatus!['body_variable_count'] as int?) ?? 0;
    final rawLabels = dbStatus!['body_variable_labels'];
    final headerType = (dbStatus!['header_type'] as String? ?? '').toLowerCase();
    final imageUrl = dbStatus!['offer_image_url'] as String?;

    if (varCount == 0) return 1; // no variables → trivially valid

    final labels = rawLabels is List ? List<String>.from(rawLabels) : <String>[];
    if (labels.isEmpty || labels.every((l) => l.trim().isEmpty)) return 3; // red

    const standard = {'customer_name', 'service', 'price', 'date', 'provider', 'branch'};
    final hasGeneric = labels.any((l) => !standard.contains(l) && l.trim().isNotEmpty);
    final imageMissing = headerType == 'image' &&
        (imageUrl == null || !imageUrl.contains('supabase.co/storage'));

    if (hasGeneric || imageMissing) return 2; // yellow
    return 1; // green
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final hasImage = template.headerType == 'IMAGE' &&
        template.headerMediaUrl != null &&
        template.headerMediaUrl!.isNotEmpty;
    final level = _validationLevel();
    final dotColor = level == 1
        ? VividColors.statusSuccess
        : level == 2
            ? VividColors.statusWarning
            : level == 3
                ? VividColors.statusUrgent
                : null;

    return Material(
      color: vc.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: vc.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header image — padded, rounded corners, full visibility
              if (hasImage)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: Image.network(
                        template.headerMediaUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          color: vc.surfaceAlt,
                          child: const Icon(Icons.broken_image_outlined,
                              color: Color(0xFF4A5568), size: 32),
                        ),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Container(
                                color: vc.surfaceAlt,
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: vc.textMuted),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              if (hasImage) const SizedBox(height: 12),

              // Card body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + status row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              template.label,
                              style: TextStyle(
                                color: vc.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _statusBadge(context, template.status),
                          if (dotColor != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Language · Category + Header type
                      Row(
                        children: [
                          Text(
                            '${template.language} · ${_capitalize(template.category)}',
                            style: TextStyle(
                                color: vc.textSecondary,
                                fontSize: 11),
                          ),
                          const Spacer(),
                          if (!hasImage) _headerBadge(context, template.headerType),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Body preview
                      Expanded(
                        child: Text(
                          template.body,
                          style: TextStyle(
                            color: vc.textSecondary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Divider + action row — admin only (delete hits Meta API)
              if (ClientConfig.isVividAdmin) ...[
                Container(
                  height: 1,
                  color: vc.border,
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => onDelete(template.name, template.id),
                        icon: const Icon(Icons.delete_outline_rounded, size: 14),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: VividColors.statusUrgent,
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    );
  }

  Widget _statusBadge(BuildContext context, String status) {
    final vc = context.vividColors;
    final (color, label) = switch (status.toUpperCase()) {
      'APPROVED' => (VividColors.statusSuccess, 'Approved'),
      'PENDING' || 'PENDING_DELETION' => (VividColors.statusWarning, 'Pending'),
      'REJECTED' => (VividColors.statusUrgent, 'Rejected'),
      _ => (vc.textMuted, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _headerBadge(BuildContext context, String? headerType) {
    final vc = context.vividColors;
    if (headerType == null || headerType.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFDC4444).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: const Color(0xFFDC4444).withValues(alpha: 0.25)),
        ),
        child: const Text('NO HEADER',
            style: TextStyle(
                color: Color(0xFFDC4444),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
      );
    }
    final color = switch (headerType.toUpperCase()) {
      'IMAGE' || 'VIDEO' => VividColors.brightBlue,
      'DOCUMENT' => const Color(0xFFEF4444),
      _ => vc.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(headerType.toUpperCase(),
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}
