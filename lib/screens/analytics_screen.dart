import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product_analytics.dart';
import '../services/analytics_service.dart';
import '../widgets/rank_chart.dart';

/// 소싱 분석 화면
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();

  final Map<String, String> _categories = {
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

  String _selectedCategoryId = '';
  int _selectedDays = 7;
  List<ProductAnalytics> _analytics = [];
  bool _isLoading = false;
  Set<String> _availableCategories = {};
  ProductAnalytics? _selectedProduct;

  @override
  void initState() {
    super.initState();
    _loadAvailableCategories();
  }

  Future<void> _loadAvailableCategories() async {
    final categories = await _analyticsService.getAvailableCategories();
    setState(() {
      _availableCategories = categories;
      // 첫 번째 사용 가능한 카테고리 선택
      if (categories.isNotEmpty && _selectedCategoryId.isEmpty) {
        _selectedCategoryId = categories.first;
      }
    });
    if (_selectedCategoryId.isNotEmpty) {
      _loadAnalytics();
    }
  }

  Future<void> _loadAnalytics() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final analytics = await _analyticsService.analyzeProducts(
        categoryId: _selectedCategoryId,
        recentDays: _selectedDays,
      );
      setState(() {
        _analytics = analytics;
        _selectedProduct = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('분석 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getCategoryName(String categoryId) {
    for (final entry in _categories.entries) {
      if (entry.value == categoryId) {
        return entry.key;
      }
    }
    return categoryId.isEmpty ? '전체' : categoryId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '소싱 분석',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _selectedProduct != null
                ? _buildProductDetail()
                : _buildAnalyticsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카테고리 선택
          const Text(
            '카테고리',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _availableCategories.map((categoryId) {
                final isSelected = categoryId == _selectedCategoryId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_getCategoryName(categoryId)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategoryId = categoryId);
                        _loadAnalytics();
                      }
                    },
                    selectedColor: const Color(0xFF434E78),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // 기간 선택
          const Text(
            '분석 기간',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [7, 14, 30].map((days) {
              final isSelected = days == _selectedDays;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('최근 $days일'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedDays = days);
                      _loadAnalytics();
                    }
                  },
                  selectedColor: const Color(0xFF434E78),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_analytics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '분석할 데이터가 없습니다',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '먼저 홈 화면에서 데이터를 저장해주세요',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _analytics.length,
      itemBuilder: (context, index) {
        final item = _analytics[index];
        return _buildAnalyticsCard(item, index + 1);
      },
    );
  }

  Widget _buildAnalyticsCard(ProductAnalytics item, int displayRank) {
    final numberFormat = NumberFormat('#,###');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => setState(() => _selectedProduct = item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 순위 뱃지
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: displayRank <= 3
                      ? const Color(0xFF434E78)
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$displayRank',
                  style: TextStyle(
                    color: displayRank <= 3 ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 상품 이미지
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 상품 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildInfoBadge(
                          '${item.appearanceCount}회 등장',
                          Colors.blue,
                        ),
                        const SizedBox(width: 6),
                        _buildInfoBadge(
                          '평균 ${item.averageRank.toStringAsFixed(1)}위',
                          Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${numberFormat.format(item.latestPrice)}원',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF434E78),
                      ),
                    ),
                  ],
                ),
              ),
              // 소싱 점수
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _getScoreColor(item.sourcingScore).withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      item.sourcingScore.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(item.sourcingScore),
                      ),
                    ),
                    Text(
                      '점',
                      style: TextStyle(
                        fontSize: 10,
                        color: _getScoreColor(item.sourcingScore),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 70) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  Widget _buildProductDetail() {
    final item = _selectedProduct!;
    final numberFormat = NumberFormat('#,###');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 뒤로가기 버튼
          TextButton.icon(
            onPressed: () => setState(() => _selectedProduct = null),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('목록으로'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 16),
          // 상품 정보 카드
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '현재가: ${numberFormat.format(item.latestPrice)}원',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF434E78),
                              ),
                            ),
                            if (item.productUrl != null) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () => _launchUrl(item.productUrl!),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('상품 페이지'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 소싱 점수 카드
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '소싱 점수',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildScoreItem(
                        '종합 점수',
                        item.sourcingScore.toStringAsFixed(0),
                        _getScoreColor(item.sourcingScore),
                        large: true,
                      ),
                      _buildScoreItem(
                        '등장 횟수',
                        '${item.appearanceCount}회',
                        Colors.blue,
                      ),
                      _buildScoreItem(
                        '평균 순위',
                        '${item.averageRank.toStringAsFixed(1)}위',
                        Colors.green,
                      ),
                      _buildScoreItem(
                        '안정성',
                        item.rankStability < 10 ? '높음' : '보통',
                        item.rankStability < 10 ? Colors.green : Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 가격 정보 카드
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '가격 정보',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPriceItem('최저가', numberFormat.format(item.lowestPrice)),
                      _buildPriceItem('최고가', numberFormat.format(item.highestPrice)),
                      _buildPriceItem(
                        '변동률',
                        '${item.priceVariation.toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 순위 추이 차트
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '순위 추이',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '낮을수록 좋음 (1위가 최상위)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  RankChart(rankHistory: item.rankHistory, height: 200),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 가격 추이 차트
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '가격 추이',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PriceChart(rankHistory: item.rankHistory, height: 150),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 날짜별 기록
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '날짜별 기록',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...item.rankHistory.reversed.map((h) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Text(
                              DateFormat('MM/dd').format(h.date),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: h.rank <= 10
                                    ? Colors.green.withAlpha(25)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${h.rank}위',
                                style: TextStyle(
                                  color: h.rank <= 10 ? Colors.green : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${numberFormat.format(h.price)}원',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreItem(String label, String value, Color color, {bool large = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 28 : 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
