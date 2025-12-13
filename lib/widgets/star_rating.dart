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
    return Stack(
      children: [
        // 배경 (회색 별 5개)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (index) => Icon(Icons.star, color: unratedColor, size: size),
          ),
        ),
        // 전경 (채워진 주황색 별)
        ClipRect(
          clipper: _StarClipper(rating: rating, starSize: size),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              5,
              (index) => Icon(Icons.star, color: color, size: size),
            ),
          ),
        ),
      ],
    );
  }
}

class _StarClipper extends CustomClipper<Rect> {
  final double rating;
  final double starSize;

  _StarClipper({required this.rating, required this.starSize});

  @override
  Rect getClip(Size size) {
    // 별점(0~5)에 따라 잘라낼 너비를 계산합니다.
    return Rect.fromLTWH(0, 0, rating * starSize, size.height);
  }

  @override
  bool shouldReclip(_StarClipper oldClipper) {
    return rating != oldClipper.rating || starSize != oldClipper.starSize;
  }
}
