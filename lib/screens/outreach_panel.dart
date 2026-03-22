import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/outreach_models.dart';
import '../models/models.dart';
import '../providers/outreach_provider.dart';
import '../theme/vivid_theme.dart';
import '../widgets/outreach_chat.dart';

/// Main outreach tab widget with 4 sub-sections.
class OutreachPanel extends StatefulWidget {
  const OutreachPanel({super.key});

  @override
  State<OutreachPanel> createState() => _OutreachPanelState();
}

class _OutreachPanelState extends State<OutreachPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    Future.microtask(() {
      if (!mounted) return;
      final p = context.read<OutreachProvider>();
      p.fetchContacts();
      p.fetchBroadcasts();
      p.fetchTemplates();
      p.loadWebhookUrl();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: vc.background,
      child: Column(
        children: [
          // Sub-navigation
          Container(
            decoration: BoxDecoration(
              color: vc.surface,
              border: Border(bottom: BorderSide(color: vc.border)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: isMobile,
              tabAlignment: isMobile ? TabAlignment.start : null,
              indicatorColor: VividColors.cyan,
              indicatorWeight: 3,
              labelColor: VividColors.cyan,
              unselectedLabelColor: vc.textMuted,
              labelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: [
                Tab(
                    icon: const Icon(Icons.contacts, size: 18),
                    text: isMobile ? null : 'Contacts'),
                Tab(
                    icon: const Icon(Icons.chat, size: 18),
                    text: isMobile ? null : 'Conversations'),
                Tab(
                    icon: const Icon(Icons.campaign, size: 18),
                    text: isMobile ? null : 'Broadcasts'),
                Tab(
                    icon: const Icon(Icons.description, size: 18),
                    text: isMobile ? null : 'Templates'),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ContactsSection(
                    onSendMessage: (contact) {
                      context.read<OutreachProvider>().selectContact(contact);
                      _tabController.animateTo(1);
                    }),
                const OutreachChat(),
                const _BroadcastsSection(),
                const _TemplatesSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// CONTACTS SECTION
// ============================================

class _ContactsSection extends StatefulWidget {
  final void Function(OutreachContact) onSendMessage;

  const _ContactsSection({required this.onSendMessage});

  @override
  State<_ContactsSection> createState() => _ContactsSectionState();
}

class _ContactsSectionState extends State<_ContactsSection> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<OutreachProvider>();

    return Column(
      children: [
        // Pipeline chips
        _buildPipeline(vc, provider),
        // Search + actions bar
        _buildToolbar(vc, provider),
        // Contact list
        Expanded(child: _buildContactList(vc, provider)),
      ],
    );
  }

  Widget _buildPipeline(VividColorScheme vc, OutreachProvider provider) {
    final counts = provider.contactCounts;
    final total = provider.allContacts.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // "All" chip
            _PipelineChip(
              label: 'All',
              count: total,
              color: VividColors.cyan,
              isSelected: provider.contactFilter == null,
              onTap: () => provider.setContactFilter(null),
            ),
            const SizedBox(width: 8),
            ...ContactStatus.values.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _PipelineChip(
                    label: s.label,
                    count: counts[s] ?? 0,
                    color: s.color,
                    isSelected: provider.contactFilter == s,
                    onTap: () => provider.setContactFilter(
                        provider.contactFilter == s ? null : s),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(VividColorScheme vc, OutreachProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          // Search
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: vc.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: vc.border),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: vc.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: TextStyle(color: vc.textMuted, fontSize: 13),
                  prefixIcon:
                      Icon(Icons.search, size: 18, color: vc.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (v) => provider.setContactSearch(v),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Import CSV
          OutlinedButton.icon(
            onPressed: () => _showImportDialog(context, provider),
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('Import'),
            style: OutlinedButton.styleFrom(
              foregroundColor: vc.textSecondary,
              side: BorderSide(color: vc.border),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          // Add Contact
          FilledButton.icon(
            onPressed: () => _showAddContactDialog(context, provider),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Contact'),
            style: FilledButton.styleFrom(
              backgroundColor: VividColors.cyan,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactList(VividColorScheme vc, OutreachProvider provider) {
    if (provider.isLoadingContacts && provider.allContacts.isEmpty) {
      return const Center(
        child:
            CircularProgressIndicator(strokeWidth: 2, color: VividColors.cyan),
      );
    }

    final contacts = provider.contacts;
    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline,
                size: 48, color: vc.textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No contacts found',
                style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Add your first outreach contact',
                style: TextStyle(color: vc.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 700;

      if (isWide) {
        // Table view
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildTable(vc, contacts, provider),
        );
      }

      // Card view (mobile)
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          return _ContactCard(
            contact: contacts[index],
            onSendMessage: widget.onSendMessage,
            onChangeStatus: (c, s) =>
                provider.updateContact(c.id, {'status': s.dbValue}),
            onDelete: (c) => provider.deleteContact(c.id),
          );
        },
      );
    });
  }

  Widget _buildTable(VividColorScheme vc, List<OutreachContact> contacts,
      OutreachProvider provider) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(vc.surface),
      dataRowColor: WidgetStateProperty.all(Colors.transparent),
      headingTextStyle: TextStyle(
          color: vc.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
      dataTextStyle: TextStyle(color: vc.textPrimary, fontSize: 13),
      columnSpacing: 24,
      columns: const [
        DataColumn(label: Text('COMPANY')),
        DataColumn(label: Text('CONTACT')),
        DataColumn(label: Text('PHONE')),
        DataColumn(label: Text('INDUSTRY')),
        DataColumn(label: Text('STATUS')),
        DataColumn(label: Text('LAST CONTACTED')),
        DataColumn(label: Text('ACTIONS')),
      ],
      rows: contacts.map((c) {
        return DataRow(cells: [
          DataCell(Text(c.companyName,
              style: const TextStyle(fontWeight: FontWeight.w600))),
          DataCell(Text(c.contactName ?? '-')),
          DataCell(Text(c.phone)),
          DataCell(Text(c.industry ?? '-')),
          DataCell(_StatusBadge(status: c.status)),
          DataCell(Text(c.lastContactedAt != null
              ? _formatDate(c.lastContactedAt!)
              : 'Never')),
          DataCell(_ActionMenu(
            contact: c,
            onSendMessage: widget.onSendMessage,
            onChangeStatus: (s) =>
                provider.updateContact(c.id, {'status': s.dbValue}),
            onDelete: () => provider.deleteContact(c.id),
          )),
        ]);
      }).toList(),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // ─── Add Contact Dialog ───

  void _showAddContactDialog(
      BuildContext context, OutreachProvider provider) {
    final vc = context.vividColors;
    final companyC = TextEditingController();
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final emailC = TextEditingController();
    final industryC = TextEditingController();
    final notesC = TextEditingController();
    var selectedStatus = ContactStatus.lead;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          backgroundColor: vc.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(Icons.person_add, size: 20, color: VividColors.cyan),
              const SizedBox(width: 8),
              Text('Add Contact',
                  style: TextStyle(
                      color: vc.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(vc, companyC, 'Company Name *'),
                  const SizedBox(height: 10),
                  _dialogField(vc, nameC, 'Contact Name'),
                  const SizedBox(height: 10),
                  _dialogField(vc, phoneC, 'Phone *'),
                  const SizedBox(height: 10),
                  _dialogField(vc, emailC, 'Email'),
                  const SizedBox(height: 10),
                  _dialogField(vc, industryC, 'Industry'),
                  const SizedBox(height: 10),
                  // Status dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: vc.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: vc.border),
                    ),
                    child: DropdownButtonFormField<ContactStatus>(
                      value: selectedStatus,
                      dropdownColor: vc.surface,
                      style: TextStyle(
                          color: vc.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Status',
                        labelStyle:
                            TextStyle(color: vc.textMuted, fontSize: 12),
                        border: InputBorder.none,
                      ),
                      items: ContactStatus.values
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: s.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(s.label),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedStatus = v);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  _dialogField(vc, notesC, 'Notes', maxLines: 3),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Cancel', style: TextStyle(color: vc.textSecondary)),
            ),
            FilledButton(
              onPressed: () async {
                if (companyC.text.trim().isEmpty ||
                    phoneC.text.trim().isEmpty) {
                  return;
                }
                final contact = OutreachContact(
                  id: '',
                  companyName: companyC.text.trim(),
                  contactName: nameC.text.trim().isNotEmpty
                      ? nameC.text.trim()
                      : null,
                  phone: phoneC.text.trim(),
                  email: emailC.text.trim().isNotEmpty
                      ? emailC.text.trim()
                      : null,
                  industry: industryC.text.trim().isNotEmpty
                      ? industryC.text.trim()
                      : null,
                  status: selectedStatus,
                  notes: notesC.text.trim().isNotEmpty
                      ? notesC.text.trim()
                      : null,
                  createdAt: DateTime.now(),
                );
                Navigator.pop(ctx);
                await provider.createContact(contact);
              },
              style: FilledButton.styleFrom(
                  backgroundColor: VividColors.cyan,
                  foregroundColor: Colors.white),
              child: const Text('Add'),
            ),
          ],
        );
      }),
    );
  }

  Widget _dialogField(VividColorScheme vc, TextEditingController controller,
      String label,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: vc.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: vc.textMuted, fontSize: 12),
        filled: true,
        fillColor: vc.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: vc.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: vc.border),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  // ─── CSV Import Dialog ───

  void _showImportDialog(BuildContext context, OutreachProvider provider) {
    final vc = context.vividColors;
    final csvController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: vc.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.upload_file, size: 20, color: VividColors.cyan),
            const SizedBox(width: 8),
            Text('Import Contacts',
                style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste CSV data with columns: company_name, contact_name, phone, email, industry',
                style: TextStyle(color: vc.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: VividColors.cyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Example:\nAcme Corp,John Doe,+97312345678,john@acme.com,Tech\nBigCo,Jane Smith,+97398765432,jane@bigco.com,Finance',
                  style: TextStyle(
                      color: vc.textSecondary,
                      fontSize: 11,
                      fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: csvController,
                maxLines: 8,
                style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: 12,
                    fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'Paste CSV here...',
                  hintStyle: TextStyle(color: vc.textMuted),
                  filled: true,
                  fillColor: vc.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: vc.border),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: vc.textSecondary)),
          ),
          FilledButton(
            onPressed: () async {
              final lines = csvController.text
                  .trim()
                  .split('\n')
                  .where((l) => l.trim().isNotEmpty)
                  .toList();
              if (lines.isEmpty) return;

              final rows = <Map<String, dynamic>>[];
              for (final line in lines) {
                final parts = line.split(',');
                if (parts.length < 3) continue;
                rows.add({
                  'company_name': parts[0].trim(),
                  'contact_name': parts.length > 1 ? parts[1].trim() : null,
                  'phone': parts.length > 2 ? parts[2].trim() : '',
                  'email': parts.length > 3 ? parts[3].trim() : null,
                  'industry': parts.length > 4 ? parts[4].trim() : null,
                });
              }

              Navigator.pop(ctx);
              final result = await provider.bulkImportContacts(rows);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.error ??
                        'Imported ${result.imported} contacts'),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
                backgroundColor: VividColors.cyan,
                foregroundColor: Colors.white),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }
}

// ─── Pipeline Chip ───

class _PipelineChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PipelineChip({
    required this.label,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Text('$count',
                style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Status Badge ───

class _StatusBadge extends StatelessWidget {
  final ContactStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: status.color.withValues(alpha: 0.3)),
      ),
      child: Text(status.label,
          style: TextStyle(
              color: status.color,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Action Menu ───

class _ActionMenu extends StatelessWidget {
  final OutreachContact contact;
  final void Function(OutreachContact) onSendMessage;
  final void Function(ContactStatus) onChangeStatus;
  final VoidCallback onDelete;

  const _ActionMenu({
    required this.contact,
    required this.onSendMessage,
    required this.onChangeStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 18, color: vc.textMuted),
      color: vc.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'message',
          child: Row(children: [
            Icon(Icons.chat, size: 16, color: VividColors.cyan),
            const SizedBox(width: 8),
            const Text('Send Message'),
          ]),
        ),
        const PopupMenuDivider(),
        ...ContactStatus.values.map((s) => PopupMenuItem(
              value: 'status_${s.dbValue}',
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: s.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text('Mark as ${s.label}'),
              ]),
            )),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline,
                size: 16, color: VividColors.statusUrgent),
            const SizedBox(width: 8),
            Text('Delete',
                style: TextStyle(color: VividColors.statusUrgent)),
          ]),
        ),
      ],
      onSelected: (value) {
        if (value == 'message') {
          onSendMessage(contact);
        } else if (value == 'delete') {
          onDelete();
        } else if (value.startsWith('status_')) {
          final statusStr = value.substring(7);
          final status = ContactStatus.fromDb(statusStr);
          onChangeStatus(status);
        }
      },
    );
  }
}

// ─── Contact Card (mobile) ───

class _ContactCard extends StatelessWidget {
  final OutreachContact contact;
  final void Function(OutreachContact) onSendMessage;
  final void Function(OutreachContact, ContactStatus) onChangeStatus;
  final void Function(OutreachContact) onDelete;

  const _ContactCard({
    required this.contact,
    required this.onSendMessage,
    required this.onChangeStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: vc.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(contact.companyName,
                    style: TextStyle(
                        color: vc.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              _StatusBadge(status: contact.status),
            ],
          ),
          if (contact.contactName != null) ...[
            const SizedBox(height: 4),
            Text(contact.contactName!,
                style: TextStyle(color: vc.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.phone, size: 12, color: vc.textMuted),
              const SizedBox(width: 4),
              Text(contact.phone,
                  style: TextStyle(color: vc.textMuted, fontSize: 12)),
              if (contact.industry != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.business, size: 12, color: vc.textMuted),
                const SizedBox(width: 4),
                Text(contact.industry!,
                    style: TextStyle(color: vc.textMuted, fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                onTap: () => onSendMessage(contact),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: VividColors.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat, size: 12, color: VividColors.cyan),
                      const SizedBox(width: 4),
                      Text('Message',
                          style: TextStyle(
                              color: VividColors.cyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _ActionMenu(
                contact: contact,
                onSendMessage: onSendMessage,
                onChangeStatus: (s) => onChangeStatus(contact, s),
                onDelete: () => onDelete(contact),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================
// BROADCASTS SECTION
// ============================================

class _BroadcastsSection extends StatelessWidget {
  const _BroadcastsSection();

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<OutreachProvider>();

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;

      if (isMobile) {
        if (provider.selectedBroadcast != null) {
          return _BroadcastDetail(
              onBack: () => provider.clearBroadcastSelection());
        }
        return _BroadcastList();
      }

      return Row(
        children: [
          SizedBox(
            width: 360,
            child: _BroadcastList(),
          ),
          Container(width: 1, color: vc.border),
          Expanded(
            child: provider.selectedBroadcast != null
                ? const _BroadcastDetail()
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.campaign_outlined,
                            size: 48,
                            color: vc.textMuted.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('Select a broadcast to view details',
                            style: TextStyle(
                                color: vc.textMuted, fontSize: 14)),
                      ],
                    ),
                  ),
          ),
        ],
      );
    });
  }
}

class _BroadcastList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<OutreachProvider>();

    return Container(
      color: vc.surface,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: vc.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.campaign, size: 18, color: VividColors.cyan),
                const SizedBox(width: 8),
                Text('Broadcasts',
                    style: TextStyle(
                        color: vc.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: VividColors.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${provider.broadcasts.length}',
                      style: TextStyle(
                          color: VividColors.cyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () =>
                      _showCreateBroadcastDialog(context, provider),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  color: VividColors.cyan,
                  tooltip: 'Create Broadcast',
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: provider.isLoadingBroadcasts
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: VividColors.cyan))
                : provider.broadcasts.isEmpty
                    ? Center(
                        child: Text('No broadcasts yet',
                            style: TextStyle(
                                color: vc.textMuted, fontSize: 13)))
                    : ListView.builder(
                        itemCount: provider.broadcasts.length,
                        itemBuilder: (context, index) {
                          final b = provider.broadcasts[index];
                          final isSelected =
                              provider.selectedBroadcast?.id == b.id;
                          return _BroadcastCard(
                            broadcast: b,
                            isSelected: isSelected,
                            onTap: () => provider.selectBroadcast(b),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showCreateBroadcastDialog(
      BuildContext context, OutreachProvider provider) {
    final vc = context.vividColors;
    final nameC = TextEditingController();
    final bodyC = TextEditingController();
    var selectedFilter = ContactStatus.lead;
    var selectedContacts = <OutreachContact>[];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        final filtered = provider.allContacts
            .where((c) => c.status == selectedFilter)
            .toList();

        return AlertDialog(
          backgroundColor: vc.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(Icons.campaign, size: 20, color: VividColors.cyan),
              const SizedBox(width: 8),
              Text('Create Broadcast',
                  style: TextStyle(
                      color: vc.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameC,
                    style: TextStyle(color: vc.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Broadcast Name *',
                      labelStyle:
                          TextStyle(color: vc.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: vc.background,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: vc.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: vc.border)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyC,
                    maxLines: 4,
                    style: TextStyle(color: vc.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Message Body *',
                      labelStyle:
                          TextStyle(color: vc.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: vc.background,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: vc.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: vc.border)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Select Recipients',
                      style: TextStyle(
                          color: vc.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  // Status filter for recipients
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ContactStatus.values.map((s) {
                        final count = provider.allContacts
                            .where((c) => c.status == s)
                            .length;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('${s.label} ($count)'),
                            selected: selectedFilter == s,
                            selectedColor:
                                s.color.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                                color: s.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
                            side: BorderSide(
                                color: s.color.withValues(alpha: 0.3)),
                            onSelected: (_) {
                              setDialogState(() {
                                selectedFilter = s;
                                selectedContacts = [];
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Select all / contact checkboxes
                  Row(
                    children: [
                      Checkbox(
                        value: selectedContacts.length == filtered.length &&
                            filtered.isNotEmpty,
                        activeColor: VividColors.cyan,
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == true) {
                              selectedContacts = List.from(filtered);
                            } else {
                              selectedContacts = [];
                            }
                          });
                        },
                      ),
                      Text('Select all ${filtered.length}',
                          style: TextStyle(
                              color: vc.textSecondary, fontSize: 12)),
                    ],
                  ),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final checked = selectedContacts.contains(c);
                        return CheckboxListTile(
                          value: checked,
                          activeColor: VividColors.cyan,
                          title: Text(c.displayName,
                              style: TextStyle(
                                  color: vc.textPrimary, fontSize: 13)),
                          subtitle: Text(c.companyName,
                              style: TextStyle(
                                  color: vc.textMuted, fontSize: 11)),
                          dense: true,
                          onChanged: (v) {
                            setDialogState(() {
                              if (v == true) {
                                selectedContacts.add(c);
                              } else {
                                selectedContacts.remove(c);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${selectedContacts.length} contacts selected',
                      style: TextStyle(
                          color: VividColors.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Cancel', style: TextStyle(color: vc.textSecondary)),
            ),
            FilledButton(
              onPressed: () async {
                if (nameC.text.trim().isEmpty ||
                    bodyC.text.trim().isEmpty ||
                    selectedContacts.isEmpty) {
                  return;
                }
                Navigator.pop(ctx);
                await provider.createBroadcast(
                  name: nameC.text.trim(),
                  messageBody: bodyC.text.trim(),
                  selectedContacts: selectedContacts,
                );
              },
              style: FilledButton.styleFrom(
                  backgroundColor: VividColors.cyan,
                  foregroundColor: Colors.white),
              child: const Text('Create'),
            ),
          ],
        );
      }),
    );
  }
}

class _BroadcastCard extends StatelessWidget {
  final OutreachBroadcast broadcast;
  final bool isSelected;
  final VoidCallback onTap;

  const _BroadcastCard({
    required this.broadcast,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? VividColors.cyan.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? VividColors.cyan : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(color: vc.border.withValues(alpha: 0.3)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    broadcast.displayName,
                    style: TextStyle(
                      color: vc.textPrimary,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _broadcastStatusBadge(vc, broadcast.status),
              ],
            ),
            if (broadcast.messageBody != null) ...[
              const SizedBox(height: 4),
              Text(
                broadcast.messageBody!,
                style: TextStyle(color: vc.textMuted, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.people, size: 13, color: vc.textMuted),
                const SizedBox(width: 4),
                Text('${broadcast.totalRecipients}',
                    style: TextStyle(color: vc.textMuted, fontSize: 12)),
                const Spacer(),
                Text(_formatDate(broadcast.createdAt),
                    style: TextStyle(color: vc.textMuted, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _broadcastStatusBadge(VividColorScheme vc, String? status) {
    final (color, label) = switch (status) {
      'sent' => (VividColors.statusSuccess, 'Sent'),
      'sending' => (VividColors.cyan, 'Sending'),
      'scheduled' => (VividColors.statusWarning, 'Scheduled'),
      'failed' => (VividColors.statusUrgent, 'Failed'),
      _ => (Colors.grey, 'Draft'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}

class _BroadcastDetail extends StatelessWidget {
  final VoidCallback? onBack;

  const _BroadcastDetail({this.onBack});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<OutreachProvider>();
    final broadcast = provider.selectedBroadcast;
    if (broadcast == null) return const SizedBox.shrink();

    return Container(
      color: vc.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: vc.surface,
              border: Border(bottom: BorderSide(color: vc.border)),
            ),
            child: Row(
              children: [
                if (onBack != null) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: onBack,
                    color: vc.textSecondary,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(broadcast.displayName,
                          style: TextStyle(
                              color: vc.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '${broadcast.totalRecipients} recipients • Created ${_formatFullDate(broadcast.createdAt)}',
                        style:
                            TextStyle(color: vc.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Message body
          if (broadcast.messageBody != null)
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: vc.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: vc.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Message',
                      style: TextStyle(
                          color: vc.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(broadcast.messageBody!,
                      style: TextStyle(
                          color: vc.textPrimary,
                          fontSize: 13,
                          height: 1.5)),
                ],
              ),
            ),
          // Delivery stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _StatChip(
                    label: 'Delivered',
                    count: broadcast.deliveredCount,
                    color: VividColors.statusSuccess),
                const SizedBox(width: 12),
                _StatChip(
                    label: 'Failed',
                    count: broadcast.failedCount,
                    color: VividColors.statusUrgent),
                const SizedBox(width: 12),
                if (broadcast.totalRecipients > 0)
                  _StatChip(
                    label: 'Rate',
                    count: ((broadcast.deliveredCount /
                                broadcast.totalRecipients) *
                            100)
                        .round(),
                    color: VividColors.cyan,
                    suffix: '%',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Recipients header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Recipients (${provider.broadcastRecipients.length})',
                style: TextStyle(
                    color: vc.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          // Recipients list
          Expanded(
            child: provider.isLoadingRecipients
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: VividColors.cyan))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: provider.broadcastRecipients.length,
                    itemBuilder: (context, index) {
                      final r = provider.broadcastRecipients[index];
                      return _RecipientTile(recipient: r);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour12:$m $period';
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final String? suffix;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          Text('$count${suffix ?? ''}',
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RecipientTile extends StatelessWidget {
  final OutreachBroadcastRecipient recipient;

  const _RecipientTile({required this.recipient});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final isDelivered = recipient.isDelivered;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: vc.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: VividColors.cyan.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                recipient.displayName.isNotEmpty
                    ? recipient.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    color: VividColors.cyan,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipient.displayName,
                    style: TextStyle(
                        color: vc.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                if (recipient.phone != null)
                  Text(recipient.phone!,
                      style: TextStyle(color: vc.textMuted, fontSize: 11)),
              ],
            ),
          ),
          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isDelivered
                      ? VividColors.statusSuccess
                      : VividColors.statusUrgent)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDelivered ? Icons.check_circle : Icons.error,
                  size: 12,
                  color: isDelivered
                      ? VividColors.statusSuccess
                      : VividColors.statusUrgent,
                ),
                const SizedBox(width: 4),
                Text(
                  isDelivered ? 'Delivered' : (recipient.status ?? 'Pending'),
                  style: TextStyle(
                    color: isDelivered
                        ? VividColors.statusSuccess
                        : VividColors.statusUrgent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// TEMPLATES SECTION
// ============================================

class _TemplatesSection extends StatelessWidget {
  const _TemplatesSection();

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;
    final provider = context.watch<OutreachProvider>();

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Icon(Icons.description, size: 18, color: VividColors.cyan),
              const SizedBox(width: 8),
              Text('Outreach Templates',
                  style: TextStyle(
                      color: vc.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: provider.isLoadingTemplates
                    ? null
                    : () => provider.fetchTemplates(),
                icon: provider.isLoadingTemplates
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: vc.textMuted))
                    : const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: vc.textSecondary,
                  side: BorderSide(color: vc.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        // Grid
        Expanded(
          child: provider.isLoadingTemplates && provider.templates.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: VividColors.cyan))
              : provider.templates.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.article_outlined,
                              size: 48,
                              color: vc.textMuted.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text('No outreach templates',
                              style: TextStyle(
                                  color: vc.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('Sync templates from Meta to get started',
                              style: TextStyle(
                                  color: vc.textMuted, fontSize: 13)),
                        ],
                      ),
                    )
                  : LayoutBuilder(builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final crossCount = w > 1200
                          ? 4
                          : w > 800
                              ? 3
                              : w > 500
                                  ? 2
                                  : 1;

                      return GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: provider.templates.length,
                        itemBuilder: (context, index) {
                          final t = provider.templates[index];
                          return _OutreachTemplateCard(template: t);
                        },
                      );
                    }),
        ),
      ],
    );
  }
}

class _OutreachTemplateCard extends StatelessWidget {
  final WhatsAppTemplate template;

  const _OutreachTemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final vc = context.vividColors;

    final (statusColor, statusLabel) = switch (template.status.toUpperCase()) {
      'APPROVED' => (VividColors.statusSuccess, 'Approved'),
      'PENDING' || 'PENDING_DELETION' => (VividColors.statusWarning, 'Pending'),
      'REJECTED' => (VividColors.statusUrgent, 'Rejected'),
      _ => (Colors.grey, template.status),
    };

    return Container(
      decoration: BoxDecoration(
        color: vc.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: vc.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        template.name,
                        style: TextStyle(
                          color: vc.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(template.language.toUpperCase(),
                        style: TextStyle(
                            color: vc.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text(template.category,
                        style:
                            TextStyle(color: vc.textMuted, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          // Body preview
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                template.body,
                style: TextStyle(
                    color: vc.textSecondary, fontSize: 12, height: 1.4),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
