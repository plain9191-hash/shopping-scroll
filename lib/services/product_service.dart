import 'dart:convert';
import 'dart:io';
import '../models/product.dart';
import 'database_service.dart';

/// 상품 데이터 서비스 (읽기 전용)
/// 데이터 수집은 bin/fetch_data.dart 스크립트에서 수행
class ProductService {
  static const String dataDirectoryPath = '/Users/grace/price_tracker/data';

  // DB 서비스 인스턴스
  final DatabaseService _dbService = DatabaseService();

  Future<void> _ensureDataDirectoryExists() async {
    final directory = Directory(dataDirectoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  String _getFilePath(String categoryKey, DateTime date) {
    final dateString =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final key = categoryKey.isEmpty ? 'all' : categoryKey;
    return '$dataDirectoryPath/${dateString}_$key.json';
  }

  /// 오늘 날짜의 JSON 파일만 DB로 동기화 (기존 데이터 유지)
  Future<void> syncAllJsonToDatabase() async {
    final today = DateTime.now();
    final todayString = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    try {
      await _ensureDataDirectoryExists();
      final directory = Directory(dataDirectoryPath);
      final files = directory.listSync().whereType<File>().where((f) {
        final fileName = f.path.split('/').last;
        return fileName.endsWith('.json') && fileName.startsWith(todayString);
      });

      for (final file in files) {
        final fileName = file.path.split('/').last;
        final parts = fileName.replaceAll('.json', '').split('_');
        if (parts.length < 2) continue;

        final dateString = parts[0];
        final categoryKey = parts.sublist(1).join('_');

        // 날짜 파싱
        final dateParts = dateString.split('-');
        if (dateParts.length != 3) continue;
        final date = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );

        // JSON 파일 읽기
        final contents = await file.readAsString();
        if (contents.isEmpty) continue;

        final jsonList = json.decode(contents) as List;
        final products = jsonList
            .map((j) => Product.fromJson(j as Map<String, dynamic>))
            .toList();

        // DB에 저장 (해당 날짜/카테고리만 업데이트)
        await _dbService.saveProducts(
          categoryKey: categoryKey,
          date: date,
          products: products,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 모든 JSON 파일을 DB로 동기화 (최초 마이그레이션용)
  Future<void> syncAllJsonToDatabaseFull() async {
    try {
      await _ensureDataDirectoryExists();
      final directory = Directory(dataDirectoryPath);
      final files = directory.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();

      // 날짜순 정렬 (오래된 것부터)
      files.sort((a, b) => a.path.compareTo(b.path));

      for (final file in files) {
        final fileName = file.path.split('/').last;
        final parts = fileName.replaceAll('.json', '').split('_');
        if (parts.length < 2) continue;

        final dateString = parts[0];
        final categoryKey = parts.sublist(1).join('_');

        // 날짜 파싱
        final dateParts = dateString.split('-');
        if (dateParts.length != 3) continue;
        final date = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );

        // JSON 파일 읽기
        final contents = await file.readAsString();
        if (contents.isEmpty) continue;

        final jsonList = json.decode(contents) as List;
        final products = jsonList
            .map((j) => Product.fromJson(j as Map<String, dynamic>))
            .toList();

        // DB에 저장
        await _dbService.saveProducts(
          categoryKey: categoryKey,
          date: date,
          products: products,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Product>> _loadProductsFromFile(
    String categoryKey,
    DateTime date,
  ) async {
    final filePath = _getFilePath(categoryKey, date);
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.isEmpty) {
          return [];
        }
        final jsonList = json.decode(contents) as List;
        final products = jsonList
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();
        return products;
      }
    } catch (e) {
      // 파일 읽기 실패 시 빈 리스트 반환
    }
    return [];
  }

  /// 저장된 데이터만 읽어옴 (읽기 전용)
  /// 데이터 수집은 bin/fetch_data.dart 스크립트에서 수행
  Future<List<Product>> getCoupangProducts({
    required String categoryId,
    required String categoryKey,
    required DateTime date,
    int limit = 100,
    int offset = 0,
  }) async {
    // 저장된 파일에서만 데이터 로드 (네트워크 요청 없음)
    final productsFromFile = await _loadProductsFromFile(categoryKey, date);
    return productsFromFile;
  }

  /// 네이버 쇼핑 데이터 (현재 미지원 - 추후 구현 예정)
  Future<List<Product>> getNaverShoppingProducts({
    int page = 0,
    int offset = 0,
    int limit = 10,
  }) async {
    // 네이버 쇼핑은 현재 "오픈 준비 중"
    return [];
  }
}
