class Product {
  final String id;
  final String title;
  final String imageUrl;
  final int currentPrice;
  final int? originalPrice; // Add originalPrice field
  final int averagePrice;
  final double priceChangePercent;
  final String source; // 'coupang' or 'naver'
  final String? category;
  final bool isRocketDelivery;
  final bool isLowestPrice;
  final int reviewCount;
  final double averageRating;
  final String? productUrl;

  Product({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.currentPrice,
    this.originalPrice, // Add to constructor
    required this.averagePrice,
    required this.priceChangePercent,
    required this.source,
    this.category,
    this.isRocketDelivery = false,
    this.isLowestPrice = false,
    this.reviewCount = 0,
    this.averageRating = 0.0,
    this.productUrl,
  });

  bool get isPriceDown => priceChangePercent < 0;
  bool get isPriceUp => priceChangePercent > 0;

  int get priceDifference => currentPrice - averagePrice;

  // JSON 직렬화를 위한 toJson 메서드
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'imageUrl': imageUrl,
      'currentPrice': currentPrice,
      'originalPrice': originalPrice, // Add to toJson
      'averagePrice': averagePrice,
      'priceChangePercent': priceChangePercent,
      'source': source,
      'category': category,
      'isRocketDelivery': isRocketDelivery,
      'isLowestPrice': isLowestPrice,
      'reviewCount': reviewCount,
      'averageRating': averageRating,
      'productUrl': productUrl,
    };
  }
}
