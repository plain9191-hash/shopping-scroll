import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/product.dart';
import '../theme/custom_colors.dart';
import 'star_rating.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final int? rank;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.rank,
  });

  Future<void> _launchUrl(BuildContext context, String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상품 링크가 존재하지 않습니다.')),
      );
      return;
    }

    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('브라우저를 열 수 없습니다: $url')),
        );
      }
    }
  }

  String _formatPrice(int price) {
    return '${NumberFormat('#,###').format(price)}원';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final customColors = Theme.of(context).extension<CustomColors>()!;
    final discountRate = product.originalPrice != null &&
            product.originalPrice! > product.currentPrice
        ? (product.originalPrice! - product.currentPrice) /
            product.originalPrice! *
            100
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          if (product.productUrl != null) {
            await _launchUrl(context, product.productUrl!);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 이미지 영역 ---
            _buildImageSection(context, colorScheme, discountRate),
            // --- 정보 영역 ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitle(),
                    const SizedBox(height: 6),
                    _buildPriceSection(colorScheme, customColors, discountRate),
                    const SizedBox(height: 6),
                    _buildReviewSection(colorScheme),
                    const Spacer(),
                    _buildFooter(colorScheme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(
    BuildContext context,
    ColorScheme colorScheme,
    double? discountRate,
  ) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: CachedNetworkImage(
              imageUrl: product.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: colorScheme.surfaceVariant,
                child:
                    const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (context, url, error) => Container(
                color: colorScheme.surfaceVariant,
                child: Icon(
                  Icons.image_not_supported,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        // --- 순위 배지 ---
        if (rank != null)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$rank위',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        // --- 특가 배지 ---
        if (product.isLowestPrice)
          Positioned(
            bottom: 10,
            left: 10,
            child: _buildBadge(
              '역대최저가',
              colorScheme.tertiary,
              colorScheme.onTertiary,
            ),
          ),
      ],
    );
  }

  Widget _buildTitle() {
    return Text(
      product.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
    );
  }

  Widget _buildPriceSection(
    ColorScheme colorScheme,
    CustomColors customColors,
    double? discountRate,
  ) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        if (discountRate != null && discountRate > 0)
          Text(
            '${discountRate.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: customColors.priceDown,
            ),
          ),
        Text(
          _formatPrice(product.currentPrice),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (product.originalPrice != null &&
            discountRate != null &&
            discountRate > 0)
          Text(
            _formatPrice(product.originalPrice!),
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
            ),
          ),
      ],
    );
  }

  Widget _buildReviewSection(ColorScheme colorScheme) {
    if (product.reviewCount == 0) return const SizedBox.shrink();
    return Row(
      children: [
        StarRating(rating: product.averageRating, size: 18),
        const SizedBox(width: 6),
        Text(
          '(${NumberFormat('#,###').format(product.reviewCount)})',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(ColorScheme colorScheme) {
    return Row(
      children: [
        _buildBadge(
          product.source == 'coupang' ? '쿠팡' : '네이버',
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
        ),
        if (product.isRocketDelivery) const SizedBox(width: 6),
        if (product.isRocketDelivery)
          _buildBadge(
            '🚀 로켓배송',
            const Color(0xFFE3F2FD),
            const Color(0xFF0D47A1),
          ),
      ],
    );
  }

  Widget _buildBadge(String text, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
