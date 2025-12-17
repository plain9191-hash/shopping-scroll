import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../widgets/category_selector.dart';
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

  final Map<String, String> _coupangCategories = {
    '전체': '',
    '패션의류/잡화': '564553',
    '뷰티': '176422',
    '출산/유아동': '221834',
    '식품': '194176',
    '주방용품': '185569',
    '생활용품': '115573',
    '홈인테리어': '184455',
    '가전디지털': '178155',
    '스포츠/레저': '317678',
    '자동차용품': '183960',
    '도서': '317677',
    '완구/취미': '317679',
    '문구/오피스': '317679',
    '반려/애완': '115574',
    '헬스/건강식품': '305698',
  };
  String _selectedCoupangCategoryId = '';

  List<Product> _coupangProducts = [];
  List<Product> _naverProducts = [];
  bool _isLoading = false;

  DateTime? _selectedDate;
  List<DateTime> _availableDates = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeScreen();

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Rebuild UI to show/hide category selector
        _loadProducts(); // Load products for the newly selected tab
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String _getFileName() {
    if (_selectedDate == null) return '';
    final source = _tabController.index == 0 ? 'coupang' : 'naver';
    final categoryId =
        (_tabController.index == 0) ? _selectedCoupangCategoryId : 'all';
    final date = DateFormat('yy.MM.dd').format(_selectedDate!);
    return '${source}_${categoryId}_products_dt=$date.json';
  }

  Future<void> _initializeScreen() async {
    await _loadAvailableDates();
    if (mounted) {
      setState(() {
        _selectedDate = DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day);
        if (!_availableDates.any((d) => d.isAtSameMomentAs(_selectedDate!))) {
          _availableDates.add(_selectedDate!);
          _availableDates.sort((a, b) => b.compareTo(a));
        }
      });
    }
    await _loadProducts();
  }

  Future<void> _loadAvailableDates() async {
    if (kIsWeb) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      final dates = <DateTime>{};
      final dateFormat = DateFormat('yy.MM.dd');

      for (final file in files) {
        final fileName = file.path.split('/').last;
        final parts = fileName.split('_products_dt=');
        if (parts.length == 2) {
          final dateString = parts[1].replaceAll('.json', '');
          try {
            final date = dateFormat.parse(dateString);
            dates.add(DateTime(date.year, date.month, date.day));
          } catch (e) {
            // Ignore files with invalid date format
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

  Future<void> _loadProducts() async {
    if (_selectedDate == null) return;
    if (kIsWeb) {
      await _fetchProductsFromApi();
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final fileName = _getFileName();
    final file = File('${directory.path}/$fileName');

    if (await file.exists()) {
      await _loadProductsFromFile();
    } else {
      await _fetchProductsFromApi();
    }
  }

  Future<void> _fetchProductsFromApi() async {
    if (_isLoading) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      List<Product> newProducts;
      if (_tabController.index == 0) {
        newProducts = await _productService.getCoupangProducts(
          categoryId: _selectedCoupangCategoryId,
          limit: 100,
        );
      } else {
        newProducts =
            await _productService.getNaverShoppingProducts(limit: 100);
      }

      final uniqueProducts = _removeDuplicates(newProducts, []);
      uniqueProducts.sort(
        (a, b) => a.priceChangePercent.compareTo(b.priceChangePercent),
      );

      if (mounted) {
        setState(() {
          if (_tabController.index == 0) {
            _coupangProducts = uniqueProducts;
          } else {
            _naverProducts = uniqueProducts;
          }
        });
      }
      await _saveProductsToFile(uniqueProducts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('상품을 불러오는 중 오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProductsFromFile() async {
    if (kIsWeb || _selectedDate == null) return;
    if (_isLoading) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = _getFileName();
      final file = File('${directory.path}/$fileName');

      if (await file.exists()) {
        final content = await file.readAsString();
        final jsonList = jsonDecode(content) as List;
        final products =
            jsonList.map((json) => Product.fromJson(json)).toList();

        if (mounted) {
          setState(() {
            if (_tabController.index == 0) {
              _coupangProducts = products;
            } else {
              _naverProducts = products;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            if (_tabController.index == 0) _coupangProducts = [];
            if (_tabController.index == 1) _naverProducts = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '${DateFormat('MM/dd').format(_selectedDate!)} 데이터가 없습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일에서 상품을 불러오는 중 오류: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProductsToFile(List<Product> products) async {
    if (kIsWeb) return;
    if (products.isEmpty) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = _getFileName();
      if (fileName.isEmpty) return;
      
      final file = File('${directory.path}/$fileName');

      final jsonList = products.map((p) => p.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      print('✅ 상품 데이터가 파일에 저장되었습니다: ${file.path}');

      await _loadAvailableDates();
    } catch (e) {
      print('❌ 파일 저장 중 오류 발생: $e');
    }
  }

  List<Product> _removeDuplicates(
    List<Product> newProducts,
    List<Product> existingProducts,
  ) {
    final uniqueIds = <String>{};
    for (final product in existingProducts) {
      uniqueIds.add(product.id);
    }
    final uniqueProducts = <Product>[];
    for (final product in newProducts) {
      if (uniqueIds.add(product.id)) {
        uniqueProducts.add(product);
      }
    }
    return uniqueProducts;
  }

  Future<void> _selectDate(BuildContext context) async {
    if (_availableDates.isEmpty) await _loadAvailableDates();
    if (!mounted || _availableDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택 가능한 날짜가 없습니다.')),
      );
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: _availableDates.last,
      lastDate: _availableDates.first,
      selectableDayPredicate: (DateTime val) {
        return _availableDates.any(
            (d) => d.year == val.year && d.month == val.month && d.day == val.day);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: const Text('가격 변동 추적',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      color: Colors.black87)),
              centerTitle: true,
              backgroundColor: Colors.white,
              floating: true,
              pinned: true,
              elevation: 0,
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
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.normal),
                tabs: const [Tab(text: '쿠팡'), Tab(text: '네이버')],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildProductList(
                products: _coupangProducts, onRefresh: _loadProducts),
            _buildProductList(
                products: _naverProducts, onRefresh: _loadProducts),
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
              _selectedDate != null
                  ? DateFormat('yyyy.MM.dd').format(_selectedDate!)
                  : '날짜를 선택하세요',
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
          if (_tabController.index == 0)
            SliverToBoxAdapter(
              child: CategorySelector(
                categories: _coupangCategories,
                selectedCategoryId: _selectedCoupangCategoryId,
                onCategorySelected: (categoryId) {
                  setState(() => _selectedCoupangCategoryId = categoryId);
                  _loadProducts();
                },
              ),
            ),
          if (_isLoading)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(),
            ),
          _buildHeader(
            _tabController.index == 0 ? '쿠팡 BEST 100' : '네이버 인기 BEST',
          ),
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
      ),
    );
  }

  SliverToBoxAdapter _buildHeader(String title) {
    final dateString =
        _selectedDate != null ? DateFormat('yy.MM.dd').format(_selectedDate!) : '';
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            Text('가격 변동 Top 100 ($dateString 기준)',
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
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