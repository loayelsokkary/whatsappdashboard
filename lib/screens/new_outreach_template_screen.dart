import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/outreach_provider.dart';
import '../theme/vivid_theme.dart';
import '../utils/toast_service.dart';

class NewOutreachTemplateScreen extends StatefulWidget {
  const NewOutreachTemplateScreen({super.key});

  @override
  State<NewOutreachTemplateScreen> createState() =>
      _NewOutreachTemplateScreenState();
}

class _NewOutreachTemplateScreenState extends State<NewOutreachTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _headerTextController = TextEditingController();
  final _bodyController = TextEditingController();
  final _footerController = TextEditingController();

  String _language = 'en_US';
  String _category = 'MARKETING';
  String _headerType = 'NONE';

  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageMimeType;
  int? _imageSize;

  final Map<int, TextEditingController> _varControllers = {};
  final List<_ButtonEntry> _buttons = [];

  static const _languages = [
    ('en_US', 'English (US)'),
    ('en_GB', 'English (UK)'),
    ('ar', 'Arabic'),
    ('fr', 'French'),
    ('es', 'Spanish'),
    ('de', 'German'),
  ];

  static const _categories = [
    ('MARKETING', 'Marketing'),
    ('UTILITY', 'Utility'),
    ('AUTHENTICATION', 'Authentication'),
  ];

  String get _previewName =>
      _nameController.text.isEmpty ? 'template_name' : _nameController.text;
  String get _previewHeaderText => _headerTextController.text;
  String get _previewBody => _bodyController.text;
  String get _previewFooter => _footerController.text;

  @override
  void dispose() {
    _nameController.dispose();
    _headerTextController.dispose();
    _bodyController.dispose();
    _footerController.dispose();
    for (final c in _varControllers.values) {
      c.dispose();
    }
    for (final b in _buttons) {
      b.dispose();
    }
    super.dispose();
  }

  void _syncVarControllers(String bodyText) {
    final nums = RegExp(r'\{\{(\d+)\}\}')
        .allMatches(bodyText)
        .map((m) => int.parse(m.group(1)!))
        .toSet();
    _varControllers.removeWhere((k, v) {
      if (!nums.contains(k)) {
        v.dispose();
        return true;
      }
      return false;
    });
    for (final n in nums) {
      _varControllers.putIfAbsent(n, () => TextEditingController());
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<OutreachProvider>();
    final templateName =
        _nameController.text.trim().toLowerCase().replaceAll(' ', '_');

    // Upload image to Supabase Storage first (permanent URL)
    String? offerImageUrl;
    if (_headerType == 'IMAGE' && _imageBytes != null && _imageMimeType != null) {
      offerImageUrl = await provider.uploadOfferImageToStorage(
        _imageBytes!,
        templateName,
        _imageMimeType!,
      );
      if (offerImageUrl == null) {
        if (!mounted) return;
        _showError('Image upload to storage failed. Please try again.');
        return;
      }
    }

    final components = <Map<String, dynamic>>[];

    // Header
    if (_headerType == 'TEXT' && _headerTextController.text.isNotEmpty) {
      components.add({
        'type': 'HEADER',
        'format': 'TEXT',
        'text': _headerTextController.text.trim(),
      });
    } else if (_headerType == 'IMAGE') {
      String? handle;
      if (_imageBytes != null && _imageMimeType != null) {
        handle = await provider.uploadImageToMeta(_imageBytes!, _imageMimeType!);
        if (handle == null) {
          if (!mounted) return;
          _showError('Image upload to Meta failed. Please try again.');
          return;
        }
      }
      if (handle != null) {
        components.add({
          'type': 'HEADER',
          'format': 'IMAGE',
          'example': {
            'header_handle': [handle],
          },
        });
      }
    }

    // Body
    final bodyText = _bodyController.text.trim();
    final varMatches = RegExp(r'\{\{(\d+)\}\}').allMatches(bodyText).toList();
    final bodyComponent = <String, dynamic>{
      'type': 'BODY',
      'text': bodyText,
    };
    if (varMatches.isNotEmpty) {
      bodyComponent['example'] = {
        'body_text': [
          varMatches.map((m) {
            final n = int.parse(m.group(1)!);
            final val = _varControllers[n]?.text.trim() ?? '';
            return val.isNotEmpty ? val : 'Example$n';
          }).toList(),
        ],
      };
    }
    components.add(bodyComponent);

    // Footer
    final footerText = _footerController.text.trim();
    if (footerText.isNotEmpty) {
      components.add({'type': 'FOOTER', 'text': footerText});
    }

    // Buttons
    if (_buttons.isNotEmpty) {
      final btnList = <Map<String, dynamic>>[];
      for (final b in _buttons) {
        final entry = <String, dynamic>{
          'type': b.type,
          'text': b.textController.text.trim(),
        };
        if (b.type == 'URL') entry['url'] = b.extraController.text.trim();
        if (b.type == 'PHONE_NUMBER') {
          entry['phone_number'] = b.extraController.text.trim();
        }
        btnList.add(entry);
      }
      components.add({'type': 'BUTTONS', 'buttons': btnList});
    }

    // Create on Meta
    final (:error, :templateId) = await provider.createTemplate(
      name: templateName,
      language: _language,
      category: _category,
      components: components,
    );

    if (!mounted) return;

    if (error != null) {
      _showError(error);
      return;
    }

    // Sync to outreach Supabase table
    if (templateId != null) {
      await provider.syncTemplateToDb(
        metaTemplateId: templateId,
        templateName: templateName,
        status: 'PENDING',
        language: _language,
        category: _category,
        headerType: _headerType,
        headerText: _headerType == 'TEXT' ? _headerTextController.text.trim() : null,
        bodyText: bodyText,
        buttons: _buttons
            .map((b) => {'type': b.type, 'text': b.textController.text.trim()})
            .toList(),
        offerImageUrl: offerImageUrl,
      );
    }

    if (!mounted) return;
    VividToast.show(context,
      message: 'Template submitted for Meta approval',
      type: ToastType.success,
    );
    await provider.fetchTemplates();
    if (mounted) Navigator.pop(context);
  }

  void _showError(String msg) {
    final vc = context.vividColors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: vc.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Submission Failed',
            style: TextStyle(color: vc.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(msg, style: TextStyle(color: vc.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: VividColors.cyan)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
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
      VividToast.show(context, message: 'Image exceeds 5 MB limit', type: ToastType.error);
      return;
    }
    final ext = (file.extension ?? 'jpg').toLowerCase();
    setState(() {
      _imageBytes = file.bytes;
      _imageName = file.name;
      _imageMimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      _imageSize = file.bytes!.lengthInBytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<OutreachProvider>();
    final isSubmitting = provider.isSubmittingTemplate;

    return Scaffold(
      body: Column(
        children: [
          _buildTopBar(context, isSubmitting),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth > 900;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildForm(context, isSubmitting)),
                    Container(width: 1, color: vc.border),
                    Expanded(flex: 2, child: _buildPreviewColumn(context)),
                  ],
                );
              }
              return _buildForm(context, isSubmitting);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isSubmitting) {
    final vc = context.vividColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
      decoration: BoxDecoration(
        color: isDark ? vc.surface : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? vc.border : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: isSubmitting ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Back'),
            style: TextButton.styleFrom(
              foregroundColor: VividColors.cyan,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New Outreach Template',
                    style: TextStyle(
                        color: vc.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                Text('Submit a new WhatsApp template for the outreach account',
                    style: TextStyle(color: vc.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, bool isSubmitting) {
    final vc = context.vividColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(context, title: 'Template Info', child: Column(
              children: [
                _buildField(context, label: 'Template Name *',
                  helper: 'Type naturally — spaces become underscores, text auto-lowercased',
                  child: TextFormField(
                    controller: _nameController,
                    style: _inputTextStyle(context),
                    decoration: _inputDecoration(context, 'e.g. summer_sale_2025'),
                    inputFormatters: [_TemplateNameFormatter()],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Template name is required';
                      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v.trim())) {
                        return 'Only lowercase letters, numbers, underscores';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildField(context, label: 'Language',
                      child: _buildDropdown(context, value: _language,
                        items: _languages.map((e) => DropdownMenuItem(
                          value: e.$1, child: Text(e.$2, style: _inputTextStyle(context)))).toList(),
                        onChanged: (v) => setState(() => _language = v ?? _language),
                      ),
                    )),
                    const SizedBox(width: 14),
                    Expanded(child: _buildField(context, label: 'Category',
                      child: _buildDropdown(context, value: _category,
                        items: _categories.map((e) => DropdownMenuItem(
                          value: e.$1, child: Text(e.$2, style: _inputTextStyle(context)))).toList(),
                        onChanged: (v) => setState(() => _category = v ?? _category),
                      ),
                    )),
                  ],
                ),
              ],
            )),
            const SizedBox(height: 20),

            _buildSection(context, title: 'Content', child: Column(
              children: [
                _buildField(context, label: 'Header (optional)',
                  child: _buildDropdown(context, value: _headerType, items: [
                    DropdownMenuItem(value: 'NONE',
                      child: Text('None', style: TextStyle(color: vc.textPrimary, fontSize: 13))),
                    DropdownMenuItem(value: 'TEXT',
                      child: Text('Text', style: TextStyle(color: vc.textPrimary, fontSize: 13))),
                    DropdownMenuItem(value: 'IMAGE',
                      child: Text('Image', style: TextStyle(color: vc.textPrimary, fontSize: 13))),
                  ], onChanged: (v) => setState(() {
                    _headerType = v ?? 'NONE';
                    _imageBytes = null;
                  })),
                ),
                if (_headerType == 'TEXT') ...[
                  const SizedBox(height: 14),
                  _buildField(context, label: 'Header Text',
                    child: TextFormField(
                      controller: _headerTextController,
                      style: _inputTextStyle(context),
                      decoration: _inputDecoration(context, 'Header text'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
                if (_headerType == 'IMAGE') ...[
                  const SizedBox(height: 14),
                  _buildImageUploadZone(context),
                ],
                const SizedBox(height: 14),
                _buildField(context, label: 'Body *',
                  helper: 'Use {{1}}, {{2}} etc. for variables. Meta requires example values.',
                  child: Stack(children: [
                    TextFormField(
                      controller: _bodyController,
                      style: _inputTextStyle(context),
                      decoration: _inputDecoration(context, 'Enter your message body...')
                          .copyWith(contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 32)),
                      maxLines: 6,
                      maxLength: 1024,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Body text is required';
                        final trimmed = v.trim();
                        if (trimmed.startsWith('{{') || trimmed.endsWith('}}')) {
                          return "Variables can't be at the start or end of the message body.";
                        }
                        return null;
                      },
                      onChanged: (v) {
                        _syncVarControllers(v);
                        setState(() {});
                      },
                    ),
                    Positioned(
                      bottom: 8, right: 12,
                      child: Text('${_bodyController.text.length}/1024',
                          style: TextStyle(color: vc.textMuted, fontSize: 10)),
                    ),
                  ]),
                ),
                if (_varControllers.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildField(context, label: 'Variable Examples *',
                    helper: 'Example values sent to Meta for approval',
                    child: Column(
                      children: (_varControllers.keys.toList()..sort())
                          .map((n) => _buildVarRow(context, n)).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _buildField(context, label: 'Footer (optional)',
                  helper: 'Footer note or unsubscribe text',
                  child: TextFormField(
                    controller: _footerController,
                    style: _inputTextStyle(context),
                    decoration: _inputDecoration(context, 'e.g. Reply STOP to unsubscribe'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            )),
            const SizedBox(height: 20),

            _buildSection(context, title: 'Buttons (optional)',
              titleTrailing: _buttons.length < 3
                  ? TextButton.icon(
                      onPressed: () => setState(() => _buttons.add(_ButtonEntry('QUICK_REPLY'))),
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                        foregroundColor: VividColors.cyan,
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  : null,
              child: Column(children: [
                if (_buttons.isEmpty)
                  Text('No buttons. Click "+ Add" to add up to 3 buttons.',
                      style: TextStyle(color: vc.textMuted, fontSize: 12)),
                ..._buttons.asMap().entries
                    .map((e) => _buildButtonEntry(context, e.key, e.value)),
                if (_buttons.length >= 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text("Maximum 3 buttons allowed per Meta's requirements",
                        style: TextStyle(color: vc.textMuted, fontSize: 11)),
                  ),
              ]),
            ),
            const SizedBox(height: 28),

            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: VividColors.cyan,
                    foregroundColor: vc.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  child: isSubmitting
                      ? SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: vc.background))
                      : const Text('Submit for Approval'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: vc.textMuted,
                  side: BorderSide(color: VividColors.tealBlue.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  textStyle: const TextStyle(fontSize: 14),
                ),
                child: const Text('Cancel'),
              ),
            ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── Preview ────────────────────────────────────────────────────────────────

  Widget _buildPreviewColumn(BuildContext context) {
    final vc = context.vividColors;
    return Container(
      color: vc.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Text('LIVE PREVIEW',
                style: TextStyle(
                    color: vc.textMuted, fontSize: 11,
                    fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFEAE0D5),
              padding: const EdgeInsets.all(20),
              child: _previewBody.isEmpty && _previewHeaderText.isEmpty && _imageBytes == null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 48,
                            color: const Color(0xFF90A4AE).withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text('Add components to see preview',
                            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13)),
                      ]),
                    )
                  : Align(alignment: Alignment.topLeft, child: _buildPreviewBubble()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBubble() {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(10),
        bottomLeft: Radius.circular(10),
        bottomRight: Radius.circular(10),
      ),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: const Color(0xFF25D366),
              child: Text(_previewName,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
            ),
            if (_headerType == 'TEXT' && _previewHeaderText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Text(_previewHeaderText,
                    style: const TextStyle(
                        color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            if (_headerType == 'IMAGE')
              _imageBytes != null
                  ? Image.memory(_imageBytes!, width: double.infinity, fit: BoxFit.contain)
                  : Container(
                      height: 100, color: const Color(0xFFDDE3EA),
                      child: const Center(
                          child: Icon(Icons.image_outlined, size: 36, color: Color(0xFF90A4AE)))),
            if (_previewBody.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: _buildBodyRichText(_previewBody),
              ),
            if (_previewFooter.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                child: Text(_previewFooter,
                    style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 10, height: 1.4)),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 4, 10, 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('9:41', style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 10)),
              ),
            ),
            if (_buttons.isNotEmpty) ...[
              const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
              ..._buttons.asMap().entries.map((e) {
                final i = e.key;
                final b = e.value;
                final icon = switch (b.type) {
                  'URL' => Icons.open_in_new_rounded,
                  'PHONE_NUMBER' => Icons.phone_rounded,
                  _ => Icons.reply_rounded,
                };
                final label = b.textController.text.isEmpty ? b.type : b.textController.text;
                return Column(children: [
                  if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(icon, size: 14, color: const Color(0xFF0088CC)),
                      const SizedBox(width: 6),
                      Text(label,
                          style: const TextStyle(
                              color: Color(0xFF0088CC), fontSize: 13, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ]);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBodyRichText(String text) {
    final spans = <TextSpan>[];
    final re = RegExp(r'\{\{(\d+)\}\}');
    int last = 0;
    for (final match in re.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(
            text: text.substring(last, match.start),
            style: const TextStyle(color: Color(0xFF111111), fontSize: 13)));
      }
      final n = int.parse(match.group(1)!);
      final exampleVal = _varControllers[n]?.text.trim() ?? '';
      if (exampleVal.isNotEmpty) {
        spans.add(TextSpan(
            text: exampleVal,
            style: const TextStyle(color: Color(0xFF111111), fontSize: 13)));
      } else {
        spans.add(TextSpan(
            text: match.group(0),
            style: const TextStyle(
                color: VividColors.cyan, fontSize: 13, fontWeight: FontWeight.w600)));
      }
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(
          text: text.substring(last),
          style: const TextStyle(color: Color(0xFF111111), fontSize: 13)));
    }
    return RichText(text: TextSpan(children: spans, style: const TextStyle(height: 1.5)));
  }

  // ─── Image upload ───────────────────────────────────────────────────────────

  Widget _buildImageUploadZone(BuildContext context) {
    final vc = context.vividColors;
    if (_imageBytes != null) {
      final kb = (_imageSize ?? 0) / 1024;
      final sizeStr = kb > 1024
          ? '${(kb / 1024).toStringAsFixed(1)} MB'
          : '${kb.toStringAsFixed(0)} KB';
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: vc.background, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: VividColors.statusSuccess.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(_imageBytes!, width: 60, height: 60, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_imageName ?? '', style: TextStyle(color: vc.textPrimary, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
              Text(sizeStr, style: TextStyle(color: vc.textMuted, fontSize: 11)),
            ],
          )),
          IconButton(
            icon: Icon(Icons.close_rounded, color: vc.textMuted, size: 18),
            onPressed: () => setState(() {
              _imageBytes = null;
              _imageName = null;
              _imageMimeType = null;
              _imageSize = null;
            }),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ]),
      );
    }

    return GestureDetector(
      onTap: _pickImage,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: vc.popupBorder),
        child: Container(
          height: 100, color: Colors.transparent,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.cloud_upload_outlined, color: vc.textMuted, size: 28),
            const SizedBox(height: 6),
            Text('Click to upload image',
                style: TextStyle(color: vc.textMuted, fontSize: 12)),
            const SizedBox(height: 2),
            Text('JPEG or PNG, max 5 MB · Recommended: 1200 × 630 px',
                style: TextStyle(color: vc.textMuted, fontSize: 10)),
          ]),
        ),
      ),
    );
  }

  // ─── Button entry ───────────────────────────────────────────────────────────

  Widget _buildButtonEntry(BuildContext context, int index, _ButtonEntry entry) {
    final vc = context.vividColors;
    const types = [
      ('QUICK_REPLY', 'Quick Reply'),
      ('URL', 'Visit Website'),
      ('PHONE_NUMBER', 'Call Phone'),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: vc.background, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: vc.border),
        ),
        child: Column(children: [
          Row(children: [
            Expanded(child: _buildDropdown(context, value: entry.type,
              items: types.map((t) => DropdownMenuItem(
                value: t.$1, child: Text(t.$2, style: _inputTextStyle(context)))).toList(),
              onChanged: (v) { if (v != null) setState(() => entry.type = v); },
            )),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.close_rounded, color: vc.textMuted, size: 16),
              onPressed: () => setState(() => _buttons.removeAt(index)),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
          ]),
          const SizedBox(height: 8),
          TextFormField(
            controller: entry.textController,
            style: _inputTextStyle(context),
            decoration: _inputDecoration(context, 'Button label'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Label required' : null,
            onChanged: (_) => setState(() {}),
          ),
          if (entry.type == 'URL' || entry.type == 'PHONE_NUMBER') ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: entry.extraController,
              style: _inputTextStyle(context),
              decoration: _inputDecoration(context,
                  entry.type == 'URL' ? 'https://example.com' : '+1234567890'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return entry.type == 'URL' ? 'URL required' : 'Phone required';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
          ],
        ]),
      ),
    );
  }

  // ─── Variable row ───────────────────────────────────────────────────────────

  Widget _buildVarRow(BuildContext context, int n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: VividColors.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text('{{$n}}',
                style: const TextStyle(
                    color: VividColors.cyan, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _varControllers[n],
            style: _inputTextStyle(context),
            decoration: _inputDecoration(context, 'Example value (required by Meta)'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Example for {{$n}} is required' : null,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  // ─── Shared helpers ─────────────────────────────────────────────────────────

  Widget _buildSection(BuildContext context,
      {required String title, required Widget child, Widget? titleTrailing}) {
    final vc = context.vividColors;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(children: [
            Text(title.toUpperCase(),
                style: TextStyle(color: vc.textPrimary, fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            if (titleTrailing != null) ...[const Spacer(), titleTrailing],
          ]),
        ),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ]),
    );
  }

  Widget _buildField(BuildContext context,
      {required String label, required Widget child, String? helper}) {
    final vc = context.vividColors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(color: vc.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      child,
      if (helper != null) ...[
        const SizedBox(height: 5),
        Text(helper, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
      ],
    ]);
  }

  Widget _buildDropdown<T>(BuildContext context,
      {required T value, required List<DropdownMenuItem<T>> items,
      required void Function(T?) onChanged}) {
    final vc = context.vividColors;
    return DropdownButtonFormField<T>(
      initialValue: value, items: items, onChanged: onChanged,
      style: _inputTextStyle(context), dropdownColor: vc.surfaceAlt,
      decoration: _inputDecoration(context, null),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: vc.textMuted, size: 18),
    );
  }

  TextStyle _inputTextStyle(BuildContext context) =>
      TextStyle(color: context.vividColors.textPrimary, fontSize: 13);

  InputDecoration _inputDecoration(BuildContext context, String? hint) {
    final vc = context.vividColors;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: vc.textMuted, fontSize: 13),
      filled: true, fillColor: vc.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: VividColors.tealBlue.withValues(alpha: 0.25))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: VividColors.tealBlue.withValues(alpha: 0.25))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: VividColors.cyan, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: VividColors.statusUrgent)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: VividColors.statusUrgent, width: 1.5)),
      errorStyle: const TextStyle(color: VividColors.statusUrgent, fontSize: 11),
    );
  }
}

class _ButtonEntry {
  String type;
  final TextEditingController textController = TextEditingController();
  final TextEditingController extraController = TextEditingController();
  _ButtonEntry(this.type);
  void dispose() {
    textController.dispose();
    extraController.dispose();
  }
}

class _TemplateNameFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return newValue.copyWith(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const radius = Radius.circular(8);
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height), radius);
    final path = Path()..addRRect(rrect);
    const dashLen = 6.0;
    const gapLen = 5.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        canvas.drawPath(metric.extractPath(dist, dist + dashLen), paint);
        dist += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
