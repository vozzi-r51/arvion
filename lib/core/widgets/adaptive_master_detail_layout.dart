import 'package:flutter/material.dart';

/// Responsive split-pane layout for Tablets, Foldables & Desktops (>= 600px).
/// Renders side-by-side List + Detail view on large screens,
/// and standard single-screen navigation stack on Mobile phones (< 600px).
class AdaptiveMasterDetailLayout<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, bool isSelected)
      masterItemBuilder;
  final Widget Function(BuildContext context, T item) detailBuilder;
  final Widget emptyDetailWidget;
  final Widget emptyMasterWidget;
  final String title;
  final double masterWidth;

  const AdaptiveMasterDetailLayout({
    super.key,
    required this.items,
    required this.masterItemBuilder,
    required this.detailBuilder,
    this.emptyDetailWidget = const Center(
      child: Text('Select an item from the list to view details',
          style: TextStyle(color: Colors.grey)),
    ),
    this.emptyMasterWidget = const Center(child: Text('No items found')),
    required this.title,
    this.masterWidth = 350.0,
  });

  @override
  State<AdaptiveMasterDetailLayout<T>> createState() =>
      _AdaptiveMasterDetailLayoutState<T>();
}

class _AdaptiveMasterDetailLayoutState<T>
    extends State<AdaptiveMasterDetailLayout<T>> {
  T? _selectedItem;

  @override
  void initState() {
    super.initState();
    if (widget.items.isNotEmpty) {
      _selectedItem = widget.items.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTabletOrDesktop = width >= 600;

    if (!isTabletOrDesktop) {
      // Mobile Single-Pane Layout
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: widget.items.isEmpty
            ? widget.emptyMasterWidget
            : ListView.builder(
                itemCount: widget.items.length,
                itemBuilder: (ctx, i) {
                  final item = widget.items[i];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('Detail')),
                            body: widget.detailBuilder(context, item),
                          ),
                        ),
                      );
                    },
                    child: widget.masterItemBuilder(context, item, false),
                  );
                },
              ),
      );
    }

    // Tablet / Foldable Side-by-Side Two-Pane Layout
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Row(
        children: [
          // Left Master Pane
          SizedBox(
            width: widget.masterWidth,
            child: Card(
              margin: const EdgeInsets.all(8),
              child: widget.items.isEmpty
                  ? widget.emptyMasterWidget
                  : ListView.builder(
                      itemCount: widget.items.length,
                      itemBuilder: (ctx, i) {
                        final item = widget.items[i];
                        final isSelected = _selectedItem == item;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedItem = item),
                          child: widget.masterItemBuilder(
                              context, item, isSelected),
                        );
                      },
                    ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // Right Detail Pane
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _selectedItem == null
                  ? widget.emptyDetailWidget
                  : widget.detailBuilder(context, _selectedItem as T),
            ),
          ),
        ],
      ),
    );
  }
}
