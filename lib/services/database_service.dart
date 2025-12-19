import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/product.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'price_tracker.db';
  static const String dataDirectoryPath = '/Users/grace/price_tracker/data';

  // 싱글톤 패턴
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // macOS/Linux/Windows에서 FFI 사용
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // data 디렉토리 확인/생성
    final directory = Directory(dataDirectoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final dbPath = join(dataDirectoryPath, _dbName);
    print('📦 [DB] 데이터베이스 경로: $dbPath');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    print('📦 [DB] 테이블 생성 중...');

    // 상품 테이블
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id TEXT NOT NULL,
        title TEXT NOT NULL,
        image_url TEXT,
        current_price INTEGER NOT NULL,
        original_price INTEGER,
        average_price INTEGER,
        price_change_percent REAL,
        source TEXT NOT NULL,
        category_key TEXT NOT NULL,
        is_rocket_delivery INTEGER DEFAULT 0,
        is_lowest_price INTEGER DEFAULT 0,
        product_url TEXT,
        review_count INTEGER DEFAULT 0,
        average_rating REAL DEFAULT 0.0,
        ranking INTEGER,
        recorded_date TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 인덱스 생성 (쿼리 성능 향상)
    await db.execute(
      'CREATE INDEX idx_products_date ON products(recorded_date)',
    );
    await db.execute(
      'CREATE INDEX idx_products_category ON products(category_key)',
    );
    await db.execute(
      'CREATE INDEX idx_products_product_id ON products(product_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_products_unique ON products(product_id, category_key, recorded_date)',
    );

    print('✅ [DB] 테이블 생성 완료!');
  }

  // 상품 목록 저장 (날짜/카테고리별)
  Future<void> saveProducts({
    required String categoryKey,
    required DateTime date,
    required List<Product> products,
  }) async {
    final db = await database;
    final dateString = _formatDate(date);

    print('💾 [DB] 저장 시작: $categoryKey / $dateString (${products.length}개)');

    // 배치 처리로 성능 향상
    final batch = db.batch();

    // 기존 데이터 삭제 (같은 날짜/카테고리)
    batch.delete(
      'products',
      where: 'category_key = ? AND recorded_date = ?',
      whereArgs: [categoryKey, dateString],
    );

    // 새 데이터 삽입
    for (int i = 0; i < products.length; i++) {
      final product = products[i];
      batch.insert('products', {
        'product_id': product.id,
        'title': product.title,
        'image_url': product.imageUrl,
        'current_price': product.currentPrice,
        'original_price': product.originalPrice,
        'average_price': product.averagePrice,
        'price_change_percent': product.priceChangePercent,
        'source': product.source,
        'category_key': categoryKey,
        'is_rocket_delivery': product.isRocketDelivery ? 1 : 0,
        'is_lowest_price': product.isLowestPrice ? 1 : 0,
        'product_url': product.productUrl,
        'review_count': product.reviewCount,
        'average_rating': product.averageRating,
        'ranking': product.ranking ?? (i + 1),
        'recorded_date': dateString,
      });
    }

    await batch.commit(noResult: true);
    print('✅ [DB] 저장 완료: $categoryKey / $dateString');
  }

  // 상품 목록 조회 (날짜/카테고리별)
  Future<List<Product>> getProducts({
    required String categoryKey,
    required DateTime date,
  }) async {
    final db = await database;
    final dateString = _formatDate(date);

    final results = await db.query(
      'products',
      where: 'category_key = ? AND recorded_date = ?',
      whereArgs: [categoryKey, dateString],
      orderBy: 'ranking ASC',
    );

    if (results.isEmpty) {
      return [];
    }

    print('📄 [DB] 조회 완료: $categoryKey / $dateString (${results.length}개)');

    return results.map((row) => _rowToProduct(row)).toList();
  }

  // 특정 날짜의 모든 카테고리 데이터 존재 여부
  Future<bool> hasDataForDate(DateTime date) async {
    final db = await database;
    final dateString = _formatDate(date);

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE recorded_date = ?',
      [dateString],
    );

    final count = result.first['count'] as int;
    return count > 0;
  }

  // 저장된 날짜 목록 조회
  Future<List<DateTime>> getAvailableDates() async {
    final db = await database;

    final results = await db.rawQuery(
      'SELECT DISTINCT recorded_date FROM products ORDER BY recorded_date DESC',
    );

    return results.map((row) {
      final dateStr = row['recorded_date'] as String;
      return DateTime.parse(dateStr);
    }).toList();
  }

  // 상품 순위 히스토리 조회 (분석용)
  Future<List<Map<String, dynamic>>> getProductRankHistory({
    required String productId,
    String? categoryKey,
    int? limit,
  }) async {
    final db = await database;

    String query = '''
      SELECT recorded_date, ranking, current_price, category_key
      FROM products
      WHERE product_id = ?
    ''';
    List<dynamic> args = [productId];

    if (categoryKey != null) {
      query += ' AND category_key = ?';
      args.add(categoryKey);
    }

    query += ' ORDER BY recorded_date DESC';

    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);
    }

    return await db.rawQuery(query, args);
  }

  // 자주 상위권에 나타나는 상품 조회 (소싱 분석용)
  Future<List<Map<String, dynamic>>> getTopRankedProducts({
    String? categoryKey,
    int minAppearances = 3,
    int maxAvgRank = 30,
    int limit = 50,
  }) async {
    final db = await database;

    String query = '''
      SELECT
        product_id,
        title,
        image_url,
        product_url,
        COUNT(*) as appearance_count,
        AVG(ranking) as avg_rank,
        MIN(ranking) as best_rank,
        MAX(ranking) as worst_rank,
        AVG(current_price) as avg_price,
        category_key
      FROM products
    ''';

    List<dynamic> args = [];

    if (categoryKey != null && categoryKey != 'all') {
      query += ' WHERE category_key = ?';
      args.add(categoryKey);
    }

    query += '''
      GROUP BY product_id
      HAVING appearance_count >= ? AND avg_rank <= ?
      ORDER BY avg_rank ASC, appearance_count DESC
      LIMIT ?
    ''';

    args.addAll([minAppearances, maxAvgRank, limit]);

    return await db.rawQuery(query, args);
  }

  // 카테고리별 통계
  Future<Map<String, dynamic>> getCategoryStats(String categoryKey) async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT
        COUNT(DISTINCT recorded_date) as total_days,
        COUNT(*) as total_records,
        COUNT(DISTINCT product_id) as unique_products,
        AVG(current_price) as avg_price
      FROM products
      WHERE category_key = ?
    ''', [categoryKey]);

    return result.first;
  }

  // 날짜 포맷팅
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // DB Row → Product 변환
  Product _rowToProduct(Map<String, dynamic> row) {
    return Product(
      id: row['product_id'] as String,
      title: row['title'] as String,
      imageUrl: row['image_url'] as String? ?? '',
      currentPrice: row['current_price'] as int,
      originalPrice: row['original_price'] as int?,
      averagePrice: (row['average_price'] as int?) ?? 0,
      priceChangePercent: (row['price_change_percent'] as double?) ?? 0.0,
      source: row['source'] as String,
      category: row['category_key'] as String?,
      isRocketDelivery: (row['is_rocket_delivery'] as int) == 1,
      isLowestPrice: (row['is_lowest_price'] as int) == 1,
      productUrl: row['product_url'] as String?,
      reviewCount: row['review_count'] as int? ?? 0,
      averageRating: row['average_rating'] as double? ?? 0.0,
      ranking: row['ranking'] as int?,
    );
  }

  // DB 닫기
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
