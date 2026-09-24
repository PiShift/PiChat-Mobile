import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/data/repositories/contact_repository.dart';
import 'package:pichat/features/chat/application/main_controller.dart';
import 'package:pichat/features/chat/widgets/file_type_badge.dart';
import 'package:pichat/features/share/share_intent_service.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Where a share goes once a contact is picked: that contact's thread, which
/// then walks the agent through the usual preview-and-caption step.
class ShareToThread {
  const ShareToThread({required this.contact, required this.payload});

  final Contact contact;
  final SharedPayload payload;
}

/// The "Send to…" screen opened by sharing into PiChat from another app.
///
/// Recent conversations first, a search over name and number, and — when
/// the search is a number nobody has yet — a way to start with it.
class ShareTargetScreen extends ConsumerStatefulWidget {
  const ShareTargetScreen({super.key});

  @override
  ConsumerState<ShareTargetScreen> createState() => _ShareTargetScreenState();
}

class _ShareTargetScreenState extends ConsumerState<ShareTargetScreen> {
  final _search = TextEditingController();

  /// Taken from the pending slot on open, so the same share is not offered
  /// a second time once this screen is gone.
  SharedPayload? _payload;
  List<Contact> _results = const [];
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _payload = ref.read(pendingShareProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pendingShareProvider.notifier).state = null;
    });
    _runSearch('');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    final found = await ref
        .read(contactRepositoryProvider)
        .searchContacts(query.trim());

    found.sort((a, b) {
      final at = a.latestChatCreatedAt;
      final bt = b.latestChatCreatedAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });

    if (mounted) setState(() => _results = found);
  }

  /// The search, read as a phone number, when it looks like one.
  String? get _typedNumber {
    final digits = _search.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 6) return null;

    final known = _results.any(
        (c) => c.phone.replaceAll(RegExp(r'[^0-9]'), '') == digits);

    return known ? null : digits;
  }

  void _sendTo(Contact contact) {
    final payload = _payload;
    if (payload == null) return;

    context.pushReplacement(
      '/home/chats/detail',
      extra: ShareToThread(contact: contact, payload: payload),
    );
  }

  Future<void> _sendToNumber(String digits) async {
    setState(() => _creating = true);

    try {
      final contact = await ref
          .read(contactRepositoryProvider)
          .createContact(phone: digits);
      ref.read(mainDataProvider.notifier).addOrUpdateContact(contact);
      if (mounted) _sendTo(contact);
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);
    final payload = _payload;
    final number = _typedNumber;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'share.title'.tr(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: payload == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                _SharedSummary(payload: payload),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: TextField(
                    controller: _search,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      hintText: 'share.search_hint'.tr(),
                      prefixIcon: const Icon(LucideIcons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colors.surface,
                      isDense: true,
                    ),
                    onChanged: (q) {
                      setState(() {});
                      _runSearch(q);
                    },
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      if (number != null)
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                colors.primary500.withValues(alpha: 0.15),
                            child: _creating
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.primary500,
                                    ),
                                  )
                                : Icon(LucideIcons.userPlus,
                                    size: 20, color: colors.primary500),
                          ),
                          title: Text(
                            'share.new_number'
                                .tr(namedArgs: {'number': '+$number'}),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: _creating ? null : () => _sendToNumber(number),
                        ),
                      if (_search.text.isEmpty && _results.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text(
                            'share.recent'.tr(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      for (final contact in _results)
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                colors.primary500.withValues(alpha: 0.15),
                            backgroundImage: contact.avatar != null
                                ? NetworkImage(contact.avatar!)
                                : null,
                            child: contact.avatar == null
                                ? Icon(LucideIcons.user,
                                    size: 20, color: colors.primary500)
                                : null,
                          ),
                          title: Text(
                            (contact.fullName?.trim().isNotEmpty ?? false)
                                ? contact.fullName!.trim()
                                : contact.formattedPhone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(contact.formattedPhone),
                          onTap: () => _sendTo(contact),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// A strip saying what is being shared: the first image, or the file type.
class _SharedSummary extends StatelessWidget {
  const _SharedSummary({required this.payload});

  final SharedPayload payload;

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);
    final first = payload.files.isEmpty ? null : payload.files.first;
    final name = first?.path.split('/').last;
    final ext = name != null && name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';

    final label = first == null
        ? (payload.text ?? '')
        : payload.files.length == 1
            ? name!
            : 'share.files_count'
                .tr(namedArgs: {'count': '${payload.files.length}'});

    Widget leading;
    if (first != null && first.type == SharedMediaType.image) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(first.path),
            width: 44, height: 44, fit: BoxFit.cover),
      );
    } else if (first != null && first.type == SharedMediaType.video) {
      leading = Icon(LucideIcons.video, size: 32, color: colors.textSecondary);
    } else if (first != null) {
      leading = FileTypeBadge(extension: ext, size: 40);
    } else {
      leading = Icon(LucideIcons.messageSquareText,
          size: 32, color: colors.textSecondary);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(width: 44, height: 44, child: Center(child: leading)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
