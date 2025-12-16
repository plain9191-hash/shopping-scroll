import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
      print('URL이 비어있습니다');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('상품 링크가 존재하지 않습니다.')));
      return;
    }

    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      print('URL을 열 수 없습니다: $url');
      // 사용자에게 피드백 제공
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('브라우저를 열 수 없습니다: $url')));
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
    final priceDifference = product.priceDifference;
    final priceChangeText =
        '${NumberFormat('#,###').format(priceDifference.abs())}원 (${product.priceChangePercent.abs().toStringAsFixed(1)}%)';

    // 할인율 계산
    double? discountRate;
    if (product.originalPrice != null &&
        product.originalPrice! > product.currentPrice) {
      discountRate = (product.originalPrice! - product.currentPrice) /
          product.originalPrice! *
          100;
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          if (product.productUrl != null) {
            await _launchUrl(context, product.productUrl!);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 순위 ---
              if (rank != null)
                Container(
                  width: 32,
                  height: 120, // 이미지 높이와 맞춤
                  alignment: Alignment.center,
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              if (rank != null) const SizedBox(width: 8),

              // --- 이미지 영역 ---
              Stack(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: colorScheme.surfaceVariant,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
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
                  // 역대최저가 배지
                  if (product.isLowestPrice)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '역대최저가',
                          style: TextStyle(
                            color: colorScheme.onTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // --- 정보 영역 ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 출처
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.source == 'coupang' ? '쿠팡' : '네이버',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 상품명
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 가격 정보
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (discountRate != null && discountRate > 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  '${discountRate.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: customColors.priceDown,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (product.originalPrice != null &&
                                      discountRate != null &&
                                      discountRate > 0)
                                    Text(
                                      _formatPrice(product.originalPrice!),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.onSurfaceVariant,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  Text(
                                    _formatPrice(product.currentPrice),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 별점 및 리뷰
                    if (product.reviewCount > 0)
                      Row(
                        children: [
                          StarRating(rating: product.averageRating, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '(${NumberFormat('#,###').format(product.reviewCount)})',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
