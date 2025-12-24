import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// 앱은 읽기 전용 - 데이터 수집은 bin/fetch_data.dart 스크립트에서 수행
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../widgets/category_selector.dart';
import '../widgets/product_card.dart';
import 'analytics_tab.dart';

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

  final Map<String, Map<String, String>> _coupangCategories = {
    '전체': {'id': '', 'key': 'all'},
    '패션의류/잡화': {'id': '564553', 'key': 'fashion'},
    '뷰티': {'id': '176422', 'key': 'beauty'},
    '출산/유아동': {'id': '221834', 'key': 'baby'},
    '식품': {'id': '194176', 'key': 'food'},
    '주방용품': {'id': '185569', 'key': 'kitchen'},
    '생활용품': {'id': '115573', 'key': 'living'},
    '홈인테리어': {'id': '184455', 'key': 'interior'},
    '가전디지털': {'id': '178155', 'key': 'digital'},
    '스포츠/레저': {'id': '317678', 'key': 'sports'},
    '자동차용품': {'id': '183960', 'key': 'car'},
    '도서': {'id': '317677', 'key': 'books'},
    '완구/취미': {'id': '317679', 'key': 'toys'},
    '문구/오피스': {'id': '177195', 'key': 'office'},
    '반려/애완': {'id': '115574', 'key': 'pet'},
    '헬스/건강식품': {'id': '305698', 'key': 'health'},
  };
  String _selectedCoupangCategoryKey = 'all';

  List<Product> _coupangProducts = [];
  bool _isLoading = false;

  DateTime _selectedDate =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  List<DateTime> _availableDates = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeScreen();

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Rebuild UI
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _loadAvailableDates();
    if (mounted) {
      setState(() {
        // 가장 최신 날짜를 선택 (데이터가 있는 경우)
        if (_availableDates.isNotEmpty) {
          _selectedDate = _availableDates.first;
        }
      });
    }

    await _loadProducts();
  }

  Future<void> _loadAvailableDates() async {
    if (kIsWeb) return;
    try {
      final directory = Directory(ProductService.dataDirectoryPath);
      if (!await directory.exists()) {
        return; // No data directory, nothing to load
      }
      final files = directory.listSync();
      final dates = <DateTime>{};
      final dateFormat = DateFormat('yyyy-MM-dd');

      for (final file in files) {
        final fileName = file.path.split('/').last;
        final parts = fileName.split('_');
        if (parts.length >= 2) {
          try {
            final date = dateFormat.parse(parts[0]);
            dates.add(DateTime(date.year, date.month, date.day));
          } catch (e) {
            // Ignore files with invalid date format in their name
          }
        }
      }

      if (mounted) {
        setState(() {
          _availableDates = dates.toList();
          _availableDates.sort((a, b) => b.compareTo(a));
        });
      }
    } catch (e) {
      print('Error loading available dates: $e');
    }
  }

  bool _selectedDateIsToday() {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _loadProducts() async {
    if (_isLoading) return;
    if (_tabController.index != 0) return; // 아이템 분석 탭은 별도 로딩
    if (mounted) setState(() => _isLoading = true);

    try {
      final categoryData = _coupangCategories.values.firstWhere(
        (data) => data['key'] == _selectedCoupangCategoryKey,
        orElse: () => {'id': '', 'key': 'all'},
      );
      final products = await _productService.getCoupangProducts(
        categoryId: categoryData['id'] ?? '',
        categoryKey: _selectedCoupangCategoryKey,
        date: _selectedDate,
      );

      if (mounted) {
        setState(() {
          _coupangProducts = products;
        });
        if (products.isEmpty && !_selectedDateIsToday()) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '${DateFormat('MM/dd').format(_selectedDate)} 데이터가 없습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('상품을 불러오는 중 오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    if (kIsWeb) return;
    await _loadAvailableDates();
    if (!mounted) return;
    if (_availableDates.isEmpty) {
      // If no dates are loaded, at least allow picking today.
      final today = DateTime.now();
      _availableDates.add(DateTime(today.year, today.month, today.day));
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _availableDates.last,
      lastDate: _availableDates.first,
      selectableDayPredicate: (DateTime val) {
        return _availableDates
            .any((d) => d.year == val.year && d.month == val.month && d.day == val.day);
      },
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadProducts();
    }
  }

  Future<void> _syncToDatabase() async {
    if (_isLoading) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON 파일을 DB로 동기화합니다...')),
    );
    if (mounted) setState(() => _isLoading = true);

    try {
      await _productService.syncAllJsonToDatabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('DB 동기화 완료!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DB 동기화 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              toolbarHeight: 60,
              title: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.pets, color: Color(0xFF434E78), size: 22),
                    SizedBox(width: 6),
                    Text('하우머치',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: Colors.black87)),
                  ],
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.white,
              floating: true,
              pinned: true,
              elevation: 0,
              actions: [
                if (!kIsWeb)
                  IconButton(
                    icon: const Icon(Icons.sync),
                    tooltip: 'JSON → DB 동기화',
                    onPressed: _isLoading ? null : _syncToDatabase,
                  ),
              ],
              bottom: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: const Color(0xFF434E78),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black87,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
                tabs: const [Tab(text: 'Top 100'), Tab(text: '아이템 분석')],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildProductList(
                products: _coupangProducts, onRefresh: _loadProducts),
            const AnalyticsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('yyyy.MM.dd').format(_selectedDate),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87),
            ),
            const Icon(Icons.calendar_month_outlined, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList({
    required List<Product> products,
    required Future<void> Function() onRefresh,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildDatePicker()),
          SliverToBoxAdapter(
            child: CategorySelector(
              categories: _coupangCategories,
              selectedCategoryKey: _selectedCoupangCategoryKey,
              onCategorySelected: (categoryKey) {
                setState(() => _selectedCoupangCategoryKey = categoryKey);
                _loadProducts();
              },
            ),
          ),
          if (_isLoading && products.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _buildHeader('쿠팡 BEST 100'),
            if (products.isEmpty && !_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: Text('표시할 상품이 없습니다.',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              _buildProductGrid(products),
          ],
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildHeader(String title) {
    final dateString = DateFormat('yy.MM.dd').format(_selectedDate);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 24),
                const SizedBox(width: 6),
                Text(title,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('$dateString 기준',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isLoading ? null : _loadProducts,
                  child: Icon(
                    Icons.refresh,
                    size: 18,
                    color: _isLoading ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid(List<Product> products) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 2 : 1;

    return SliverPadding(
      padding: const EdgeInsets.all(8.0),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: crossAxisCount == 2 ? 1 / 1.5 : 1 / 1.6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index < products.length) {
              return ProductCard(product: products[index], rank: index + 1);
            }
            return null;
          },
          childCount: products.length,
        ),
      ),
    );
  }

}