import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/data/repositories/contact_repository.dart';
import 'package:pichat/features/chat/application/main_controller.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _searchController = TextEditingController();

  bool _isCreating = false;
  bool _showNewContactForm = false;
  String? _errorMessage;
  List<Contact> _searchResults = [];

  @override
  void initState() {
    super.initState();
    // Pre-populate search with all cached contacts
    _runSearch('');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    final repo = ref.read(contactRepositoryProvider);
    final results = await repo.searchContacts(query);
    if (mounted) {
      setState(() => _searchResults = results);
    }
  }

  void _openThread(Contact contact) {
    context.pop();
    context.push('/home/chats/detail', extra: contact);
  }

  Future<void> _createAndOpenChat() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'new_chat.error.phone_required'.tr());
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(contactRepositoryProvider);
      final contact = await repo.createContact(
        phone: phone,
        firstName: _firstNameController.text.trim().isNotEmpty
            ? _firstNameController.text.trim()
            : null,
        lastName: _lastNameController.text.trim().isNotEmpty
            ? _lastNameController.text.trim()
            : null,
      );

      // Add to contacts list if not present
      ref.read(mainDataProvider.notifier).addOrUpdateContact(contact);

      if (mounted) {
        _openThread(contact);
      }
    } on Exception catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('new_chat.title'.tr(), style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() {
              _showNewContactForm = !_showNewContactForm;
              _errorMessage = null;
            }),
            icon: Icon(
              _showNewContactForm ? Icons.search : Icons.person_add,
              color: Colors.white,
            ),
            label: Text(
              _showNewContactForm ? 'new_chat.action.search'.tr() : 'new_chat.action.new_contact'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _showNewContactForm ? _buildNewContactForm() : _buildSearchPane(),
    );
  }

  Widget _buildSearchPane() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'new_chat.search.hint'.tr(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        _runSearch('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: PiColors.of(context).surface,
            ),
            onChanged: _runSearch,
          ),
        ),
        if (_searchResults.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_search, size: 64, color: PiColors.of(context).ink400),
                  const SizedBox(height: 12),
                  Text(
                    'new_chat.empty.no_contacts'.tr(),
                    style: TextStyle(color: PiColors.of(context).textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _showNewContactForm = true),
                    icon: const Icon(Icons.person_add),
                    label: Text('new_chat.empty.create_contact'.tr()),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final contact = _searchResults[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    backgroundImage: contact.avatar != null
                        ? NetworkImage(contact.avatar!)
                        : null,
                    child: contact.avatar == null
                        ? Text(
                            _initials(contact.fullName ?? contact.phone),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    contact.fullName ?? contact.phone,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(contact.formattedPhone),
                  onTap: () => _openThread(contact),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildNewContactForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'new_chat.form.subtitle'.tr(),
            style: TextStyle(color: PiColors.of(context).textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Phone
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'new_chat.form.phone_label'.tr(),
              hintText: 'new_chat.form.phone_hint'.tr(),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),

          // First name
          TextField(
            controller: _firstNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'new_chat.form.first_name_label'.tr(),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),

          // Last name
          TextField(
            controller: _lastNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'new_chat.form.last_name_label'.tr(),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[700], fontSize: 13),
              ),
            ),
          ],

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isCreating ? null : _createAndOpenChat,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isCreating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('new_chat.form.start_chat_button'.tr(), style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
