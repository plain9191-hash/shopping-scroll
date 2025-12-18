import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/product_analytics.dart';
import 'product_service.dart';

/// 상품 분석 서비스
class AnalyticsService {
  /// 저장된 데이터 파일 목록 조회
  Future<List<FileInfo>> getAvailableDataFiles() async {
    final files = <FileInfo>[];
    try {
      final directory = Directory(ProductService.dataDirectoryPath);
      if (!await directory.exists()) {
        return files;
      }

      final dateFormat = DateFormat('yyyy-MM-dd');
      for (final file in directory.listSync()) {
        if (file is File && file.path.endsWith('.json')) {
          final fileName = file.path.split('/').last;
          final parts = fileName.replaceAll('.json', '').split('_');
          if (parts.length >= 2) {
            try {
              final date = dateFormat.parse(parts[0]);
              final categoryId = parts.sublist(1).join('_');
              files.add(FileInfo(
                path: file.path,
                date: date,
                categoryId: categoryId,
              ));
            } catch (e) {
              // 잘못된 형식의 파일 무시
            }
          }
        }
      }

      // 날짜순 정렬 (최신순)
      files.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      print('❌ [분석] 파일 목록 조회 실패: $e');
    }
    return files;
  }

  /// 특정 카테고리의 모든 날짜 데이터 로드
  Future<Map<DateTime, List<RankedProduct>>> loadProductsByCategory(
    String categoryId,
  ) async {
    final result = <DateTime, List<RankedProduct>>{};
    final files = await getAvailableDataFiles();

    for (final file in files.where((f) => f.categoryId == categoryId)) {
      try {
        final fileObj = File(file.path);
        final contents = await fileObj.readAsString();
        if (contents.isEmpty) continue;

        final jsonList = json.decode(contents) as List;
        final products = <RankedProduct>[];

        for (int i = 0; i < jsonList.length; i++) {
          final product = Product.fromJson(jsonList[i] as Map<String, dynamic>);
          products.add(RankedProduct(
            product: product,
            rank: i + 1, // 파일 내 순서가 순위
          ));
        }

        result[file.date] = products;
      } catch (e) {
        print('❌ [분석] 파일 로드 실패: ${file.path}, $e');
      }
    }

    return result;
  }

  /// 사용 가능한 카테고리 목록 조회
  Future<Set<String>> getAvailableCategories() async {
    final files = await getAvailableDataFiles();
    return files.map((f) => f.categoryId).toSet();
  }

  /// 사용 가능한 날짜 목록 조회
  Future<List<DateTime>> getAvailableDates() async {
    final files = await getAvailableDataFiles();
    final dates = files.map((f) => f.date).toSet().toList();
    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }

  /// 상품 분석 수행
  Future<List<ProductAnalytics>> analyzeProducts({
    required String categoryId,
    int? recentDays, // null이면 모든 날짜
  }) async {
    final dataByDate = await loadProductsByCategory(categoryId);
    if (dataByDate.isEmpty) return [];

    // 날짜 필터링
    final dates = dataByDate.keys.toList()..sort((a, b) => b.compareTo(a));
    final filteredDates = recentDays != null
        ? dates.take(recentDays).toList()
        : dates;

    if (filteredDates.isEmpty) return [];

    // 상품별 데이터 수집
    final productDataMap = <String, _ProductData>{};

    for (final date in filteredDates) {
      final products = dataByDate[date] ?? [];
      for (final rankedProduct in products) {
        final product = rankedProduct.product;
        final key = _normalizeProductKey(product);

        if (!productDataMap.containsKey(key)) {
          productDataMap[key] = _ProductData(
            productId: product.id,
            title: product.title,
            imageUrl: product.imageUrl,
            productUrl: product.productUrl,
          );
        }

        productDataMap[key]!.addRankRecord(
          date: date,
          rank: rankedProduct.rank,
          price: product.currentPrice,
          categoryId: categoryId,
        );
      }
    }

    // 분석 결과 계산
    final totalDays = filteredDates.length;
    final analytics = <ProductAnalytics>[];

    for (final data in productDataMap.values) {
      final analysis = data.calculateAnalytics(totalDays);
      analytics.add(analysis);
    }

    // 소싱 점수순 정렬
    analytics.sort((a, b) => b.sourcingScore.compareTo(a.sourcingScore));

    return analytics;
  }

  /// 상품 키 정규화 (중복 방지)
  String _normalizeProductKey(Product product) {
    // URL이 있으면 URL 기반, 없으면 제목 기반
    if (product.productUrl != null && product.productUrl!.isNotEmpty) {
      // URL에서 쿼리 파라미터 제거
      final url = product.productUrl!.split('?').first;
      return url;
    }
    // 제목 정규화 (공백, 특수문자 제거)
    return product.title.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }
}

/// 파일 정보
class FileInfo {
  final String path;
  final DateTime date;
  final String categoryId;

  FileInfo({
    required this.path,
    required this.date,
    required this.categoryId,
  });
}

/// 순위가 포함된 상품
class RankedProduct {
  final Product product;
  final int rank;

  RankedProduct({
    required this.product,
    required this.rank,
  });
}

/// 상품 데이터 수집용 내부 클래스
class _ProductData {
  final String productId;
  final String title;
  final String imageUrl;
  final String? productUrl;
  final List<RankHistory> rankRecords = [];

  _ProductData({
    required this.productId,
    required this.title,
    required this.imageUrl,
    this.productUrl,
  });

  void addRankRecord({
    required DateTime date,
    required int rank,
    required int price,
    required String categoryId,
  }) {
    rankRecords.add(RankHistory(
      date: date,
      rank: rank,
      price: price,
      categoryId: categoryId,
    ));
  }

  ProductAnalytics calculateAnalytics(int totalDays) {
    final appearanceCount = rankRecords.length;
    final ranks = rankRecords.map((r) => r.rank).toList();
    final prices = rankRecords.map((r) => r.price).toList();

    // 평균 순위
    final averageRank = ranks.reduce((a, b) => a + b) / ranks.length;

    // 순위 안정성 (표준편차)
    final rankStability = _calculateStdDev(ranks.map((r) => r.toDouble()).toList());

    // 가격 정보
    final latestRecord = rankRecords.reduce(
      (a, b) => a.date.isAfter(b.date) ? a : b,
    );
    final lowestPrice = prices.reduce(min);
    final highestPrice = prices.reduce(max);

    // 소싱 점수 계산
    // 등장횟수 점수: (등장횟수 / 전체 날짜수) × 100
    final appearanceScore = (appearanceCount / totalDays) * 100;

    // 순위 점수: (1 - 평균순위/100) × 100 (1위가 100점, 100위가 0점)
    final rankScore = (1 - (averageRank / 100).clamp(0, 1)) * 100;

    // 안정성 점수: (1 - 순위표준편차/50) × 100 (표준편차 0이 100점)
    final stabilityScore = (1 - (rankStability / 50).clamp(0, 1)) * 100;

    // 복합 점수: 등장횟수 40% + 순위 40% + 안정성 20%
    final sourcingScore =
        (appearanceScore * 0.4) + (rankScore * 0.4) + (stabilityScore * 0.2);

    return ProductAnalytics(
      productId: productId,
      title: title,
      imageUrl: imageUrl,
      productUrl: productUrl,
      appearanceCount: appearanceCount,
      averageRank: averageRank,
      rankStability: rankStability,
      rankHistory: List.from(rankRecords)
        ..sort((a, b) => a.date.compareTo(b.date)),
      latestPrice: latestRecord.price,
      lowestPrice: lowestPrice,
      highestPrice: highestPrice,
      sourcingScore: sourcingScore.clamp(0, 100),
    );
  }

  double _calculateStdDev(List<double> values) {
    if (values.length < 2) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => pow(v - mean, 2));
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }
}
