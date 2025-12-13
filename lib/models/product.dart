class Product {
  final String id;
  final String title;
  final String imageUrl;
  final int currentPrice;
  final int averagePrice;
  final double priceChangePercent;
  final String source; // 'coupang' or 'naver'
  final String? category;
  final bool isRocketDelivery;
  final bool isLowestPrice;
  final String? productUrl;

  Product({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.currentPrice,
    required this.averagePrice,
    required this.priceChangePercent,
    required this.source,
    this.category,
    this.isRocketDelivery = false,
    this.isLowestPrice = false,
    this.productUrl,
  });

  bool get isPriceDown => priceChangePercent < 0;
  bool get isPriceUp => priceChangePercent > 0;

  int get priceDifference => currentPrice - averagePrice;
}



