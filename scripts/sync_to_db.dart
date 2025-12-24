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

  print('🔄 $dateString 데이터 DB 동기화 시작...');

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
      print('  ✅ $fileName: ${products.length}개');
    }
    print('🔄 총 $totalSynced개 상품 동기화 완료');
  } catch (e) {
    print('❌ 동기화 실패: $e');
    exit(1);
  }
}
