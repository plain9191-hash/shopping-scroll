/// 날짜별 순위 기록
class RankHistory {
  final DateTime date;
  final int rank;
  final int price;
  final String categoryId;

  RankHistory({
    required this.date,
    required this.rank,
    required this.price,
    required this.categoryId,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'rank': rank,
        'price': price,
        'categoryId': categoryId,
      };

  factory RankHistory.fromJson(Map<String, dynamic> json) => RankHistory(
        date: DateTime.parse(json['date'] as String),
        rank: json['rank'] as int,
        price: json['price'] as int,
        categoryId: json['categoryId'] as String,
      );
}

/// 상품 분석 결과 모델
class ProductAnalytics {
  final String productId;
  final String title;
  final String imageUrl;
  final String? productUrl;
  final int appearanceCount; // 등장 횟수
  final double averageRank; // 평균 순위
  final double rankStability; // 순위 안정성 (표준편차, 낮을수록 안정적)
  final List<RankHistory> rankHistory; // 날짜별 순위 기록
  final int latestPrice;
  final int lowestPrice;
  final int highestPrice;
  final double sourcingScore; // 소싱 추천 점수 (0-100)
  final double appearanceScore; // 등장 점수 (40%)
  final double rankScore; // 순위 점수 (40%)
  final double stabilityScore; // 안정성 점수 (20%)
  final int totalDays; // 분석 기간 일수

  ProductAnalytics({
    required this.productId,
    required this.title,
    required this.imageUrl,
    this.productUrl,
    required this.appearanceCount,
    required this.averageRank,
    required this.rankStability,
    required this.rankHistory,
    required this.latestPrice,
    required this.lowestPrice,
    required this.highestPrice,
    required this.sourcingScore,
    required this.appearanceScore,
    required this.rankScore,
    required this.stabilityScore,
    required this.totalDays,
  });

  /// 가격 변동률 (최저가 대비 최고가)
  double get priceVariation {
    if (lowestPrice == 0) return 0;
    return ((highestPrice - lowestPrice) / lowestPrice) * 100;
  }

  /// 최신 순위
  int get latestRank {
    if (rankHistory.isEmpty) return 0;
    final sorted = List<RankHistory>.from(rankHistory)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.first.rank;
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'title': title,
        'imageUrl': imageUrl,
        'productUrl': productUrl,
        'appearanceCount': appearanceCount,
        'averageRank': averageRank,
        'rankStability': rankStability,
        'rankHistory': rankHistory.map((h) => h.toJson()).toList(),
        'latestPrice': latestPrice,
        'lowestPrice': lowestPrice,
        'highestPrice': highestPrice,
        'sourcingScore': sourcingScore,
        'appearanceScore': appearanceScore,
        'rankScore': rankScore,
        'stabilityScore': stabilityScore,
        'totalDays': totalDays,
      };

  factory ProductAnalytics.fromJson(Map<String, dynamic> json) =>
      ProductAnalytics(
        productId: json['productId'] as String,
        title: json['title'] as String,
        imageUrl: json['imageUrl'] as String,
        productUrl: json['productUrl'] as String?,
        appearanceCount: json['appearanceCount'] as int,
        averageRank: (json['averageRank'] as num).toDouble(),
        rankStability: (json['rankStability'] as num).toDouble(),
        rankHistory: (json['rankHistory'] as List)
            .map((h) => RankHistory.fromJson(h as Map<String, dynamic>))
            .toList(),
        latestPrice: json['latestPrice'] as int,
        lowestPrice: json['lowestPrice'] as int,
        highestPrice: json['highestPrice'] as int,
        sourcingScore: (json['sourcingScore'] as num).toDouble(),
        appearanceScore: (json['appearanceScore'] as num?)?.toDouble() ?? 0,
        rankScore: (json['rankScore'] as num?)?.toDouble() ?? 0,
        stabilityScore: (json['stabilityScore'] as num?)?.toDouble() ?? 0,
        totalDays: (json['totalDays'] as int?) ?? 0,
      );
}
