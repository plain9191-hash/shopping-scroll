import 'package:flutter/material.dart';

class CategorySelector extends StatelessWidget {
  final Map<String, String> categories;
  final String selectedCategoryId;
  final Function(String) onCategorySelected;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Theme.of(context).appBarTheme.backgroundColor,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final categoryName = categories.keys.elementAt(index);
          final categoryId = categories.values.elementAt(index);
          final isSelected = selectedCategoryId == categoryId;

          return ChoiceChip(
            label: Text(categoryName),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                onCategorySelected(categoryId);
              }
            },
            selectedColor: Colors.orange,
            labelStyle: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: const StadiumBorder(),
            side: BorderSide(
              color: isSelected ? Colors.orange : Colors.grey[300]!,
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
      ),
    );
  }
}
