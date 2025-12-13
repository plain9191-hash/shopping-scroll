import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product.dart';
import 'star_rating.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCard({super.key, required this.product, this.onTap});

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) {
      print('URL이 비어있습니다');
      return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // 새 창에서 열기
        );
      } else {
        print('URL을 열 수 없습니다: $url');
      }
    } catch (e) {
      print('URL 실행 오류: $e - URL: $url');
    }
  }

  String _formatPrice(int price) {
    return '${NumberFormat('#,###').format(price)}원';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          if (product.productUrl != null && product.productUrl!.isNotEmpty) {
            await _launchUrl(product.productUrl!);
          } else {
            // URL이 없으면 사용자에게 알림
            if (onTap != null) {
              onTap!();
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상품 이미지
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 180,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 180,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                // 역대최저가 배지
                if (product.isLowestPrice)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '역대최저가',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // 상품 정보
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 출처 및 배송 정보
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: product.source == 'coupang'
                              ? Colors.orange[100]
                              : Colors.green[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.source == 'coupang' ? '쿠팡' : '네이버',
                          style: TextStyle(
                            fontSize: 10,
                            color: product.source == 'coupang'
                                ? Colors.orange[900]
                                : Colors.green[900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (product.isRocketDelivery) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.local_shipping,
                          size: 14,
                          color: Colors.orange[700],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 상품명
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
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
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  // 가격 정보
                  Text(
                    _formatPrice(product.currentPrice),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: product.isPriceDown
                          ? Colors.red[700]
                          : Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
