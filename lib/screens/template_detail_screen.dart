import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/templates_provider.dart';
import '../services/supabase_service.dart';
import '../theme/vivid_theme.dart';

class TemplateDetailScreen extends StatefulWidget {
  final WhatsAppTemplate template;

  const TemplateDetailScreen({super.key, required this.template});

  @override
  State<TemplateDetailScreen> createState() => _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends State<TemplateDetailScreen> {
  static const _labelOptions = [
    'customer_name',
    'service',
    'price',
    'date',
    'provider',
    'branch',
  ];
  static const _sourceOptions = ['customer_data', 'ai_extracted', 'static'];

  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  // DB row fields
  String? _dbRowId; // Supabase primary key (uuid)
  int _varCount = 0;
  List<String> _labels = [];
  List<String> _sources = [];
  String? _offerImageUrl;
  String? _bodyText;

  // Image edit state
  Uint8List? _newImageBytes;
  String? _newImageMimeType;

  @override
  void initState() {
    super.initState();
    _loadDbRow();
  }

  Future<void> _loadDbRow() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final row = await SupabaseService.adminClient
          .from('whatsapp_templates')
          .select(
              'id, body_variable_count, body_variable_labels, body_variable_sources, offer_image_url, body_text, template_name, header_type')
          .eq('meta_template_id', widget.template.id)
          .maybeSingle();

      if (row == null) {
        setState(() {
          _loadError = 'No Supabase record found for this template.\nPress "Sync to AI" on the templates screen first.';
          _isLoading = false;
        });
        return;
      }

      final count = (row['body_variable_count'] as int?) ?? 0;
      final rawLabels = row['body_variable_labels'];
      final rawSources = row['body_variable_sources'];

      final labels = rawLabels is List
          ? List<String>.from(rawLabels)
          : List.filled(count, 'customer_name');
      final sources = rawSources is List
          ? List<String>.from(rawSources)
          : List.filled(count, 'customer_data');

      // Pad or trim to match varCount
      while (labels.length < count) {
        labels.add(_labelOptions[labels.length < _labelOptions.length ? labels.length : 0]);
      }
      while (sources.length < count) {
        sources.add('ai_extracted');
      }

      setState(() {
        _dbRowId = row['id'] as String?;
        _varCount = count;
        _labels = labels.take(count).toList();
        _sources = sources.take(count).toList();
        _offerImageUrl = row['offer_image_url'] as String?;
        _bodyText = row['body_text'] as String? ?? widget.template.body;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickNewImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    if (file.bytes!.lengthInBytes > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Image exceeds 5 MB limit'),
        backgroundColor: VividColors.statusUrgent,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final ext = (file.extension ?? 'jpg').toLowerCase();
    setState(() {
      _newImageBytes = file.bytes;
      _newImageMimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
    });
  }

  Future<void> _save() async {
    if (_dbRowId == null) return;
    setState(() => _isSaving = true);

    try {
      final provider = context.read<TemplatesProvider>();
      String? resolvedImageUrl = _offerImageUrl;

      // Upload new image if one was picked
      if (_newImageBytes != null && _newImageMimeType != null) {
        resolvedImageUrl = await provider.uploadOfferImageToStorage(
          _newImageBytes!,
          widget.template.name,
          _newImageMimeType!,
        );
        setState(() => _offerImageUrl = resolvedImageUrl);
      }

      final clientId = ClientConfig.currentClient?.id ?? '';
      await SupabaseService.adminClient
          .from('whatsapp_templates')
          .update({
            'body_variable_labels': _labels,
            'body_variable_descriptions': _labels,
            'body_variable_sources': _sources,
            'offer_image_url': resolvedImageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _dbRowId!)
          .eq('client_id', clientId);

      // Refresh validation indicators on the list screen
      await provider.fetchTemplateDbStatuses(clientId);

      if (!mounted) return;
      setState(() {
        _newImageBytes = null;
        _newImageMimeType = null;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Saved ✓'),
        backgroundColor: VividColors.statusSuccess,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed: $e'),
        backgroundColor: VividColors.statusUrgent,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Scaffold(
      backgroundColor: vc.background,
      body: Column(
        children: [
          _buildTopBar(context),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: VividColors.cyan))
                : _loadError != null
                    ? _buildError(context)
                    : _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
      decoration: BoxDecoration(
        color: vc.surface,
        border: Border(bottom: BorderSide(color: vc.border)),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Back'),
            style: TextButton.styleFrom(
              foregroundColor: VividColors.cyan,
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.template.name,
                  style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${widget.template.language} · ${_capitalize(widget.template.category)}',
                  style: TextStyle(color: vc.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          _statusBadge(context, widget.template.status),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: (_isSaving || _isLoading || _loadError != null)
                ? null
                : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 16),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              backgroundColor: VividColors.cyan,
              foregroundColor: vc.background,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final vc = context.vividColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              color: VividColors.statusUrgent, size: 40),
          const SizedBox(height: 16),
          Text(
            _loadError!,
            style: TextStyle(color: vc.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _loadDbRow,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 860;
      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildEditorColumn(context)),
            Container(width: 1, color: context.vividColors.border),
            Expanded(flex: 2, child: _buildPreviewColumn(context)),
          ],
        );
      }
      return _buildEditorColumn(context);
    });
  }

  // ─── Editor column ───────────────────────────────────────────────────────────

  Widget _buildEditorColumn(BuildContext context) {
    final vc = context.vividColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Body text (read-only with highlighted vars)
          _buildSection(
            context,
            title: 'Message Body',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: vc.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: vc.border),
              ),
              child: _buildBodyRichText(context, _bodyText ?? widget.template.body),
            ),
          ),

          if (_varCount > 0) ...[
            const SizedBox(height: 24),
            _buildSection(
              context,
              title: 'Variable Mapping',
              subtitle: 'Labels must match n8n valueMap keys exactly',
              child: Column(
                children: List.generate(_varCount, (i) {
                  final n = i + 1;
                  return Padding(
                    padding: EdgeInsets.only(bottom: i < _varCount - 1 ? 16 : 0),
                    child: _buildVarRow(context, n, i),
                  );
                }),
              ),
            ),
          ],

          if (widget.template.headerType.toUpperCase() == 'IMAGE') ...[
            const SizedBox(height: 24),
            _buildSection(
              context,
              title: 'Offer Image',
              subtitle: 'Stored permanently in Supabase Storage',
              child: _buildImageSection(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVarRow(BuildContext context, int n, int i) {
    final vc = context.vividColors;
    final label = i < _labels.length ? _labels[i] : _labelOptions[0];
    final source = i < _sources.length ? _sources[i] : 'ai_extracted';

    // Find the context excerpt around {{n}}
    final bodySnippet = _getVarContext(n);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: vc.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Variable tag + context snippet
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: VividColors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: VividColors.cyan.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '{{$n}}',
                  style: const TextStyle(
                    color: VividColors.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (bodySnippet.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '"$bodySnippet"',
                    style: TextStyle(
                        color: vc.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Label dropdown
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Label',
                        style:
                            TextStyle(color: vc.textMuted, fontSize: 11)),
                    const SizedBox(height: 4),
                    _buildDropdown(
                      context,
                      value: _labelOptions.contains(label) ? label : _labelOptions[0],
                      items: _labelOptions,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          while (_labels.length <= i) {
                            _labels.add(_labelOptions[0]);
                          }
                          _labels[i] = v;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Source dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Source',
                        style:
                            TextStyle(color: vc.textMuted, fontSize: 11)),
                    const SizedBox(height: 4),
                    _buildDropdown(
                      context,
                      value: _sourceOptions.contains(source) ? source : _sourceOptions[0],
                      items: _sourceOptions,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          while (_sources.length <= i) {
                            _sources.add('ai_extracted');
                          }
                          _sources[i] = v;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(BuildContext context) {
    final vc = context.vividColors;
    final hasNewImage = _newImageBytes != null;
    final hasExistingImage = _offerImageUrl != null &&
        _offerImageUrl!.contains('supabase.co/storage');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: vc.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: hasNewImage
                  ? Image.memory(_newImageBytes!, fit: BoxFit.contain)
                  : hasExistingImage
                      ? Image.network(
                          _offerImageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(context),
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : Container(
                                      color: vc.background,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: VividColors.cyan),
                                      ),
                                    ),
                        )
                      : _imagePlaceholder(context),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (hasExistingImage && !hasNewImage)
                Expanded(
                  child: Text(
                    'Supabase Storage URL set',
                    style: TextStyle(
                        color: VividColors.statusSuccess, fontSize: 11),
                  ),
                )
              else if (hasNewImage)
                Expanded(
                  child: Text(
                    'New image selected — will upload on Save',
                    style: TextStyle(
                        color: VividColors.statusWarning, fontSize: 11),
                  ),
                )
              else
                Expanded(
                  child: Text(
                    'No image set',
                    style: TextStyle(color: vc.textMuted, fontSize: 11),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _pickNewImage,
                icon: const Icon(Icons.upload_rounded, size: 14),
                label: const Text('Change Image'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: vc.textSecondary,
                  side: BorderSide(
                      color: VividColors.tealBlue.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      color: vc.background,
      child: Icon(Icons.image_outlined, size: 40, color: vc.textMuted),
    );
  }

  // ─── Preview column ──────────────────────────────────────────────────────────

  Widget _buildPreviewColumn(BuildContext context) {
    final vc = context.vividColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preview',
              style: TextStyle(
                  color: vc.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          // WhatsApp mock bubble
          Container(
            constraints: const BoxConstraints(maxWidth: 340),
            decoration: const BoxDecoration(
              color: Color(0xFFEAE0D5),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF25D366),
                        borderRadius:
                            BorderRadius.only(topRight: Radius.circular(12)),
                      ),
                      child: Text(
                        widget.template.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Header image preview (use new local bytes if available, else Storage URL)
                    if (widget.template.headerType.toUpperCase() == 'IMAGE') ...[
                      _newImageBytes != null
                          ? Image.memory(_newImageBytes!,
                              width: double.infinity, fit: BoxFit.contain)
                          : (_offerImageUrl != null &&
                                  _offerImageUrl!.contains('supabase.co/storage'))
                              ? Image.network(_offerImageUrl!,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 100,
                                    color: const Color(0xFFDDE3EA),
                                    child: const Icon(Icons.broken_image_outlined,
                                        size: 32,
                                        color: Color(0xFF90A4AE)),
                                  ))
                              : Container(
                                  height: 100,
                                  color: const Color(0xFFDDE3EA),
                                  child: const Icon(Icons.image_outlined,
                                      size: 32,
                                      color: Color(0xFF90A4AE)),
                                ),
                    ],
                    if (widget.template.headerType.toUpperCase() == 'TEXT' &&
                        widget.template.headerText != null)
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: Text(
                          widget.template.headerText!,
                          style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                      child: _buildBodyRichText(
                          context, _bodyText ?? widget.template.body,
                          darkText: true),
                    ),
                    if (widget.template.footer != null &&
                        widget.template.footer!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                        child: Text(
                          widget.template.footer!,
                          style: const TextStyle(
                              color: Color(0xFF9E9E9E), fontSize: 11),
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(0, 0, 10, 6),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('9:41',
                            style: TextStyle(
                                color: Color(0xFF9E9E9E), fontSize: 10)),
                      ),
                    ),
                    if (widget.template.buttons.isNotEmpty) ...[
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      ...widget.template.buttons.map((b) {
                        final icon = switch (b.type.toUpperCase()) {
                          'URL' => Icons.open_in_new_rounded,
                          'PHONE_NUMBER' => Icons.phone_rounded,
                          _ => Icons.reply_rounded,
                        };
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon,
                                  size: 14,
                                  color: const Color(0xFF0088CC)),
                              const SizedBox(width: 6),
                              Text(b.text,
                                  style: const TextStyle(
                                      color: Color(0xFF0088CC),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Variable map summary
          if (_varCount > 0) ...[
            Text('Variable Map',
                style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...List.generate(_varCount, (i) {
              final label = i < _labels.length ? _labels[i] : '—';
              final source = i < _sources.length ? _sources[i] : '—';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: VividColors.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('{{${i + 1}}}',
                          style: const TextStyle(
                              color: VividColors.cyan,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Text(label,
                        style: TextStyle(
                            color: vc.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 6),
                    Text('($source)',
                        style:
                            TextStyle(color: vc.textMuted, fontSize: 11)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ─── Shared helpers ──────────────────────────────────────────────────────────

  Widget _buildSection(BuildContext context,
      {required String title, String? subtitle, required Widget child}) {
    final vc = context.vividColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: vc.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(color: vc.textMuted, fontSize: 11)),
        ],
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    final vc = context.vividColors;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: vc.inputFill,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: vc.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: vc.surface,
          style: TextStyle(color: vc.textPrimary, fontSize: 12),
          icon: Icon(Icons.expand_more_rounded, size: 16, color: vc.textMuted),
          items: items
              .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e,
                      style: TextStyle(
                          color: vc.textPrimary, fontSize: 12))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildBodyRichText(BuildContext context, String text,
      {bool darkText = false}) {
    final vc = context.vividColors;
    final baseColor = darkText ? const Color(0xFF111111) : vc.textSecondary;
    final spans = <TextSpan>[];
    final re = RegExp(r'\{\{(\d+)\}\}');
    int last = 0;
    for (final match in re.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(
            text: text.substring(last, match.start),
            style: TextStyle(color: baseColor, fontSize: 13)));
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
          style: TextStyle(color: baseColor, fontSize: 13)));
    }
    return RichText(
        text: TextSpan(children: spans, style: const TextStyle(height: 1.5)));
  }

  /// Returns a short excerpt of text around {{n}}, ~30 chars before the placeholder.
  String _getVarContext(int n) {
    final body = _bodyText ?? widget.template.body;
    final placeholder = '{{$n}}';
    final idx = body.indexOf(placeholder);
    if (idx == -1) return '';
    final start = (idx - 35).clamp(0, body.length);
    final snippet = body.substring(start, idx).trim();
    return snippet.length > 35
        ? '…${snippet.substring(snippet.length - 35)}'
        : snippet.isNotEmpty
            ? '…$snippet'
            : '';
  }

  Widget _statusBadge(BuildContext context, String status) {
    final (color, label) = switch (status.toUpperCase()) {
      'APPROVED' => (VividColors.statusSuccess, 'Approved'),
      'PENDING' || 'PENDING_DELETION' => (VividColors.statusWarning, 'Pending'),
      'REJECTED' => (VividColors.statusUrgent, 'Rejected'),
      _ => (context.vividColors.textMuted, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}
