import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:pichat/core/theme/app_colors.dart';

/// A single contact card the user picked to share. Includes name + the
/// phone numbers selected (Meta accepts multiple `phones[]` per card).
class SharedContactCard {
  final String displayName;
  final String? firstName;
  final String? lastName;
  final List<SharedContactPhone> phones;
  const SharedContactCard({
    required this.displayName,
    this.firstName,
    this.lastName,
    required this.phones,
  });
}

class SharedContactPhone {
  final String phone;
  final String type; // CELL / HOME / WORK
  const SharedContactPhone({required this.phone, this.type = 'CELL'});
}

/// WhatsApp-style sheet that lists every contact from the device address
/// book and lets the user pick one to share. Returns `null` if dismissed.
Future<SharedContactCard?> showShareContactSheet(BuildContext context) {
  return showModalBottomSheet<SharedContactCard>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ShareContactSheet(),
  );
}

class _ShareContactSheet extends StatefulWidget {
  const _ShareContactSheet();

  @override
  State<_ShareContactSheet> createState() => _ShareContactSheetState();
}

class _ShareContactSheetState extends State<_ShareContactSheet> {
  List<fc.Contact>? _contacts;
  String? _error;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final granted = await fc.FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        setState(() {
          _loading = false;
          _error = 'Contacts permission denied.';
        });
        return;
      }
      final list = await fc.FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
        sorted: true,
      );
      // Drop entries with no phone numbers — they can't be shared.
      final usable = list.where((c) => c.phones.isNotEmpty).toList();
      if (!mounted) return;
      setState(() {
        _contacts = usable;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not read contacts: $e';
        _loading = false;
      });
    }
  }

  String _initial(fc.Contact c) {
    final n = c.displayName.trim();
    return n.isEmpty ? '?' : n[0].toUpperCase();
  }

  String _phoneTypeLabel(fc.Phone p) {
    switch (p.label) {
      case fc.PhoneLabel.mobile:
        return 'CELL';
      case fc.PhoneLabel.home:
        return 'HOME';
      case fc.PhoneLabel.work:
        return 'WORK';
      default:
        return 'CELL';
    }
  }

  Future<void> _pick(fc.Contact c) async {
    // If multiple numbers, ask which to share. Single number → ship it.
    SharedContactPhone? chosen;
    if (c.phones.length == 1) {
      chosen = SharedContactPhone(
        phone: c.phones.first.number,
        type: _phoneTypeLabel(c.phones.first),
      );
    } else {
      chosen = await showModalBottomSheet<SharedContactPhone>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Choose a number',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              for (final p in c.phones)
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(p.number),
                  subtitle: Text(_phoneTypeLabel(p)),
                  onTap: () => Navigator.of(context).pop(
                    SharedContactPhone(
                      phone: p.number,
                      type: _phoneTypeLabel(p),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    if (chosen == null) return;
    if (!mounted) return;
    Navigator.of(context).pop(
      SharedContactCard(
        displayName: c.displayName,
        firstName: c.name.first.isEmpty ? null : c.name.first,
        lastName: c.name.last.isEmpty ? null : c.name.last,
        phones: [chosen],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: PiColors.of(context).surfaceRaised,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: PiColors.of(context).divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.person_rounded,
                        color: Color(0xFF34A853)),
                    const SizedBox(width: 8),
                    Text(
                      'Share contact',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              if (!_loading && _error == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search contacts',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) =>
                        setState(() => _query = v.toLowerCase()),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController controller) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final all = _contacts ?? const <fc.Contact>[];
    final filtered = _query.isEmpty
        ? all
        : all.where((c) {
            final hay =
                '${c.displayName} ${c.phones.map((p) => p.number).join(' ')}'
                    .toLowerCase();
            return hay.contains(_query);
          }).toList();
    if (filtered.isEmpty) {
      return const Center(child: Text('No contacts'));
    }
    return ListView.builder(
      controller: controller,
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final c = filtered[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFE7F4EE),
            child: Text(
              _initial(c),
              style: const TextStyle(
                  color: Color(0xFF34A853), fontWeight: FontWeight.w600),
            ),
          ),
          title: Text(c.displayName.isEmpty ? '(no name)' : c.displayName),
          subtitle: Text(
            c.phones.first.number +
                (c.phones.length > 1 ? '  +${c.phones.length - 1}' : ''),
          ),
          onTap: () => _pick(c),
        );
      },
    );
  }
}
