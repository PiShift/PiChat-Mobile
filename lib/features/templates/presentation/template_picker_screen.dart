import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/repositories/template_repository.dart';

/// Screen for picking a template to send (used when 24h window is expired)
class TemplatePickerScreen extends ConsumerStatefulWidget {
  final String contactUuid;
  final String contactName;
  final VoidCallback? onTemplateSent;

  const TemplatePickerScreen({
    super.key,
    required this.contactUuid,
    required this.contactName,
    this.onTemplateSent,
  });

  @override
  ConsumerState<TemplatePickerScreen> createState() => _TemplatePickerScreenState();
}

class _TemplatePickerScreenState extends ConsumerState<TemplatePickerScreen> {
  Template? _selectedTemplate;
  final Map<String, TextEditingController> _variableControllers = {};
  bool _isSending = false;
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void dispose() {
    for (final controller in _variableControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templatesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('templates.title'.tr(), style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.orange.shade50,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '24-hour window expired. You can only send approved templates to ${widget.contactName}.',
                    style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'templates.search.hint'.tr(),
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Category filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _CategoryChip(
                  label: 'templates.category.all'.tr(),
                  isSelected: _selectedCategory == null,
                  onTap: () => setState(() => _selectedCategory = null),
                ),
                _CategoryChip(
                  label: 'templates.category.marketing'.tr(),
                  isSelected: _selectedCategory == 'MARKETING',
                  onTap: () => setState(() => _selectedCategory = 'MARKETING'),
                ),
                _CategoryChip(
                  label: 'templates.category.utility'.tr(),
                  isSelected: _selectedCategory == 'UTILITY',
                  onTap: () => setState(() => _selectedCategory = 'UTILITY'),
                ),
                _CategoryChip(
                  label: 'templates.category.authentication'.tr(),
                  isSelected: _selectedCategory == 'AUTHENTICATION',
                  onTap: () => setState(() => _selectedCategory = 'AUTHENTICATION'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Template list
          Expanded(
            child: templatesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                    const SizedBox(height: 12),
                    Text('templates.error.load_failed'.tr(), style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(templatesProvider),
                      child: Text('common.retry'.tr()),
                    ),
                  ],
                ),
              ),
              data: (templates) {
                var filtered = templates;

                // Filter by category
                if (_selectedCategory != null) {
                  filtered = filtered.where((t) => t.category == _selectedCategory).toList();
                }

                // Filter by search
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  filtered = filtered.where((t) =>
                      t.name.toLowerCase().contains(query) ||
                      t.preview.toLowerCase().contains(query)).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined, color: Colors.grey[400], size: 48),
                        const SizedBox(height: 12),
                        Text('templates.empty.no_templates'.tr(), style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final template = filtered[index];
                    final isSelected = _selectedTemplate?.id == template.id;

                    return _TemplateCard(
                      template: template,
                      isSelected: isSelected,
                      onTap: () => _openSendSheet(template),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _setupVariableControllers(Template template) {
    _variableControllers.clear();
    for (final variable in template.variables) {
      final key = '${variable.component}_${variable.index}';
      _variableControllers[key] = TextEditingController();
    }
  }

  void _openSendSheet(Template template) {
    _setupVariableControllers(template);
    setState(() => _selectedTemplate = template);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SendSheet(
        template: template,
        contactName: widget.contactName,
        controllers: _variableControllers,
        isSending: _isSending,
        onSend: (PlatformFile? mediaFile) async {
          await _sendTemplate(mediaFile: mediaFile);
        },
      ),
    );
  }

  Future<void> _sendTemplate({PlatformFile? mediaFile}) async {
    if (_selectedTemplate == null) return;

    setState(() => _isSending = true);

    try {
      // Collect body values in order
      final bodyVars = _selectedTemplate!.bodyVariables;
      final bodyValues = bodyVars.map((v) {
        final key = '${v.component}_${v.index}';
        return _variableControllers[key]?.text ?? '';
      }).toList();

      // Collect header text values in order (only for TEXT headers)
      final headerVars = _selectedTemplate!.headerVariables;
      final headerValues = headerVars.map((v) {
        final key = '${v.component}_${v.index}';
        return _variableControllers[key]?.text ?? '';
      }).toList();

      final repo = ref.read(templateRepositoryProvider);
      await repo.sendTemplate(
        widget.contactUuid,
        _selectedTemplate!.id,
        bodyValues: bodyValues.isEmpty ? null : bodyValues,
        headerValues: headerValues.isEmpty ? null : headerValues,
        mediaFile: mediaFile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('templates.snackbar.sent_successfully'.tr()), backgroundColor: Colors.green),
        );
        widget.onTemplateSent?.call();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('templates.snackbar.failed_to_send'.tr(namedArgs: {'error': e.toString()})), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

// ── Modal sheet shown when a template is tapped ──────────────────────────────
class _SendSheet extends StatefulWidget {
  final Template template;
  final String contactName;
  final Map<String, TextEditingController> controllers;
  final bool isSending;
  final Future<void> Function(PlatformFile? mediaFile) onSend;

  const _SendSheet({
    required this.template,
    required this.contactName,
    required this.controllers,
    required this.isSending,
    required this.onSend,
  });

  @override
  State<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<_SendSheet> {
  bool _sending = false;
  PlatformFile? _pickedMedia;

  bool get _isRtl => ['ar', 'he', 'fa', 'ur']
      .contains(widget.template.language.toLowerCase().split('_').first);

  String _humanLabel(TemplateVariable v) {
    final ph = v.placeholder;
    // Guard: if backend returns {{1}} style placeholder, treat as empty
    if (ph.isEmpty || RegExp(r'^\{\{\d+\}\}$').hasMatch(ph)) {
      final section = v.component == 'body' ? 'Message' : 'Header';
      return '$section field ${v.index}';
    }
    return ph;
  }

  String _hintFor(TemplateVariable v) {
    final ph = v.placeholder.toLowerCase();
    if (ph.contains('name') || ph.contains('passenger')) return 'e.g. Ahmed Al-Rashid';
    if (ph.contains('date')) return 'e.g. April 28, 2026';
    if (ph.contains('time') || ph.contains('embarq') || ph.contains('depart') || ph.contains('decol')) return 'e.g. 14:30';
    if (ph.contains('destination') || ph.contains('city')) return 'e.g. Dubai';
    if (ph.contains('order') || ph.contains('number') || ph.contains('invoice') || ph.contains('payment')) return 'e.g. #12345';
    if (ph.contains('amount') || ph.contains('price') || ph.contains('total')) return 'e.g. 500.00 SAR';
    if (ph.contains('code') || ph.contains('otp')) return 'e.g. 123456';
    return 'Enter value…';
  }

  Future<void> _pickMedia(String format) async {
    FileType fileType;
    List<String>? allowedExtensions;

    switch (format) {
      case 'IMAGE':
        fileType = FileType.image;
      case 'VIDEO':
        fileType = FileType.video;
      case 'DOCUMENT':
        fileType = FileType.custom;
        allowedExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'];
      default:
        fileType = FileType.any;
    }

    final result = await FilePicker.platform.pickFiles(
      type: fileType,
      allowedExtensions: allowedExtensions,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedMedia = result.files.first);
    }
  }

  Widget _buildHeaderInfo() {
    final fmt = widget.template.headerFormat;
    if (fmt == null || fmt == 'TEXT') return const SizedBox.shrink();

    final (icon, label, color) = switch (fmt) {
      'IMAGE'    => (Icons.image_outlined,       'Image',    Colors.blue),
      'VIDEO'    => (Icons.videocam_outlined,    'Video',    Colors.purple),
      'DOCUMENT' => (Icons.description_outlined, 'Document', Colors.orange),
      _          => (Icons.attach_file,          'File',     Colors.grey),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: '$label attachment'),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _pickMedia(fmt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _pickedMedia != null ? color : color.withValues(alpha: 0.25),
                width: _pickedMedia != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: _pickedMedia != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pickedMedia!.name,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_pickedMedia!.size > 0)
                              Text(
                                _formatFileSize(_pickedMedia!.size),
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                          ],
                        )
                      : Text(
                          'Tap to pick $label',
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        ),
                ),
                Icon(
                  _pickedMedia != null ? Icons.check_circle : Icons.upload_file,
                  color: _pickedMedia != null ? Colors.green : Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildPreview() {
    return AnimatedBuilder(
      animation: Listenable.merge([...widget.controllers.values]),
      builder: (context, _) {
        var text = widget.template.preview;
        for (final v in widget.template.variables) {
          final key = '${v.component}_${v.index}';
          final val = widget.controllers[key]?.text ?? '';
          final display = val.isNotEmpty ? val : '_____';
          text = text.replaceAll('{{${v.index}}}', display);
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFECF8E8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFB6DFA8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 13, color: Colors.green.shade700),
                  const SizedBox(width: 5),
                  Text('templates.preview.label'.tr(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                text,
                style: const TextStyle(fontSize: 14, height: 1.4),
                textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final bodyVars = template.bodyVariables..sort((a, b) => a.index.compareTo(b.index));
    final headerVars = template.headerVariables..sort((a, b) => a.index.compareTo(b.index));
    final hasFields = template.hasVariables || (template.headerFormat != null && template.headerFormat != 'TEXT');

    return DraggableScrollableSheet(
      initialChildSize: hasFields ? 0.80 : 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            // Title row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      template.name
                          .replaceAll('_', ' ')
                          .split(' ')
                          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
                          .join(' '),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      template.language.toUpperCase(),
                      style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'for ${widget.contactName}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
            ),
            const Divider(height: 24),
            // Scrollable body
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildHeaderInfo(),
                  // No fields needed
                  if (!hasFields) ...[  
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 18),
                          const SizedBox(width: 8),
                          Text('templates.info.no_fields'.tr(), style: TextStyle(color: Colors.green.shade700, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  // Header variables (text placeholders in TEXT-format headers)
                  if (headerVars.isNotEmpty) ...[
                    _SectionLabel(label: 'templates.section.header_fields'.tr()),
                    const SizedBox(height: 10),
                    ...headerVars.map((v) => _VariableField(variable: v, controller: widget.controllers['${v.component}_${v.index}']!, label: _humanLabel(v), hint: _hintFor(v))),
                    const SizedBox(height: 16),
                  ],
                  // Body variables
                  if (bodyVars.isNotEmpty) ...[
                    _SectionLabel(label: 'templates.section.message_fields'.tr()),
                    const SizedBox(height: 10),
                    ...bodyVars.map((v) => _VariableField(variable: v, controller: widget.controllers['${v.component}_${v.index}']!, label: _humanLabel(v), hint: _hintFor(v))),
                    const SizedBox(height: 16),
                  ],
                  // Preview (always shown)
                  _buildPreview(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // Send button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _sending
                        ? null
                        : () async {
                            setState(() => _sending = true);
                            await widget.onSend(_pickedMedia);
                            if (mounted) setState(() => _sending = false);
                          },
                    child: _sending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('templates.send_button'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54, letterSpacing: 0.3));
  }
}

class _VariableField extends StatelessWidget {
  final TemplateVariable variable;
  final TextEditingController controller;
  final String label;
  final String hint;

  const _VariableField({required this.variable, required this.controller, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

// ── Category chip ─────────────────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        checkmarkColor: AppColors.primary,
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final Template template;
  final bool isSelected;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.onTap,
  });

  String get _displayName {
    return template.name
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final headerFormat = template.headerFormat;
    final hasMedia = headerFormat != null && headerFormat != 'TEXT';
    final bodyVars = template.bodyVariables..sort((a, b) => a.index.compareTo(b.index));
    final hasAnything = template.hasVariables || hasMedia;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isSelected ? 3 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: name + category badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(template.category).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      template.category,
                      style: TextStyle(
                        fontSize: 10,
                        color: _getCategoryColor(template.category),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Preview text
              Text(
                template.preview,
                style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.35),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: _isRtlLanguage(template.language) ? TextDirection.rtl : TextDirection.ltr,
              ),
              if (hasAnything) ...[  
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Media attachment badge
                    if (hasMedia)
                      _InfoChip(
                        icon: switch (headerFormat) {
                          'IMAGE'    => Icons.image_outlined,
                          'VIDEO'    => Icons.videocam_outlined,
                          'DOCUMENT' => Icons.description_outlined,
                          _          => Icons.attach_file,
                        },
                        label: switch (headerFormat) {
                          'IMAGE'    => 'templates.attachment.image'.tr(),
                          'VIDEO'    => 'templates.attachment.video'.tr(),
                          'DOCUMENT' => 'templates.attachment.document_attachment'.tr(),
                          _          => 'templates.attachment.file'.tr(),
                        },
                        color: Colors.orange,
                      ),
                    // Variable name chips
                    ...bodyVars.map((v) {
                      final label = v.placeholder.isNotEmpty &&
                              !RegExp(r'^\{\{\d+\}\}$').hasMatch(v.placeholder)
                          ? v.placeholder
                          : 'templates.variable.message_field'.tr(namedArgs: {'index': v.index.toString()});
                      return _InfoChip(
                        icon: Icons.edit_outlined,
                        label: label,
                        color: AppColors.primary,
                      );
                    }),
                  ],
                ),
              ] else ...[  
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 13, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text('templates.ready_to_send'.tr(), style: TextStyle(fontSize: 11, color: Colors.green[600], fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isRtlLanguage(String language) {
    return ['ar', 'he', 'fa', 'ur'].contains(language.toLowerCase().split('_').first);
  }

  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'MARKETING':
        return Colors.purple;
      case 'UTILITY':
        return Colors.blue;
      case 'AUTHENTICATION':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}