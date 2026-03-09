import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/templates_provider.dart';
import '../models/models.dart';
import '../theme/vivid_theme.dart';
import 'new_template_screen.dart';

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
      if (mounted) context.read<TemplatesProvider>().fetchTemplates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<TemplatesProvider>();

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
                  'Manage your approved WhatsApp message templates',
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
          const SizedBox(width: 10),
          // New Template button
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
          return _TemplateCard(
            template: provider.templates[index],
            onDelete: (name, id) => _confirmDelete(context, provider, name, id),
            onPreview: (t) => _showPreview(context, t),
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

  void _showPreview(BuildContext context, WhatsAppTemplate template) {
    showDialog(
      context: context,
      builder: (_) => _TemplatePreviewDialog(template: template),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Delete failed: $err'),
        backgroundColor: VividColors.statusUrgent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Template deleted successfully'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEMPLATE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final WhatsAppTemplate template;
  final void Function(String name, String id) onDelete;
  final void Function(WhatsAppTemplate t) onPreview;

  const _TemplateCard({
    required this.template,
    required this.onDelete,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final hasImage = template.headerType == 'IMAGE' &&
        template.headerMediaUrl != null &&
        template.headerMediaUrl!.isNotEmpty;

    return Material(
      color: vc.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias, // clips image to card border-radius
      child: InkWell(
        onTap: () => onPreview(template),
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
                              template.name,
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

              // Divider + action row (Delete only — card tap opens preview)
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
                    // Delete — stop propagation so it doesn't trigger card tap
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

// ─────────────────────────────────────────────────────────────────────────────
// PREVIEW DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _TemplatePreviewDialog extends StatelessWidget {
  final WhatsAppTemplate template;

  const _TemplatePreviewDialog({required this.template});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Dialog(
      backgroundColor: vc.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: vc.border),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_android_rounded,
                      color: VividColors.cyan, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Preview',
                        style: TextStyle(
                            color: vc.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: vc.textMuted, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // WhatsApp mock area
            Flexible(
              child: Container(
                color: const Color(0xFFEAE0D5),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildBubble(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(0),
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header bar (green)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF25D366),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              template.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Header text/image
          if (template.headerType == 'TEXT' &&
              template.headerText != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Text(
                template.headerText!,
                style: const TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (template.headerType == 'IMAGE') ...[
            if (template.headerMediaUrl != null &&
                template.headerMediaUrl!.isNotEmpty)
              Image.network(
                template.headerMediaUrl!,
                width: double.infinity,
                fit: BoxFit.contain, // show full image without cropping
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: const Color(0xFFDDE3EA),
                  child: const Icon(Icons.broken_image_outlined,
                      size: 40, color: Color(0xFF90A4AE)),
                ),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        height: 120,
                        color: const Color(0xFFDDE3EA),
                        child: const Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF90A4AE))),
                      ),
              )
            else
              Container(
                height: 120,
                width: double.infinity,
                color: const Color(0xFFDDE3EA),
                child: const Icon(Icons.image_outlined,
                    size: 40, color: Color(0xFF90A4AE)),
              ),
          ],
          if (template.headerType == 'VIDEO') ...[
            Container(
              height: 120,
              width: double.infinity,
              color: const Color(0xFFDDE3EA),
              child: const Icon(Icons.play_circle_outline_rounded,
                  size: 40, color: Color(0xFF90A4AE)),
            ),
          ],

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: _buildBodyText(template.body),
          ),

          // Footer
          if (template.footer != null && template.footer!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                template.footer!,
                style: const TextStyle(
                    color: Color(0xFF9E9E9E), fontSize: 11),
              ),
            ),

          // Timestamp stub
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 10, 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('9:41',
                  style: TextStyle(
                      color: Color(0xFF9E9E9E), fontSize: 10)),
            ),
          ),

          // Buttons
          if (template.buttons.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            ...template.buttons.map((b) => _buildButton(b)),
          ],
        ],
      ),
    );
  }

  Widget _buildBodyText(String text) {
    // Highlight {{n}} variables in cyan
    final spans = <TextSpan>[];
    final re = RegExp(r'\{\{(\d+)\}\}');
    int last = 0;
    for (final match in re.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, match.start),
          style: const TextStyle(color: Color(0xFF111111), fontSize: 13),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          color: VividColors.cyan,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(
        text: text.substring(last),
        style: const TextStyle(color: Color(0xFF111111), fontSize: 13),
      ));
    }
    return RichText(
        text: TextSpan(
            children: spans,
            style: const TextStyle(height: 1.5)));
  }

  Widget _buildButton(TemplateButton button) {
    final icon = switch (button.type.toUpperCase()) {
      'URL' => Icons.open_in_new_rounded,
      'PHONE_NUMBER' => Icons.phone_rounded,
      _ => Icons.reply_rounded,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0088CC)),
          const SizedBox(width: 6),
          Text(
            button.text,
            style: const TextStyle(
                color: Color(0xFF0088CC),
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
