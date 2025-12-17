import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateSelector extends StatelessWidget {
  final List<DateTime> dates;
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;

  const DateSelector({
    super.key,
    required this.dates,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Theme.of(context).scaffoldBackgroundColor, // Use scaffold background
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = selectedDate != null &&
              date.year == selectedDate!.year &&
              date.month == selectedDate!.month &&
              date.day == selectedDate!.day;

          final today = DateTime.now();
          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;
          
          String dateText = isToday ? '오늘' : DateFormat('MM/dd').format(date);

          return ChoiceChip(
            label: Text(dateText),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                onDateSelected(date);
              }
            },
            selectedColor: Colors.blue, // A different color to distinguish
            labelStyle: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            backgroundColor: Colors.white,
            shape: const StadiumBorder(),
            side: BorderSide(
              color: isSelected ? Colors.blue : Colors.grey[300]!,
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
      ),
    );
  }
}
