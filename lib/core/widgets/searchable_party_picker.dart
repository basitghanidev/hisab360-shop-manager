import 'package:flutter/material.dart';

class PartyPickerItem {
  final int id;
  final String name;
  final String? subtitle; // e.g. phone number or balance
  const PartyPickerItem({required this.id, required this.name, this.subtitle});
}

/// Shows a searchable bottom sheet for picking any party (supplier, wholesaler,
/// or customer). Returns the selected id, or null if cancelled.
Future<int?> showPartyPicker(
  BuildContext context, {
  required String title,
  required List<PartyPickerItem> items,
}) async {
  return await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PartyPickerSheet(title: title, items: items),
  );
}

class _PartyPickerSheet extends StatefulWidget {
  final String title;
  final List<PartyPickerItem> items;
  const _PartyPickerSheet({required this.title, required this.items});

  @override
  State<_PartyPickerSheet> createState() => _PartyPickerSheetState();
}

class _PartyPickerSheetState extends State<_PartyPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.items
        : widget.items.where((i) => i.name.toLowerCase().contains(_query.toLowerCase())).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No matches found'))
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => ListTile(
                        title: Text(filtered[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: filtered[i].subtitle != null ? Text(filtered[i].subtitle!) : null,
                        onTap: () => Navigator.pop(context, filtered[i].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
