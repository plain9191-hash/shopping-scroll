import 'package:flutter/material.dart';

class CategorySelector extends StatefulWidget {
  final Map<String, Map<String, String>> categories;
  final String selectedCategoryKey;
  final Function(String) onCategorySelected;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategoryKey,
    required this.onCategorySelected,
  });

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  final ScrollController _scrollController = ScrollController();
  late List<GlobalKey> _tabKeys;

  @override
  void initState() {
    super.initState();
    _tabKeys =
        List.generate(widget.categories.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CategorySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categories.length != oldWidget.categories.length) {
      _tabKeys =
          List.generate(widget.categories.length, (_) => GlobalKey());
    }
    // Scroll to the selected tab when the widget updates
    _scrollToSelected();
  }

  void _onCategoryTap(int index) {
    final categoryData = widget.categories.values.elementAt(index);
    final categoryKey = categoryData['key'] ?? 'all';
    widget.onCategorySelected(categoryKey);

    // The parent widget will rebuild this widget with the new selectedCategoryKey,
    // and didUpdateWidget will trigger the scroll.
  }

  void _scrollToSelected() {
    if (!mounted) return;

    final selectedIndex = widget.categories.values.toList().indexWhere(
      (data) => data['key'] == widget.selectedCategoryKey,
    );
    if (selectedIndex != -1 && selectedIndex < _tabKeys.length) {
      final key = _tabKeys[selectedIndex];
      final keyContext = key.currentContext;
      if (keyContext != null && mounted) {
        // Ensure the tab is visible and centered after the frame is rendered
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (key.currentContext != null) {
            Scrollable.ensureVisible(
              key.currentContext!,
              duration: const Duration(milliseconds: 300),
              alignment: 0.5, // Center align
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final categoryName = widget.categories.keys.elementAt(index);
          final categoryData = widget.categories.values.elementAt(index);
          final categoryKey = categoryData['key'] ?? 'all';
          final isSelected = widget.selectedCategoryKey == categoryKey;

          return GestureDetector(
            key: _tabKeys[index],
            onTap: () => _onCategoryTap(index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: isSelected ? const Color(0xFF607B8F) : Colors.transparent,
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  )
                ] : null,
              ),
              alignment: Alignment.center,
              child: Text(
                categoryName,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
