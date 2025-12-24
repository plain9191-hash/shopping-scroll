#!/usr/bin/env dart
/// 데이터 수집 CLI 스크립트
///
/// 사용법:
///   dart run bin/fetch_data.dart
///
/// cron 설정 예시 (매일 오전 6시):
///   0 6 * * * cd /Users/grace/price_tracker && dart run bin/fetch_data.dart >> logs/fetch.log 2>&1

import 'dart:io';
import 'dart:convert';

const String dataDirectoryPath = '/Users/grace/price_tracker/data';
const String dbPath = '/Users/grace/price_tracker/data/price_tracker.db';
const String scriptsPath = '/Users/grace/price_tracker/scripts';
const String venvPython = '/Users/grace/price_tracker/scripts/venv/bin/python3';

final Map<String, String> categories = {
  'all': '',
  'fashion': '564553',
  'beauty': '176422',
  'baby': '221834',
  'food': '194176',
  'kitchen': '185569',
  'living': '115573',
  'interior': '184455',
  'digital': '178155',
  'sports': '317678',
  'car': '183960',
  'books': '317677',
  'toys': '317679',
  'office': '177195',
  'pet': '115574',
  'health': '305698',
};

void main() async {
  final startTime = DateTime.now();
  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('🚀 [하우머치] 데이터 수집 시작');
  print('📅 ${startTime.toString().substring(0, 19)}');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('');

  // 1. 데이터 디렉토리 확인/생성
  await _ensureDirectories();

  // 2. 모든 카테고리 데이터 수집
  final today = DateTime.now();
  final dateString = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

  int successCount = 0;
  int failCount = 0;
  int totalProducts = 0;

  for (final entry in categories.entries) {
    final categoryKey = entry.key;
    final categoryName = _getCategoryDisplayName(categoryKey);

    print('📦 [$categoryName] 데이터 수집 중...');

    try {
      final productCount = await _fetchCategory(categoryKey, dateString);
      if (productCount > 0) {
        print('   ✅ ${productCount}개 상품 저장 완료');
        successCount++;
        totalProducts += productCount;
      } else {
        print('   ⚠️  상품 없음');
        failCount++;
      }
    } catch (e) {
      print('   ❌ 실패: $e');
      failCount++;
    }

    // 서버 부하 방지를 위한 딜레이
    await Future.delayed(const Duration(seconds: 2));
  }

  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('📊 데이터 수집 완료');
  print('   성공: $successCount개 카테고리');
  print('   실패: $failCount개 카테고리');
  print('   총 상품: $totalProducts개');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('');

  // 3. JSON → DB 동기화
  print('🔄 [DB 동기화] JSON 파일을 DB로 동기화 중...');
  await _syncToDatabase(dateString);

  final endTime = DateTime.now();
  final duration = endTime.difference(startTime);

  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('✅ [하우머치] 모든 작업 완료!');
  print('⏱️  소요 시간: ${duration.inMinutes}분 ${duration.inSeconds % 60}초');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('');
}

Future<void> _ensureDirectories() async {
  final dataDir = Directory(dataDirectoryPath);
  if (!await dataDir.exists()) {
    await dataDir.create(recursive: true);
    print('📁 데이터 디렉토리 생성: $dataDirectoryPath');
  }

  final logsDir = Directory('/Users/grace/price_tracker/logs');
  if (!await logsDir.exists()) {
    await logsDir.create(recursive: true);
    print('📁 로그 디렉토리 생성: ${logsDir.path}');
  }
}

Future<int> _fetchCategory(String categoryKey, String dateString) async {
  final scriptPath = '$scriptsPath/scrape_coupang.py';

  // Python 스크립트 실행
  final result = await Process.run(
    venvPython,
    [scriptPath, categoryKey],
    workingDirectory: scriptsPath,
  );

  if (result.exitCode != 0) {
    throw Exception('Python 스크립트 실패: ${result.stderr}');
  }

  // JSON 파일 확인
  final jsonPath = '$dataDirectoryPath/${dateString}_$categoryKey.json';
  final file = File(jsonPath);

  if (await file.exists()) {
    final contents = await file.readAsString();
    if (contents.isNotEmpty) {
      final jsonList = json.decode(contents) as List;
      return jsonList.length;
    }
  }

  return 0;
}

Future<void> _syncToDatabase(String dateString) async {
  try {
    final directory = Directory(dataDirectoryPath);
    final files = directory.listSync().whereType<File>().where((f) {
      final fileName = f.path.split('/').last;
      return fileName.endsWith('.json') && fileName.startsWith(dateString);
    }).toList();

    if (files.isEmpty) {
      print('   ⚠️  동기화할 파일이 없습니다.');
      return;
    }

    // Dart에서 직접 SQLite 사용하기 위해 별도 스크립트 실행
    final syncScriptPath = '$scriptsPath/sync_to_db.dart';
    final syncScript = File(syncScriptPath);

    if (!await syncScript.exists()) {
      // sync_to_db.dart가 없으면 생성
      await _createSyncScript(syncScriptPath);
    }

    final result = await Process.run(
      'dart',
      ['run', syncScriptPath, dateString],
      workingDirectory: '/Users/grace/price_tracker',
    );

    if (result.exitCode == 0) {
      print('   ✅ DB 동기화 완료!');
      if (result.stdout.toString().isNotEmpty) {
        print(result.stdout);
      }
    } else {
      print('   ⚠️  DB 동기화 중 오류: ${result.stderr}');
    }
  } catch (e) {
    print('   ❌ DB 동기화 실패: $e');
  }
}

Future<void> _createSyncScript(String path) async {
  final content = '''
import 'dart:io';
import 'dart:convert';
import 'package:price_tracker/services/database_service.dart';
import 'package:price_tracker/models/product.dart';

const String dataDirectoryPath = '/Users/grace/price_tracker/data';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('사용법: dart run scripts/sync_to_db.dart <date_string>');
    print('예: dart run scripts/sync_to_db.dart 2024-12-24');
    exit(1);
  }

  final dateString = args[0];
  final dbService = DatabaseService();

  print('🔄 \$dateString 데이터 DB 동기화 시작...');

  try {
    final directory = Directory(dataDirectoryPath);
    final files = directory.listSync().whereType<File>().where((f) {
      final fileName = f.path.split('/').last;
      return fileName.endsWith('.json') && fileName.startsWith(dateString);
    }).toList();

    int totalSynced = 0;
    for (final file in files) {
      final fileName = file.path.split('/').last;
      final parts = fileName.replaceAll('.json', '').split('_');
      if (parts.length < 2) continue;

      final categoryKey = parts.sublist(1).join('_');
      final dateParts = parts[0].split('-');
      if (dateParts.length != 3) continue;

      final date = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );

      final contents = await file.readAsString();
      if (contents.isEmpty) continue;

      final jsonList = json.decode(contents) as List;
      final products = jsonList
          .map((j) => Product.fromJson(j as Map<String, dynamic>))
          .toList();

      await dbService.saveProducts(
        categoryKey: categoryKey,
        date: date,
        products: products,
      );
      totalSynced += products.length;
      print('  ✅ \$fileName: \${products.length}개');
    }
    print('🔄 총 \$totalSynced개 상품 동기화 완료');
  } catch (e) {
    print('❌ 동기화 실패: \$e');
    exit(1);
  }
}
''';

  await File(path).writeAsString(content);
  print('   📝 동기화 스크립트 생성: $path');
}

String _getCategoryDisplayName(String key) {
  const names = {
    'all': '전체',
    'fashion': '패션의류/잡화',
    'beauty': '뷰티',
    'baby': '출산/유아동',
    'food': '식품',
    'kitchen': '주방용품',
    'living': '생활용품',
    'interior': '홈인테리어',
    'digital': '가전디지털',
    'sports': '스포츠/레저',
    'car': '자동차용품',
    'books': '도서',
    'toys': '완구/취미',
    'office': '문구/오피스',
    'pet': '반려/애완',
    'health': '헬스/건강식품',
  };
  return names[key] ?? key;
}
