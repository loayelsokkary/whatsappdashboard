import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/templates_provider.dart';
import '../theme/vivid_theme.dart';

class TemplateSetupDialog extends StatefulWidget {
  final WhatsAppTemplate template;
  final List<String>? existingLabels;
  final List<String>? existingSources;

  const TemplateSetupDialog({
    super.key,
    required this.template,
    this.existingLabels,
    this.existingSources,
  });

  @override
  State<TemplateSetupDialog> createState() => _TemplateSetupDialogState();
}

class _TemplateSetupDialogState extends State<TemplateSetupDialog> {
  static const _servicesList = [
    'Full Body Laser',
    'Full Body Laser with out back and abdomen',
    'Glassy Skin',
    'Calcium',
    'Filler Juvederm',
    'Botox Dysport',
    'Botox Allergan',
    'Filler',
    'Botox Nabota',
  ];

  static const _sourceOptions = ['customer_data', 'ai_extracted', 'static'];

  // Services
  bool _allServices = false;
  final Set<String> _selectedServices = {};

  // Body variables
  late final List<int> _varNumbers;
  late final List<TextEditingController> _labelControllers;
  late List<String> _varSources;

  // Offer image (only when headerType == IMAGE)
  Uint8List? _imageBytes;
  String? _imageMimeType;
  String? _imageFileName;

  bool _saving = false;

  bool get _isImageTemplate =>
      widget.template.headerType.toUpperCase() == 'IMAGE';

  bool get _canSave {
    if (_saving) return false;
    if (!_allServices && _selectedServices.isEmpty) return false;
    for (final c in _labelControllers) {
      if (c.text.trim().isEmpty) return false;
    }
    if (_isImageTemplate && _imageBytes == null) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    final nums = RegExp(r'\{\{(\d+)\}\}')
        .allMatches(widget.template.body)
        .map((m) => int.parse(m.group(1)!))
        .toSet()
        .toList()
      ..sort();
    _varNumbers = nums;
    _labelControllers = List.generate(nums.length, (i) {
      final existing = widget.existingLabels;
      final text = (existing != null && i < existing.length) ? existing[i] : '';
      return TextEditingController(text: text);
    });
    _varSources = List.generate(nums.length, (i) {
      final existing = widget.existingSources;
      return (existing != null && i < existing.length)
          ? existing[i]
          : 'customer_data';
    });
  }

  @override
  void dispose() {
    for (final c in _labelControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    final ext = (file.extension ?? 'jpg').toLowerCase();
    setState(() {
      _imageBytes = file.bytes;
      _imageMimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      _imageFileName = file.name;
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    final provider = context.read<TemplatesProvider>();

    // Upload offer image to Supabase Storage if selected
    String? offerImageUrl;
    if (_isImageTemplate && _imageBytes != null) {
      offerImageUrl = await provider.uploadOfferImageToStorage(
        _imageBytes!,
        widget.template.name,
        _imageMimeType ?? 'image/jpeg',
      );
      if (offerImageUrl == null) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Image upload to storage failed. Try again.'),
          backgroundColor: VividColors.statusUrgent,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    }

    final targetServices =
        _allServices ? 'all' : _selectedServices.toList();
    final labels = _labelControllers.map((c) => c.text.trim()).toList();
    final sources = List<String>.from(_varSources);

    final error = await provider.syncSingleTemplate(
      widget.template,
      targetServices: targetServices,
      variableLabels: labels,
      variableSources: sources,
      offerImageUrl: offerImageUrl,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed: $error'),
        backgroundColor: VividColors.statusUrgent,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      Navigator.pop(context, true);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    return Dialog(
      backgroundColor: vc.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 560,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, vc),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildServicesSection(vc),
                    if (_varNumbers.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildVariablesSection(vc),
                    ],
                    if (_isImageTemplate) ...[
                      const SizedBox(height: 24),
                      _buildImageSection(vc),
                    ],
                  ],
                ),
              ),
            ),
            _buildFooter(context, vc),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, VividColorScheme vc) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: vc.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.smart_toy_rounded,
              color: VividColors.cyan, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setup for AI',
                  style: TextStyle(
                    color: vc.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  widget.template.name,
                  style: TextStyle(
                    color: vc.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: vc.textMuted, size: 20),
            onPressed: _saving ? null : () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ─── Services section ─────────────────────────────────────────────────────

  Widget _buildServicesSection(VividColorScheme vc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Target Services', vc),
        const SizedBox(height: 12),

        // All Services toggle
        GestureDetector(
          onTap: () => setState(() {
            _allServices = !_allServices;
            if (_allServices) _selectedServices.clear();
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _allServices
                  ? VividColors.cyan.withValues(alpha: 0.12)
                  : vc.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _allServices
                    ? VividColors.cyan.withValues(alpha: 0.5)
                    : vc.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _allServices
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 16,
                  color: _allServices ? VividColors.cyan : vc.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  'All Services',
                  style: TextStyle(
                    color: _allServices
                        ? VividColors.cyan
                        : vc.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Individual service chips
        AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _allServices ? 0.35 : 1.0,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _servicesList.map((service) {
              final selected = _selectedServices.contains(service);
              return GestureDetector(
                onTap: _allServices
                    ? null
                    : () => setState(() {
                          if (selected) {
                            _selectedServices.remove(service);
                          } else {
                            _selectedServices.add(service);
                          }
                        }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? VividColors.brightBlue.withValues(alpha: 0.12)
                        : vc.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected
                          ? VividColors.brightBlue.withValues(alpha: 0.5)
                          : vc.border,
                    ),
                  ),
                  child: Text(
                    service,
                    style: TextStyle(
                      color: selected
                          ? VividColors.brightBlue
                          : vc.textSecondary,
                      fontSize: 12,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── Variables section ────────────────────────────────────────────────────

  Widget _buildVariablesSection(VividColorScheme vc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Body Variables', vc),
        const SizedBox(height: 4),
        Text(
          'Label each {{N}} variable so the AI knows what to fill in',
          style: TextStyle(color: vc.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 12),
        ...List.generate(_varNumbers.length, (i) {
          final n = _varNumbers[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                // Variable tag
                Container(
                  width: 38,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: VividColors.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '{{$n}}',
                    style: const TextStyle(
                      color: VividColors.cyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Label field
                Expanded(
                  child: TextField(
                    controller: _labelControllers[i],
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: vc.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. customer_name',
                      hintStyle:
                          TextStyle(color: vc.textMuted, fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: vc.surfaceAlt,
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
                        borderSide: const BorderSide(
                            color: VividColors.cyan, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Source dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: vc.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: vc.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _varSources[i],
                      dropdownColor: vc.surface,
                      style: TextStyle(
                          color: vc.textSecondary, fontSize: 12),
                      items: _sourceOptions
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s,
                                    style: TextStyle(
                                        color: vc.textSecondary,
                                        fontSize: 12)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _varSources[i] = v);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ─── Image section ────────────────────────────────────────────────────────

  Widget _buildImageSection(VividColorScheme vc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Offer Image', vc),
        const SizedBox(height: 4),
        Text(
          'Upload a permanent image to Supabase Storage for AI use',
          style: TextStyle(color: vc.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 12),
        if (_imageBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _imageBytes!,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: VividColors.statusSuccess, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _imageFileName ?? 'Image selected',
                  style: const TextStyle(
                      color: VividColors.statusSuccess, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: _pickImage,
                style: TextButton.styleFrom(
                  foregroundColor: vc.textMuted,
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Replace'),
              ),
            ],
          ),
        ] else ...[
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 96,
              width: double.infinity,
              decoration: BoxDecoration(
                color: vc.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: vc.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined,
                      color: vc.textMuted, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    'Click to upload image',
                    style: TextStyle(
                        color: vc.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  Text('PNG or JPEG',
                      style:
                          TextStyle(color: vc.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─── Footer ───────────────────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context, VividColorScheme vc) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: vc.border))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: vc.textMuted),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _canSave ? _save : null,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.cloud_upload_rounded, size: 16),
            label: Text(_saving ? 'Saving…' : 'Save to AI'),
            style: FilledButton.styleFrom(
              backgroundColor: VividColors.cyan,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  VividColors.cyan.withValues(alpha: 0.3),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionLabel(String title, VividColorScheme vc) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: vc.textPrimary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}
