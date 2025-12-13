import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProductService _productService = ProductService();
  final ScrollController _scrollController = ScrollController();

  List<Product> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 쿠팡 상품 10개
      final newProducts = await _productService.getCoupangProducts(
        offset: 0,
        limit: 10,
      );

      // 네이버 상품은 초기 로드 시 제외하거나, 별도 로직으로 추가할 수 있습니다.
      // 여기서는 쿠팡 베스트100 순위 로딩에 집중합니다.
      // final naverProducts = await _productService.getNaverShoppingProducts(
      //   page: 0,
      //   limit: 10,
      // );

      final uniqueProducts = _removeDuplicates(newProducts);

      // 가격 변동률 기준으로 정렬
      uniqueProducts.sort(
        (a, b) => a.priceChangePercent.compareTo(b.priceChangePercent),
      );
      setState(() {
        _products = uniqueProducts;
        _isLoading = false;
        _currentOffset = 10; // 다음 로드할 시작 순위
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('상품을 불러오는 중 오류가 발생했습니다: $e')));
      }
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 쿠팡 상품 10개
      final newProducts = await _productService.getCoupangProducts(
        offset: _currentOffset,
        limit: 10,
      );

      // 새로 불러온 상품 중 기존 목록에 없는 것만 추가
      final uniqueNewProducts = _removeDuplicates([
        ..._products,
        ...newProducts,
      ]).sublist(_products.length);

      // 가격 변동률 기준으로 정렬
      uniqueNewProducts.sort(
        (a, b) => a.priceChangePercent.compareTo(b.priceChangePercent),
      );

      setState(() {
        if (uniqueNewProducts.isEmpty) {
          _hasMore = false;
        } else {
          _products.addAll(uniqueNewProducts);
          _currentOffset += 10;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('상품을 불러오는 중 오류가 발생했습니다: $e')));
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreProducts();
    }
  }

  List<Product> _removeDuplicates(List<Product> products) {
    final uniqueIds = <String>{}; // 이미 추가된 상품 ID를 추적
    final uniqueProducts = <Product>[];
    for (final product in products) {
      // add 메서드는 Set에 요소가 성공적으로 추가되면 true를 반환
      if (uniqueIds.add(product.id)) {
        uniqueProducts.add(product);
      }
    }
    return uniqueProducts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '가격 변동 추적',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading && _products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _products = [];
                  _currentOffset = 0;
                  _hasMore = true;
                });
                await _loadInitialProducts();
              },
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // 헤더 섹션
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '지금 최저가인 상품',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '쿠팡과 네이버 쇼핑의 가격 변동을 실시간으로 추적합니다',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 상품 그리드
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index < _products.length) {
                          final product = _products[index];
                          return ProductCard(product: product);
                        }
                        return null;
                      }, childCount: _products.length),
                    ),
                  ),
                  // 로딩 인디케이터
                  if (_isLoading && _products.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  // 더 이상 없음 메시지
                  if (!_hasMore && _products.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            '모든 상품을 불러왔습니다',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
