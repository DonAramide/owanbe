import 'package:flutter/material.dart';

void showSearchableSelector({
  required BuildContext context,
  required String title,
  required List<String> options,
  required ValueChanged<String> onSelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return _SearchableListModal(
            title: title,
            options: options,
            onSelected: onSelected,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _SearchableListModal extends StatefulWidget {
  const _SearchableListModal({
    required this.title,
    required this.options,
    required this.onSelected,
    required this.scrollController,
  });

  final String title;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final ScrollController scrollController;

  @override
  State<_SearchableListModal> createState() => _SearchableListModalState();
}

class _SearchableListModalState extends State<_SearchableListModal> {
  final _searchController = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.options;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = widget.options
          .where((opt) => opt.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final item = _filtered[index];
                return ListTile(
                  title: Text(item),
                  onTap: () {
                    widget.onSelected(item);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
