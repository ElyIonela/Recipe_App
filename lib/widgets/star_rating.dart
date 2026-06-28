import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final int starCount;
  final double size;
  final Color color;
  final bool interactive;
  final ValueChanged<int>? onRatingChanged;

  const StarRating({
    super.key,
    required this.rating,
    this.starCount = 5,
    this.size = 20,
    this.color = Colors.amber,
    this.interactive = false,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(starCount, (index) {
        final starValue = index + 1;
        IconData icon;
        if (rating >= starValue) {
          icon = Icons.star;
        } else if (rating >= starValue - 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }

        final star = Icon(icon, color: color, size: size);

        if (interactive) {
          return GestureDetector(
            onTap: () => onRatingChanged?.call(starValue),
            child: star,
          );
        }
        return star;
      }),
    );
  }
}
