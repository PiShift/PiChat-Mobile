import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/router/app_router.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/models/organization_model.dart';
import 'package:pichat/data/repositories/auth_repository.dart';
import 'package:pichat/features/chat/application/main_controller.dart';
import 'package:pichat/features/chat/widgets/contactItem.dart';
import 'package:pichat/shared/base/BaseButton.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  bool showOrgSwitcher = false;

  void toggleOrgSwitcher() {
    setState(() {
      showOrgSwitcher = !showOrgSwitcher;
    });
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(organizationProvider);
    final userOrgsAsync = ref.watch(userOrgsProvider);
    final contacts = ref.watch(mainDataProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
            org?.name ?? 'Chats', style: const TextStyle(color: Colors.white)
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.arrow_2_circlepath, color: Colors.white),
            onPressed: toggleOrgSwitcher
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main chat content
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  SizedBox(height: 12),
                  // first row with 3 childs, small search bar, filter button, new chat button
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search...'.tr(),
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              isDense: true,
                              contentPadding: const EdgeInsets.all(2.0)
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: BaseButton(
                          text: 'Filter'.tr(),
                          prefixIcon: Icon(Icons.filter_alt_outlined, color: AppColors.textDark,),
                          type: 'outline',
                          height: 40.0,
                          borcolor: AppColors.greyBorder,
                          textColor: AppColors.textDark,
                          onTap: () {},
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: BaseButton(
                          text: 'Chat'.tr(),
                          prefixIcon: Icon(Icons.add, color: AppColors.textDark,),
                          type: 'outline',
                          height: 40.0,
                          borcolor: AppColors.greyBorder,
                          textColor: AppColors.textDark,
                          onTap: () {},
                        ),
                      )
                    ],
                  ),
                  SizedBox(height: 12),
                  // Placeholder for chat list
                  Container(
                    height: 600,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: contacts.isEmpty ? const Center(
                      child: CircularProgressIndicator()
                    ) : RefreshIndicator(
                      onRefresh: () async {
                        await ref.read(mainDataProvider.notifier).refreshContacts();
                      },
                      child: ListView.builder(
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          return ContactItem(contact: contact);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sliding org switcher
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            top: showOrgSwitcher ? 0 : -200, // slide from top
            left: 0,
            right: 0,
            height: 200, // height of switcher panel
            child: Material(
              elevation: 1,
              color: AppColors.primary,
              child: userOrgsAsync.when(
                data: (orgs) => ListView.builder(
                  itemCount: orgs.length,
                  itemBuilder: (context, index) {
                    final o = orgs[index];
                    final selected = org?.id == o.id;
                    return ListTile(
                      selectedColor: Colors.white,
                      selected: selected,
                      enabled: !selected,
                      title: Text(
                          o.name,
                          style: TextStyle(
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              color: selected ? Colors.black : Colors.white
                          )
                      ),
                      trailing: selected
                          ? const Icon(Icons.check, color: Colors.black)
                          : null,
                      onTap: o.id == org!.id ? null : () async {
                        // set selected org
                        ref.read(authRepositoryProvider).selectOrganization(o);
                        setState(() => showOrgSwitcher = false);
                      },
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
