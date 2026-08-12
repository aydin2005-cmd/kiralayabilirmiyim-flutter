import 'package:flutter/material.dart';

import 'flow_widgets.dart';

class SearchableSelectField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final String searchHint;

  const SearchableSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.searchHint = 'Ara',
  });

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _SearchableSelectSheet(
        title: label,
        items: items,
        selectedValue: value,
        searchHint: searchHint,
      ),
    );

    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: enabled ? () => _openPicker(context) : null,
      child: InputDecorator(
        isEmpty: value == null || value!.isEmpty,
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          suffixIcon: Icon(
            Icons.search_rounded,
            color: enabled ? FlowColors.navy : FlowColors.muted,
          ),
        ),
        child: Text(
          value ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: enabled ? FlowColors.navyDark : FlowColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SearchableSelectSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selectedValue;
  final String searchHint;

  const _SearchableSelectSheet({
    required this.title,
    required this.items,
    required this.selectedValue,
    required this.searchHint,
  });

  @override
  State<_SearchableSelectSheet> createState() => _SearchableSelectSheetState();
}

class _SearchableSelectSheetState extends State<_SearchableSelectSheet> {
  final searchController = TextEditingController();
  String query = '';

  String _normalize(String value) {
    return value
        .trim()
        .replaceAll('İ', 'I')
        .replaceAll('ı', 'I')
        .replaceAll('Ğ', 'G')
        .replaceAll('ğ', 'G')
        .replaceAll('Ü', 'U')
        .replaceAll('ü', 'U')
        .replaceAll('Ş', 'S')
        .replaceAll('ş', 'S')
        .replaceAll('Ö', 'O')
        .replaceAll('ö', 'O')
        .replaceAll('Ç', 'C')
        .replaceAll('ç', 'C')
        .toUpperCase();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _normalize(query);
    final filtered = normalizedQuery.isEmpty
        ? widget.items
        : widget.items
            .where((item) => _normalize(item).contains(normalizedQuery))
            .toList();

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: FlowColors.navyDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          setState(() => query = '');
                        },
                        icon: const Icon(Icons.clear_rounded),
                      ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Eşleşen sonuç bulunamadı.',
                      style: TextStyle(
                        color: FlowColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final selected = item == widget.selectedValue;
                      return ListTile(
                        title: Text(
                          item,
                          style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w900 : FontWeight.w700,
                            color: FlowColors.navyDark,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: FlowColors.green,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
