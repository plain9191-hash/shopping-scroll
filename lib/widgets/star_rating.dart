import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final Color color;
  final Color unratedColor;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 16.0,
    this.color = Colors.amber,
    this.unratedColor = const Color(0xFFE0E0E0), // 밝은 회색
  });

  @override
  Widget build(BuildContext context) {
    print('⭐ [StarRating] 별점 값: $rating');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        // index는 0부터 4까지.
        // 꽉 찬 별: rating이 (index + 1)보다 크거나 같을 때 (예: rating 4.5, index 3 -> 4.5 >= 4)
        if (rating >= index + 1) {
          return Icon(Icons.star, color: color, size: size);
        }
        // 반쪽 별: rating이 (index + 0.5)보다 크거나 같을 때 (예: rating 4.5, index 4 -> 4.5 >= 4.5)
        else if (rating >= index + 0.5) {
          return Icon(Icons.star_half, color: color, size: size);
        }
        // 빈 별: 나머지 경우
        else {
          return Icon(Icons.star_border, color: unratedColor, size: size);
        }
      }),
    );
  }
}
