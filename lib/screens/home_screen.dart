import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ProductService _productService = ProductService();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  List<Product> _coupangProducts = [];
  List<Product> _naverProducts = [];
  bool _isLoading = false;
  bool _hasMoreCoupang = true;
  bool _hasMoreNaver = true;
  int _currentCoupangOffset = 0;
  int _currentNaverOffset = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialProducts();
    // _scrollController.addListener(_onScroll); // 한 번에 100개를 로드하므로 무한 스크롤 비활성화

    // 탭 변경을 감지하여 UI를 다시 그리도록 setState 호출
    _tabController.addListener(() {
      // 탭 전환 애니메이션이 완료된 시점에 UI를 업데이트하고, 필요하면 데이터 로드
      if (!_tabController.indexIsChanging) {
        setState(() {}); // 탭 UI(헤더 등)를 올바르게 업데이트하기 위해 호출
        if (_tabController.index == 0 && _coupangProducts.isEmpty) {
          _loadInitialProducts();
        } else if (_tabController.index == 1 && _naverProducts.isEmpty) {
          _loadInitialProducts();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose(); // 컨트롤러는 여전히 dispose 필요
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialProducts() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      if (_tabController.index == 0) {
        // 쿠팡 상품 로드
        final newProducts = await _productService.getCoupangProducts(
          offset: _currentCoupangOffset,
          limit: 100, // 최대 100개 가져오기
        );
        final uniqueProducts = _removeDuplicates(newProducts, []);
        uniqueProducts.sort(
          (a, b) => a.priceChangePercent.compareTo(b.priceChangePercent),
        );
        setState(() {
          _coupangProducts = uniqueProducts;
          _currentCoupangOffset = uniqueProducts.length;
          _hasMoreCoupang = false; // 한 번에 모두 로드하므로 더 이상 없음
          _saveProductsToFile(uniqueProducts, 'coupang');
        });
      } else {
        // 네이버 상품 로드
        final newProducts = await _productService.getNaverShoppingProducts(
          offset: _currentNaverOffset,
          limit: 100, // 최대 100개 가져오기
        );
        final uniqueProducts = _removeDuplicates(newProducts, []);
        uniqueProducts.sort(
          (a, b) => a.priceChangePercent.compareTo(b.priceChangePercent),
        );
        setState(() {
          _naverProducts = uniqueProducts;
          _currentNaverOffset = uniqueProducts.length;
          _hasMoreNaver = false; // 한 번에 모두 로드하므로 더 이상 없음
          // _saveProductsToFile(uniqueProducts, 'naver'); // 필요 시 네이버 상품도 저장
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('상품을 불러오는 중 오류가 발생했습니다: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProductsToFile(
    List<Product> products,
    String source,
  ) async {
    // 웹 환경에서는 파일 저장을 지원하지 않으므로 스킵
    if (kIsWeb) {
      print('웹 환경에서는 파일 저장을 건너뜁니다.');
      return;
    }
    if (products.isEmpty) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final date = DateFormat('yy.MM.dd').format(DateTime.now());
      final fileName = '${source}_products_dt=$date.json';
      final file = File('${directory.path}/$fileName');

      final jsonList = products.map((p) => p.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      print('✅ 상품 데이터가 파일에 저장되었습니다: ${file.path}');
    } catch (e) {
      print('❌ 파일 저장 중 오류 발생: $e');
    }
  }

  // 한 번에 100개를 모두 로드하므로 추가 로드 함수는 비활성화합니다.
  Future<void> _loadMoreProducts() async {
    return;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreProducts();
    }
  }

  List<Product> _removeDuplicates(
    List<Product> newProducts,
    List<Product> existingProducts,
  ) {
    final uniqueIds = <String>{}; // 이미 추가된 상품 ID를 추적
    for (final product in existingProducts) {
      uniqueIds.add(product.id);
    }

    final uniqueProducts = <Product>[];
    for (final product in newProducts) {
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: '쿠팡'),
            Tab(text: '네이버'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductList(
            products: _coupangProducts,
            hasMore: _hasMoreCoupang,
            onRefresh: () async {
              setState(() {
                _coupangProducts = [];
                _currentCoupangOffset = 0;
                _hasMoreCoupang = true;
              });
              await _loadInitialProducts();
            },
          ),
          _buildProductList(
            products: _naverProducts,
            hasMore: _hasMoreNaver,
            onRefresh: () async {
              setState(() {
                _naverProducts = [];
                _currentNaverOffset = 0;
                _hasMoreNaver = true;
              });
              await _loadInitialProducts();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductList({
    required List<Product> products,
    required bool hasMore,
    required Future<void> Function() onRefresh,
  }) {
    if (_isLoading && products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildHeader(
            _tabController.index == 0 ? '쿠팡 BEST 100' : '네이버 인기 BEST',
          ),
          _buildProductGrid(products),
          _buildLoadingIndicator(products),
          _buildNoMoreItemsIndicator(hasMore, products),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildHeader(String title) {
    final date = DateFormat('yy.MM.dd').format(DateTime.now());
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '실시간 가격 변동을 추적하는 인기 상품 목록입니다.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '$date 기준',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid(List<Product> products) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index < products.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: ProductCard(
              product: products[index],
              rank: index + 1,
            ),
          );
        }
        return null;
      }, childCount: products.length),
    );
  }

  Widget _buildLoadingIndicator(List<Product> products) {
    if (_isLoading && products.isNotEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  Widget _buildNoMoreItemsIndicator(bool hasMore, List<Product> products) {
    if (!hasMore && products.isNotEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('모든 상품을 불러왔습니다', style: TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }
}
