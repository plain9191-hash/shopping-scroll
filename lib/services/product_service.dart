import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/product.dart';

class ProductService {
  static const String _coupangBaseUrl = 'https://www.coupang.com';
  static const String _naverShoppingBaseUrl = 'https://shopping.naver.com';
  static const String _naverApiBaseUrl =
      'https://openapi.naver.com/v1/search/shop.json';

  final String _naverClientId = dotenv.env['NAVER_CLIENT_ID'] ?? '';
  final String _naverClientSecret = dotenv.env['NAVER_CLIENT_SECRET'] ?? '';

  // 실제 쿠팡 상품 스크래핑 (메인/베스트 페이지)
  Future<List<Product>> getCoupangProducts({
    int page = 0,
    int offset = 0,
    int limit = 10,
  }) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🛒 [쿠팡] 상품 데이터 가져오기 시작');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📄 페이지: $page, 제한: $limit');

    // 웹 환경에서 CORS 문제 경고
    if (kIsWeb) {
      print('⚠️  [쿠팡] 웹 환경 감지됨');
      print('💡 [쿠팡] 웹에서 직접 스크래핑은 CORS 정책으로 제한될 수 있습니다.');
      print('💡 [쿠팡] 해결 방법:');
      print('   1. 백엔드 프록시 서버 사용 (권장)');
      print('   2. Chrome 실행 시 --disable-web-security 플래그 사용 (개발 전용)');
      print('   3. 모바일/데스크톱 앱으로 실행');
    }

    try {
      // 쿠팡 베스트100 페이지 URL (offset과 limit은 파싱 단계에서 사용)
      final url = 'https://www.coupang.com/np/best100/bestseller';

      print('🌐 [쿠팡] 페이지 URL: $url');
      print('⏳ [쿠팡] HTTP 요청 시작...');

      // 403 오류 방지를 위한 더 나은 헤더 설정
      final headers = {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Sec-Fetch-User': '?1',
        'Cache-Control': 'max-age=0',
        'Referer': 'https://www.coupang.com/',
        'Origin': 'https://www.coupang.com',
        'DNT': '1',
      };

      print('📋 [쿠팡] 요청 헤더 설정 완료');

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      print('✅ [쿠팡] HTTP 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final html = response.body;
        print('📦 [쿠팡] HTML 길이: ${html.length} bytes');
        print('🔍 [쿠팡] HTML 파싱 시작...');
        final products = await _parseCoupangHtml(html, offset, limit);
        print('✅ [쿠팡] 파싱 완료! 상품 수: ${products.length}개');
        if (products.isNotEmpty) {
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          return products;
        } else {
          print('⚠️  [쿠팡] 파싱된 상품이 없습니다.');
        }
      } else if (response.statusCode == 403) {
        print('❌ [쿠팡] 403 Forbidden - 서버가 요청을 차단했습니다.');
        if (kIsWeb) {
          print('💡 [쿠팡] 웹 환경에서 403 오류는 CORS 정책 때문일 수 있습니다.');
          print('💡 [쿠팡] 해결 방법:');
          print('   1. 백엔드 프록시 서버 구축 (가장 안정적)');
          print(
            '   2. Chrome 실행: flutter run -d chrome --web-browser-flag="--disable-web-security"',
          );
          print('   3. 모바일/데스크톱 앱으로 실행');
        } else {
          print('💡 [쿠팡] 서버가 봇 요청을 차단했습니다.');
        }
      } else if (response.statusCode == 404) {
        print('❌ [쿠팡] 404 Not Found - 페이지를 찾을 수 없습니다.');
        print('💡 [쿠팡] URL이 변경되었거나 접근할 수 없습니다.');
      } else {
        print('❌ [쿠팡] HTTP 응답 오류: ${response.statusCode}');
        if (response.statusCode == 429) {
          print('⚠️  [쿠팡] 요청이 너무 많습니다. 잠시 후 다시 시도하세요.');
        }
      }
    } catch (e) {
      print('❌ [쿠팡] 스크래핑 오류: $e');
      if (kIsWeb && e.toString().contains('CORS') ||
          e.toString().contains('XMLHttpRequest')) {
        print('💡 [쿠팡] CORS 오류 감지됨');
        print('💡 [쿠팡] 웹에서 직접 스크래핑은 브라우저 보안 정책으로 제한됩니다.');
        print('💡 [쿠팡] 해결 방법:');
        print('   1. 백엔드 프록시 서버 구축 (권장)');
        print(
          '   2. Chrome 실행: flutter run -d chrome --web-browser-flag="--disable-web-security"',
        );
        print('   3. 모바일/데스크톱 앱으로 실행');
      }
      print('스택 트레이스: ${StackTrace.current}');
    }

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    // 실패 시 빈 리스트 반환
    return [];
  }

  // 실제 네이버 쇼핑 상품 가져오기 (API 또는 스크래핑)
  Future<List<Product>> getNaverShoppingProducts({
    int page = 0,
    int offset = 0,
    int limit = 10,
  }) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🛍️  [네이버 쇼핑] 상품 데이터 가져오기 시작');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📄 페이지: $page, 오프셋: $offset, 제한: $limit');

    // 먼저 API 시도 (API 키가 설정된 경우)
    // 웹 환경에서는 CORS 문제로 API 직접 호출이 불가하므로 스크래핑으로 바로 넘어갑니다.
    if (!kIsWeb && _naverClientId.isNotEmpty && _naverClientSecret.isNotEmpty) {
      print('🔑 [네이버 쇼핑] API 키 확인됨, API 호출 시도...');
      try {
        final keywords = [
          '노트북',
          '스마트폰',
          '이어폰',
          '키보드',
          '마우스',
          '모니터',
          '태블릿',
          '스피커',
          '헤드폰',
          '웹캠',
        ];
        final keyword = keywords[page % keywords.length];

        final start = (page * limit) + 1;
        final display = limit > 100 ? 100 : limit;

        final queryParams = {
          'query': keyword,
          'display': display.toString(),
          'start': start.toString(),
          'sort': 'asc',
        };

        final uri = Uri.parse(
          _naverApiBaseUrl,
        ).replace(queryParameters: queryParams);

        print(
          '🌐 [네이버 쇼핑] API URL: ${uri.toString().substring(0, uri.toString().length > 100 ? 100 : uri.toString().length)}...',
        );
        print('⏳ [네이버 쇼핑] API 요청 시작...');

        final response = await http
            .get(
              uri,
              headers: {
                'X-Naver-Client-Id': _naverClientId,
                'X-Naver-Client-Secret': _naverClientSecret,
              },
            )
            .timeout(const Duration(seconds: 10));

        print('✅ [네이버 쇼핑] API 응답 상태: ${response.statusCode}');

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          print('📦 [네이버 쇼핑] API 응답 데이터 파싱 중...');
          final products = _parseNaverShoppingApi(jsonData);
          print('✅ [네이버 쇼핑] API로 ${products.length}개 상품 가져옴');
          if (products.isNotEmpty) {
            print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            return products;
          }
        } else {
          print('❌ [네이버 쇼핑] API 오류: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ [네이버 쇼핑] API 오류: $e');
      }
    } else if (kIsWeb) {
      print('⚠️  [네이버 쇼핑] 웹 환경에서는 CORS 정책으로 인해 API를 사용할 수 없습니다.');
      print('💡 [네이버 쇼핑] 스크래핑으로 전환합니다.');
      print('💡 [네이버 쇼핑] 안정적인 운영을 위해서는 백엔드 프록시 서버를 통한 API 호출을 권장합니다.');
    } else {
      print('⚠️  [네이버 쇼핑] API 키 미설정, 스크래핑으로 전환...');
    }

    // API 실패 시 네이버 쇼핑 메인/베스트 페이지 스크래핑 시도
    try {
      // 네이버 쇼핑 베스트 페이지 URL
      final url = 'https://shopping.naver.com/ns/home/best';

      print('🌐 [네이버 쇼핑] 베스트 페이지 URL: $url');
      print('⏳ [네이버 쇼핑] HTTP 요청 시작...');

      // 403 오류 방지를 위한 더 나은 헤더 설정
      final headers = {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Sec-Fetch-User': '?1',
        'Cache-Control': 'max-age=0',
        'Referer': 'https://shopping.naver.com/',
        'Origin': 'https://shopping.naver.com',
        'DNT': '1',
      };

      print('📋 [네이버 쇼핑] 요청 헤더 설정 완료');

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      print('✅ [네이버 쇼핑] HTTP 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final html = response.body;
        print('📦 [네이버 쇼핑] HTML 길이: ${html.length} bytes');
        print('🔍 [네이버 쇼핑] HTML 파싱 시작...');
        final products = _parseNaverShoppingHtml(html, offset, limit);
        print('✅ [네이버 쇼핑] 파싱 완료! 상품 수: ${products.length}개');
        if (products.isNotEmpty) {
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          return products;
        } else {
          print('⚠️  [네이버 쇼핑] 파싱된 상품이 없습니다.');
        }
      } else if (response.statusCode == 403) {
        print('❌ [네이버 쇼핑] 403 Forbidden - 서버가 요청을 차단했습니다.');
        if (kIsWeb) {
          print('💡 [네이버 쇼핑] 웹 환경에서 403 오류는 CORS 정책 때문일 수 있습니다.');
          print('💡 [네이버 쇼핑] 해결 방법:');
          print('   1. 네이버 쇼핑 API 키 설정 (가장 권장)');
          print('   2. 백엔드 프록시 서버 구축');
          print(
            '   3. Chrome 실행: flutter run -d chrome --web-browser-flag="--disable-web-security"',
          );
        } else {
          print('💡 [네이버 쇼핑] 해결 방법:');
          print('   1. 네이버 쇼핑 API 키 설정 (권장)');
          print('   2. 백엔드 서버를 통해 스크래핑');
        }
      } else if (response.statusCode == 404) {
        print('❌ [네이버 쇼핑] 404 Not Found - 페이지를 찾을 수 없습니다.');
        print('💡 [네이버 쇼핑] URL이 변경되었거나 접근할 수 없습니다.');
      } else {
        print('❌ [네이버 쇼핑] HTTP 응답 오류: ${response.statusCode}');
        if (response.statusCode == 429) {
          print('⚠️  [네이버 쇼핑] 요청이 너무 많습니다. 잠시 후 다시 시도하세요.');
        }
      }
    } catch (e) {
      print('❌ [네이버 쇼핑] 스크래핑 오류: $e');
      if (kIsWeb &&
          (e.toString().contains('CORS') ||
              e.toString().contains('XMLHttpRequest'))) {
        print('💡 [네이버 쇼핑] CORS 오류 감지됨');
        print('💡 [네이버 쇼핑] 웹에서 직접 스크래핑은 브라우저 보안 정책으로 제한됩니다.');
        print('💡 [네이버 쇼핑] 해결 방법:');
        print('   1. 네이버 쇼핑 API 키 설정 (가장 권장)');
        print('   2. 백엔드 프록시 서버 구축');
        print(
          '   3. Chrome 실행: flutter run -d chrome --web-browser-flag="--disable-web-security"',
        );
      }
      print('스택 트레이스: ${StackTrace.current}');
    }

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    // 모든 방법 실패 시 빈 리스트 반환 (Mock 데이터 사용 안 함)
    return [];
  }

  // 네이버 쇼핑 HTML 파싱 (실제 검색 페이지)
  List<Product> _parseNaverShoppingHtml(String html, int offset, int limit) {
    final products = <Product>[];
    try {
      print('📄 [네이버 쇼핑] HTML 문서 파싱 중...');
      final document = html_parser.parse(html);

      // 네이버 쇼핑 베스트 페이지 상품 선택자
      final productElements = document.querySelectorAll(
        'li[class^="bestProductCardResponsive_best_product_card_responsive"]',
      );

      print('🔍 [네이버 쇼핑] 찾은 상품 요소 수: ${productElements.length}개');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      int processedCount = 0;
      for (var element
          in productElements
              .skip(offset)
              .take(limit > 0 ? limit : productElements.length)) {
        processedCount++;
        print('📦 [네이버 쇼핑] 상품 #$processedCount 처리 중...');
        try {
          // 상품명 (더 많은 선택자 시도)
          String title = '';
          final titleSelectors = [
            '.product_title',
            'div[class^="bestProductCardResponsive_title"]',
          ];

          for (var selector in titleSelectors) {
            final titleElement = element.querySelector(selector);
            title = titleElement?.text.trim() ?? '';
            if (title.isNotEmpty) break;
          }

          title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
          title = title.replaceAll(RegExp(r'<[^>]*>'), '').trim();

          if (title.isEmpty || title.length < 2) {
            print('  ⚠️  상품명 없음, 스킵');
            continue;
          }

          print(
            '  📝 상품명: ${title.length > 50 ? "${title.substring(0, 50)}..." : title}',
          );

          // 이미지 - 상품 요소 내에서만 찾기 (더 정확한 선택자)
          String imageUrl = '';
          print('  🖼️  썸네일 이미지 추출 중...');

          final imgElement = element.querySelector(
            'img[class^="bestProductCardResponsive_image"]',
          );

          if (imgElement != null) {
            final imgAttributes = [
              'src',
              'data-img-src',
              'data-src',
              'data-lazy-src',
              'data-original',
              'data-lazy',
            ];

            for (var attr in imgAttributes) {
              imageUrl = imgElement.attributes[attr] ?? '';
              if (imageUrl.isNotEmpty &&
                  !imageUrl.contains('placeholder') &&
                  !imageUrl.contains('blank') &&
                  !imageUrl.contains('loading')) {
                print('  ✅ 이미지 속성 "$attr"에서 찾음');
                break;
              }
            }
          }

          // 이미지 URL 정규화
          if (imageUrl.isNotEmpty) {
            final originalUrl = imageUrl;
            if (imageUrl.startsWith('//')) {
              imageUrl = 'https:$imageUrl';
            } else if (imageUrl.startsWith('/')) {
              imageUrl = 'https://shopping.naver.com$imageUrl';
            } else if (!imageUrl.startsWith('http')) {
              imageUrl = 'https:$imageUrl';
            }
            if (originalUrl != imageUrl) {
              print('  🔄 이미지 URL 정규화: $originalUrl → $imageUrl');
            }
          }

          // 유효하지 않은 이미지 URL 필터링
          if (imageUrl.contains('placeholder') ||
              imageUrl.contains('blank') ||
              imageUrl.contains('loading') ||
              imageUrl.isEmpty) {
            imageUrl = '';
            print('  ⚠️  유효하지 않은 이미지 URL, 필터링됨');
          } else {
            print(
              '  ✅ 썸네일 URL: ${imageUrl.length > 60 ? "${imageUrl.substring(0, 60)}..." : imageUrl}',
            );
          }

          // 가격
          final priceElement = element.querySelector(
            'span[class^="priceResponsive_number"]',
          );
          final priceText = priceElement?.text.trim() ?? '';
          final price = _parsePrice(priceText);

          // 상품 링크 (상세 페이지)
          final productId = element.id;

          print('  🔗 상세 페이지 URL 추출 중...');
          final linkElement = element.querySelector(
            'a[class^="bestProductCardResponsive_link"]',
          );
          String productUrl = linkElement?.attributes['href'] ?? '';
          if (productUrl.isEmpty) {
            productUrl = element.querySelector('a')?.attributes['href'] ?? '';
          }

          if (productUrl.isNotEmpty && !productUrl.startsWith('http')) {
            final originalUrl = productUrl;
            if (productUrl.startsWith('//')) {
              productUrl = 'https:$productUrl';
            } else if (productUrl.startsWith('/')) {
              productUrl = 'https://shopping.naver.com$productUrl';
            }
            if (originalUrl != productUrl) {
              print('  🔄 상세 페이지 URL 정규화: $originalUrl → $productUrl');
            }
          }

          if (productUrl.isNotEmpty) {
            print(
              '  ✅ 상세 페이지 URL: ${productUrl.length > 60 ? "${productUrl.substring(0, 60)}..." : productUrl}',
            );
          } else {
            print('  ⚠️  상세 페이지 URL 없음');
          }

          // URL에서 쿼리 파라미터 제거하여 정규화
          if (productUrl.contains('?')) {
            productUrl = productUrl.split('?')[0];
          }

          // 리뷰 수 및 별점
          print('  ⭐ 리뷰/별점 추출 중...');
          final reviewElement = element.querySelector(
            'span[class^="bestProductCardResponsive_review_"]',
          );
          final reviewText = reviewElement?.text.trim() ?? '';
          final reviewCount = _parsePrice(reviewText);

          final ratingElement = element.querySelector(
            'span[class^="bestProductCardResponsive_rating__"]',
          );
          final ratingText =
              ratingElement?.text.trim().replaceAll('별점', '') ?? '0.0';
          final rating = double.tryParse(ratingText) ?? 0.0;

          if (reviewCount > 0) {
            print('  ✅ 리뷰 수: $reviewCount');
          }
          if (rating > 0) {
            print('  ✅ 별점: $rating');
          }

          if (title.isNotEmpty && price > 0) {
            // 이미지가 없으면 스킵 (실제 상품 이미지만 사용)
            if (imageUrl.isEmpty) {
              print('  ❌ 이미지 없음, 상품 스킵');
              continue;
            }

            final originalPriceElement = element.querySelector(
              'span[class^="priceResponsive_original_price__"]',
            );
            final originalPrice = _parsePrice(
              originalPriceElement?.text.trim() ?? '',
            );

            final basePrice = originalPrice > 0
                ? originalPrice
                : (price * 1.1).round();
            final priceChange = basePrice > 0
                ? ((price - basePrice) / basePrice * 100)
                : 0.0;

            print(
              '  💰 가격: ${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}원',
            );
            print('  ✅ [네이버 쇼핑] 상품 추가 완료!');
            print('  ──────────────────────────────────────');

            products.add(
              Product(
                id: productId.isNotEmpty
                    ? 'naver_$productId'
                    : 'naver_$productUrl',
                title: title,
                imageUrl: imageUrl, // 실제 이미지만 사용
                currentPrice: price,
                averagePrice: basePrice,
                priceChangePercent: priceChange,
                source: 'naver',
                isLowestPrice: priceChange < -20,
                productUrl: productUrl.isNotEmpty ? productUrl : null,
                reviewCount: reviewCount,
                averageRating: rating,
              ),
            );
          }
        } catch (e) {
          print('  ❌ [네이버 쇼핑] 상품 파싱 오류: $e');
          continue;
        }
      }
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ [네이버 쇼핑] 총 ${products.length}개 상품 파싱 완료');
    } catch (e) {
      print('❌ [네이버 쇼핑] HTML 파싱 오류: $e');
    }

    return products;
  }

  // 네이버 쇼핑 API 응답 파싱
  List<Product> _parseNaverShoppingApi(Map<String, dynamic> jsonData) {
    final products = <Product>[];
    print('📦 [네이버 쇼핑 API] JSON 데이터 파싱 시작...');

    try {
      final items = jsonData['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) {
        print('⚠️  [네이버 쇼핑 API] items가 비어있습니다.');
        return products;
      }

      print('🔍 [네이버 쇼핑 API] 총 ${items.length}개 아이템 발견');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      int processedCount = 0;
      for (var item in items) {
        processedCount++;
        print('📦 [네이버 쇼핑 API] 상품 #$processedCount 처리 중...');
        try {
          final title = (item['title'] as String? ?? '')
              .replaceAll('<b>', '')
              .replaceAll('</b>', '')
              .trim();

          if (title.isEmpty) {
            print('  ⚠️  상품명 없음, 스킵');
            continue;
          }

          print(
            '  📝 상품명: ${title.length > 50 ? "${title.substring(0, 50)}..." : title}',
          );

          // 네이버 API의 image 필드는 이미 상세 페이지의 썸네일 이미지입니다
          print('  🖼️  썸네일 이미지 추출 중...');
          String imageUrl = item['image'] as String? ?? '';

          if (imageUrl.isNotEmpty) {
            print(
              '  ✅ 썸네일 URL: ${imageUrl.length > 60 ? "${imageUrl.substring(0, 60)}..." : imageUrl}',
            );
          } else {
            print('  ⚠️  썸네일 URL 없음');
          }

          print('  🔗 상세 페이지 URL 추출 중...');
          final link = item['link'] as String? ?? '';

          // 네이버 API의 link는 인코딩된 URL이므로 디코딩 필요
          String decodedLink = link;
          try {
            if (link.contains('openapi.naver.com/l?')) {
              print('  🔄 인코딩된 URL 디코딩 중...');
              // 네이버 API의 리다이렉트 URL 디코딩
              final uri = Uri.parse(link);
              final queryParams = uri.queryParameters;
              if (queryParams.containsKey('url')) {
                decodedLink = queryParams['url'] ?? link;
                print(
                  '  ✅ 디코딩 완료: ${decodedLink.length > 60 ? "${decodedLink.substring(0, 60)}..." : decodedLink}',
                );
              }
            } else {
              print(
                '  ✅ 상세 페이지 URL: ${decodedLink.length > 60 ? "${decodedLink.substring(0, 60)}..." : decodedLink}',
              );
            }
          } catch (e) {
            print('  ❌ URL 디코딩 오류: $e');
          }

          // URL에서 쿼리 파라미터 제거하여 정규화
          if (decodedLink.contains('?')) {
            decodedLink = decodedLink.split('?')[0];
          }

          final lprice = item['lprice'] as String? ?? '0';
          final hprice = item['hprice'] as String? ?? '0';
          final productId = item['productId'] as String? ?? '';
          final reviewCountStr = item['reviewCount'] as String? ?? '0';

          final reviewCount = int.tryParse(reviewCountStr) ?? 0;

          final currentPrice = int.tryParse(lprice) ?? 0;
          final highPrice = int.tryParse(hprice) ?? 0;

          if (currentPrice == 0) {
            print('  ⚠️  가격 없음, 스킵');
            continue;
          }

          // 평균 가격 계산 (최저가와 최고가의 평균, 또는 현재 가격의 110%)
          final averagePrice = highPrice > 0
              ? ((currentPrice + highPrice) ~/ 2)
              : (currentPrice * 1.1).round();

          final priceChange =
              ((currentPrice - averagePrice) / averagePrice * 100);

          print(
            '  💰 가격: ${currentPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}원',
          );
          if (reviewCount > 0) {
            print('  ✅ 리뷰 수: $reviewCount');
          }

          print('  ✅ [네이버 쇼핑 API] 상품 추가 완료!');
          print('  ──────────────────────────────────────');

          products.add(
            Product(
              id: 'naver_$productId',
              title: title,
              // 네이버 API의 image 필드는 이미 상세 페이지의 썸네일 이미지입니다
              imageUrl: imageUrl.isNotEmpty
                  ? imageUrl
                  : 'https://via.placeholder.com/200',
              currentPrice: currentPrice,
              averagePrice: averagePrice,
              priceChangePercent: priceChange,
              source: 'naver',
              isLowestPrice: priceChange < -20,
              productUrl: decodedLink.isNotEmpty
                  ? decodedLink
                  : null, // 상세 페이지 URL
              reviewCount: reviewCount,
              averageRating: 0.0, // API는 별점 정보를 제공하지 않음
            ),
          );
        } catch (e) {
          print('  ❌ [네이버 쇼핑 API] 상품 파싱 오류: $e');
          continue;
        }
      }

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ [네이버 쇼핑 API] 총 ${products.length}개 상품 파싱 완료');
    } catch (e) {
      print('❌ [네이버 쇼핑 API] JSON 파싱 오류: $e');
    }

    return products;
  }

  // 쿠팡 HTML 파싱 (실제 메인 페이지 구조)
  Future<List<Product>> _parseCoupangHtml(
    String html,
    int offset,
    int limit,
  ) async {
    final products = <Product>[];
    try {
      print('📄 [쿠팡] HTML 문서 파싱 중...');
      final document = html_parser.parse(html);

      // 쿠팡 실제 상품 리스트 선택자 (다양한 선택자 시도)
      final productElements = document.querySelectorAll(
        'li.baby-product, '
        'li.search-product, '
        '.search-product-wrap-item, '
        'ul#productList > li, '
        '.baby-product-wrap, '
        '[data-product-id], '
        '.baby-product-item, '
        'dl.search-product-wrap, '
        'div[class*="product"], '
        'li[class*="product"], ' // 일반적인 상품 리스트 아이템
        'div.today-discovery-product-item', // 메인 페이지 '오늘의 발견' 상품
      );

      print('🔍 [쿠팡] 찾은 상품 요소 수: ${productElements.length}개');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      int processedCount = 0;
      for (var element
          in productElements
              .skip(offset)
              .take(limit > 0 ? limit : productElements.length)) {
        processedCount++;
        print('📦 [쿠팡] 상품 #$processedCount 처리 중...');
        try {
          // 상품명 (더 많은 선택자 시도)
          String title = '';
          final titleSelectors = [
            '.name',
            '.product-name',
            'a[data-product-id]',
            '.baby-product-name',
            '[class*="name"]',
            'dt.name',
            '.product-title',
            'strong.name',
            'a.name',
          ];

          for (var selector in titleSelectors) {
            final titleElement = element.querySelector(selector);
            title = titleElement?.text.trim() ?? '';
            if (title.isNotEmpty) break;
          }

          if (title.isEmpty) {
            // 링크에서 상품명 추출
            final linkElement = element.querySelector('a');
            title = linkElement?.text.trim() ?? '';
          }

          title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (title.isEmpty || title.length < 2) {
            print('  ⚠️  상품명 없음, 스킵');
            continue;
          }

          print(
            '  📝 상품명: ${title.length > 50 ? "${title.substring(0, 50)}..." : title}',
          );

          // 이미지 - 상품 요소 내에서만 찾기 (더 정확한 선택자)
          String imageUrl = '';
          print('  🖼️  썸네일 이미지 추출 중...');

          // 먼저 상품 이미지 영역 내에서 찾기
          final imageContainer = element.querySelector(
            '.product-image, .product_img, .thumb, .thumbnail, .baby-product-image, [class*="image"], [class*="img"]',
          );

          final imgElement =
              imageContainer?.querySelector('img') ??
              element.querySelector('img');

          if (imgElement != null) {
            // 다양한 이미지 속성 시도
            final imgAttributes = [
              'src',
              'data-img-src',
              'data-src',
              'data-lazy-src',
              'data-original',
              'data-lazy',
            ];

            for (var attr in imgAttributes) {
              imageUrl = imgElement.attributes[attr] ?? '';
              if (imageUrl.isNotEmpty &&
                  !imageUrl.contains('placeholder') &&
                  !imageUrl.contains('blank') &&
                  !imageUrl.contains('loading') &&
                  !imageUrl.contains('1x1')) {
                print('  ✅ 이미지 속성 "$attr"에서 찾음');
                break;
              }
            }
          }

          // 이미지 URL이 없으면 다른 방법 시도
          if (imageUrl.isEmpty) {
            print('  🔍 이미지 컨테이너에서 추가 검색...');
            final dataSrc = element.querySelector('[data-img-src], [data-src]');
            imageUrl =
                dataSrc?.attributes['data-img-src'] ??
                dataSrc?.attributes['data-src'] ??
                '';
          }

          // 이미지 URL 정규화
          if (imageUrl.isNotEmpty) {
            final originalUrl = imageUrl;
            if (imageUrl.startsWith('//')) {
              imageUrl = 'https:$imageUrl';
            } else if (imageUrl.startsWith('/')) {
              imageUrl = '$_coupangBaseUrl$imageUrl';
            } else if (!imageUrl.startsWith('http')) {
              imageUrl = 'https:$imageUrl';
            }
            if (originalUrl != imageUrl) {
              print('  🔄 이미지 URL 정규화: $originalUrl → $imageUrl');
            }
          }

          // 유효하지 않은 이미지 URL 필터링
          if (imageUrl.contains('placeholder') ||
              imageUrl.contains('blank') ||
              imageUrl.contains('loading') ||
              imageUrl.contains('1x1') ||
              imageUrl.isEmpty) {
            imageUrl = '';
            print('  ⚠️  유효하지 않은 이미지 URL, 필터링됨');
          } else {
            print(
              '  ✅ 썸네일 URL: ${imageUrl.length > 60 ? "${imageUrl.substring(0, 60)}..." : imageUrl}',
            );
          }

          // 가격 (더 많은 선택자 시도)
          String priceText = '';
          final priceSelectors = [
            '.price-value',
            '.price',
            '.product-price',
            '[class*="price"]',
            '.price-value strong',
            'strong.price-value',
            '.cost',
            'em.price',
          ];

          for (var selector in priceSelectors) {
            final priceElement = element.querySelector(selector);
            priceText = priceElement?.text.trim() ?? '';
            if (priceText.isNotEmpty) break;
          }

          if (priceText.isEmpty) {
            // 가격이 여러 요소로 나뉘어 있을 수 있음
            final priceElements = element.querySelectorAll('[class*="price"]');
            priceText = priceElements.map((e) => e.text.trim()).join('');
          }

          final price = _parsePrice(priceText);
          if (price == 0) {
            print('가격 없음, 스킵: $title');
            continue;
          }

          // 상품 링크 (상세 페이지)
          // 상품 ID 추출을 위해 먼저 처리
          final idElement = element.querySelector('a[data-product-id]');
          final productId = idElement?.attributes['data-product-id'] ?? '';

          print('  🔗 상세 페이지 URL 추출 중...');
          final linkElement =
              element.querySelector(
                'a.search-product-link',
              ) ?? // BEST100 페이지의 기본 링크 선택자
              element.querySelector('a[href*="/products/"]') ??
              element.querySelector('a[href*="coupang.com"]') ??
              element.querySelector('a');
          String productUrl = linkElement?.attributes['href'] ?? '';
          if (productUrl.isNotEmpty) {
            final originalUrl = productUrl;
            if (productUrl.startsWith('//')) {
              productUrl = 'https:$productUrl';
            } else if (productUrl.startsWith('/')) {
              productUrl = '$_coupangBaseUrl$productUrl';
            } else {
              productUrl = '$_coupangBaseUrl/$productUrl';
            }
            if (originalUrl != productUrl) {
              print('  🔄 상세 페이지 URL 정규화: $originalUrl → $productUrl');
            }
          }

          if (productUrl.isNotEmpty) {
            print(
              '  ✅ 상세 페이지 URL: ${productUrl.length > 60 ? "${productUrl.substring(0, 60)}..." : productUrl}',
            );
          } else {
            print('  ⚠️  상세 페이지 URL 없음');
          }

          // URL에서 쿼리 파라미터 제거하여 정규화
          if (productUrl.contains('?')) {
            productUrl = productUrl.split('?')[0];
          }

          if (productUrl.isEmpty) {
            print('  ⚠️  상세 페이지 URL 없음, 상품 스킵');
            continue;
          }

          // 로켓배송 확인
          final isRocket =
              element.text.contains('로켓배송') ||
              element.text.contains('로켓직구') ||
              element.querySelector('.badge-rocket, .rocket') != null;

          // 리뷰 수 및 별점
          print('  ⭐ 리뷰/별점 추출 중...');
          int reviewCount = 0;
          double rating = 0.0;

          // 리뷰 수
          final reviewElement = element.querySelector('.rating-total-count');
          if (reviewElement != null) {
            reviewCount = _parsePrice(reviewElement.text);
            print('  ✅ 리뷰 수: $reviewCount');
          }

          // 별점 (width %로 계산)
          final ratingSelectors = [
            '.star-rating .rating', // 기존 선택자
            '.rating-star .rating', // 새로운 선택자
          ];
          for (var selector in ratingSelectors) {
            final ratingElement = element.querySelector(selector);
            if (ratingElement != null) {
              final style = ratingElement.attributes['style'] ?? '';
              final match = RegExp(r'width:\s*(\d+\.?\d*)%').firstMatch(style);
              if (match != null) {
                final widthPercent =
                    double.tryParse(match.group(1) ?? '0') ?? 0.0;
                rating = widthPercent / 20.0; // 100% -> 5.0점
                print('  ✅ 별점: ${rating.toStringAsFixed(1)}');
                if (rating > 0) break; // 유효한 값을 찾으면 중단
              }
            }
          }

          if (title.isNotEmpty && price > 0) {
            // 이미지가 없으면 스킵 (실제 상품 이미지만 사용)
            if (imageUrl.isEmpty) {
              print('  ❌ 이미지 없음, 상품 스킵');
              continue;
            }

            final basePrice = (price * 1.1).round(); // 평균 가격 추정 (현재 가격의 110%)
            final priceChange = ((price - basePrice) / basePrice * 100);

            print(
              '  💰 가격: ${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}원',
            );
            print('  ✅ [쿠팡] 상품 추가 완료!');
            print('  ──────────────────────────────────────');

            products.add(
              Product(
                id: productId.isNotEmpty
                    ? 'coupang_$productId'
                    : 'coupang_$productUrl',
                title: title,
                imageUrl: imageUrl,
                currentPrice: price,
                averagePrice: basePrice,
                priceChangePercent: priceChange,
                source: 'coupang',
                isRocketDelivery: isRocket,
                isLowestPrice: priceChange < -20,
                productUrl: productUrl,
                reviewCount: reviewCount,
                averageRating: rating,
              ),
            );
          }
        } catch (e) {
          print('  ❌ [쿠팡] 상품 파싱 오류: $e');
          continue;
        }
      }
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ [쿠팡] 총 ${products.length}개 상품 파싱 완료');
    } catch (e) {
      print('❌ [쿠팡] HTML 파싱 오류: $e');
    }

    return products;
  }

  // 가격 텍스트에서 숫자 추출
  int _parsePrice(String priceText) {
    if (priceText.isEmpty) return 0;

    // 숫자만 추출
    final priceStr = priceText.replaceAll(RegExp(r'[^\d]'), '');
    if (priceStr.isEmpty) return 0;

    return int.tryParse(priceStr) ?? 0;
  }

  List<Product> _generateMockProducts(
    String source,
    int startIndex,
    int count,
  ) {
    final categories = ['식품', '생활용품', '가전/디지털', '뷰티', '출산/유아', '주방용품', '패션의류'];
    final products = <Product>[];

    final productNames = [
      'SKY 핏 페블 무선이어폰, 세라믹화이트',
      '네티스 기가비트 8포트 스위칭허브',
      '코리아나 앰플엔 히알루론샷 토너',
      '아이코닉 2026 더 플래너 M 위클리 다이어리',
      '아로마티카 로즈마리 루트 인핸서 두피 에센스',
      '트립몽 와플 확장형 캐리어',
      '네오플램 인덕션 대니쉬 멀티 케틀팟',
      '아로마티카 시더우드 에센셜 오일',
      '듀벨 정수키트 프로키트용 중형 리필필터',
      '브이티코스메틱 리들샷 립 플럼퍼 엑스퍼트',
      '육식토끼 닭가슴살 150g 3종 혼합',
      '빼바 소프트 크런치 프로틴바 카카오',
      '비비고 남도 떡갈비',
      '홀리데이즈 콘드로이친 3000',
      '한예지 프리미어 3겹 순수 천연펄프 롤 화장지',
      '소니 알파 렌즈 SEL70200GM2',
      '가민 포러너 965 스마트워치',
      '지오바니 50:50 발란스 컨디셔너',
      '다슈 데일리 아크네 쿨링 바디워시',
      '달리프 베러 루트 탈모 브러쉬 스칼프 두피 앰플',
    ];

    for (int i = 0; i < count; i++) {
      final index = (startIndex + i) % productNames.length;
      final basePrice = 10000 + (index * 5000) + (i * 1000);
      final priceChange = -30.0 + (i * 3.0); // -30% ~ 0% 사이
      final currentPrice = (basePrice * (1 + priceChange / 100)).round();

      products.add(
        Product(
          id: '${source}_${startIndex + i}',
          title: productNames[index],
          imageUrl: 'https://picsum.photos/200/200?random=${startIndex + i}',
          currentPrice: currentPrice,
          averagePrice: basePrice,
          priceChangePercent: priceChange,
          source: source,
          category: categories[i % categories.length],
          isRocketDelivery: i % 3 == 0,
          isLowestPrice: priceChange < -20,
          productUrl: source == 'coupang'
              ? '$_coupangBaseUrl/products/${startIndex + i}'
              : '$_naverShoppingBaseUrl/products/${startIndex + i}',
        ),
      );
    }

    return products;
  }
}
