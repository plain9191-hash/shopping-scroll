class Product {
  final String id;
  final String title;
  final String imageUrl;
  final int currentPrice;
  final int? originalPrice;
  final int averagePrice;
  final double priceChangePercent;
  final String source; // 'coupang' or 'naver'
  final String? category;
  final bool isRocketDelivery;
  final bool isLowestPrice;
  final int reviewCount;
  final double averageRating;
  final String? productUrl;
  final int? ranking; // 순위

  Product({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.currentPrice,
    this.originalPrice,
    required this.averagePrice,
    required this.priceChangePercent,
    required this.source,
    this.category,
    this.isRocketDelivery = false,
    this.isLowestPrice = false,
    this.reviewCount = 0,
    this.averageRating = 0.0,
    this.productUrl,
    this.ranking,
  });

  bool get isPriceDown => priceChangePercent < 0;
  bool get isPriceUp => priceChangePercent > 0;

  int get priceDifference => currentPrice - averagePrice;

  // JSON deserialization
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      title: json['title'] as String,
      imageUrl: json['imageUrl'] as String,
      currentPrice: json['currentPrice'] as int,
      originalPrice: json['originalPrice'] as int?,
      averagePrice: json['averagePrice'] as int,
      priceChangePercent: (json['priceChangePercent'] as num).toDouble(),
      source: json['source'] as String,
      category: json['category'] as String?,
      isRocketDelivery: json['isRocketDelivery'] as bool? ?? false,
      isLowestPrice: json['isLowestPrice'] as bool? ?? false,
      reviewCount: json['reviewCount'] as int? ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      productUrl: json['productUrl'] as String?,
      ranking: json['ranking'] as int?,
    );
  }

  // JSON 직렬화를 위한 toJson 메서드
  Map<String, dynamic> toJson() {
    return {
      'ranking': ranking,
      'id': id,
      'title': title,
      'imageUrl': imageUrl,
      'currentPrice': currentPrice,
      'originalPrice': originalPrice,
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

  /// ranking을 포함한 새 Product 생성
  Product copyWithRanking(int rank) {
    return Product(
      id: id,
      title: title,
      imageUrl: imageUrl,
      currentPrice: currentPrice,
      originalPrice: originalPrice,
      averagePrice: averagePrice,
      priceChangePercent: priceChangePercent,
      source: source,
      category: category,
      isRocketDelivery: isRocketDelivery,
      isLowestPrice: isLowestPrice,
      reviewCount: reviewCount,
      averageRating: averageRating,
      productUrl: productUrl,
      ranking: rank,
    );
  }
}
