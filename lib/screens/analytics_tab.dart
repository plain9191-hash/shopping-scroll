import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product_analytics.dart';
import '../services/analytics_service.dart';
import '../widgets/rank_chart.dart';

/// 아이템 분석 탭 (HomeScreen 내 탭으로 사용)
class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final AnalyticsService _analyticsService = AnalyticsService();

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
      final sortedCategories = categories.toList();
      sortedCategories.sort((a, b) {
        if (a == 'all') return -1;
        if (b == 'all') return 1;
        return a.compareTo(b);
      });
      _availableCategories = sortedCategories.toSet();

      if (categories.contains('all')) {
        _selectedCategoryId = 'all';
      } else if (categories.isNotEmpty && _selectedCategoryId.isEmpty) {
        _selectedCategoryId = sortedCategories.first;
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
    // 카테고리 키(영어)를 대문자로 표시
    if (categoryId == 'all') return 'ALL';
    if (categoryId == 'fashion') return 'FASHION';
    if (categoryId == 'beauty') return 'BEAUTY';
    if (categoryId == 'baby') return 'BABY';
    if (categoryId == 'food') return 'FOOD';
    if (categoryId == 'kitchen') return 'KITCHEN';
    if (categoryId == 'living') return 'LIVING';
    if (categoryId == 'interior') return 'INTERIOR';
    if (categoryId == 'digital') return 'DIGITAL';
    if (categoryId == 'sports') return 'SPORTS';
    if (categoryId == 'car') return 'CAR';
    if (categoryId == 'books') return 'BOOKS';
    if (categoryId == 'toys') return 'TOYS';
    if (categoryId == 'office') return 'OFFICE';
    if (categoryId == 'pet') return 'PET';
    if (categoryId == 'health') return 'HEALTH';
    return categoryId.toUpperCase();
  }

  void _showScoringInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('아이템 점수 계산법'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoSection(
                '종합 점수',
                '(등장 점수 × 0.5) + (순위 점수 × 0.5)',
                Colors.purple,
              ),
              const SizedBox(height: 16),
              _buildInfoSection(
                '등장 점수 (50%)',
                '(등장 횟수 ÷ 분석 기간) × 100\n\n'
                    '예) 7일 중 7일 등장 → 100점\n'
                    '예) 7일 중 3일 등장 → 42.9점',
                Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildInfoSection(
                '순위 점수 (50%)',
                '(1 - 평균순위 ÷ 100) × 100\n\n'
                    '예) 평균 1위 → 99점\n'
                    '예) 평균 50위 → 50점\n'
                    '예) 평균 100위 → 0점',
                Colors.green,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '높은 점수 = 매일 꾸준히 상위권에 등장하는 상품',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String description, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            height: 1.4,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 상세 화면일 때는 필터 숨기고 목록으로 헤더 표시
    if (_selectedProduct != null) {
      return Column(
        children: [
          _buildDetailHeader(),
          Expanded(child: _buildProductDetail()),
        ],
      );
    }

    return Column(
      children: [
        _buildFilters(),
        Expanded(child: _buildAnalyticsList()),
      ],
    );
  }

  Widget _buildDetailHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _selectedProduct = null),
            child: Row(
              children: [
                const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF434E78)),
                const SizedBox(width: 4),
                const Text(
                  '목록으로',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF434E78),
                    fontFamily: 'Pretendard',
                  ),
                ),
              ],
            ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '카테고리',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                  fontFamily: 'Pretendard',
                ),
              ),
              GestureDetector(
                onTap: _showScoringInfoDialog,
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '점수 계산법',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600], fontFamily: 'Pretendard'),
                    ),
                  ],
                ),
              ),
            ],
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
                      fontSize: 14,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '분석 기간',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
              fontFamily: 'Pretendard',
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
                    fontSize: 14,
                    fontFamily: 'Pretendard',
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
              style: TextStyle(color: Colors.grey[600], fontSize: 18, fontFamily: 'Pretendard'),
            ),
            const SizedBox(height: 8),
            Text(
              '먼저 Top 100 탭에서 데이터를 확인해주세요',
              style: TextStyle(color: Colors.grey[400], fontSize: 16, fontFamily: 'Pretendard'),
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selectedProduct = item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildInfoBadge(
                          '${item.appearanceCount}회 등장',
                          Colors.blue,
                        ),
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF434E78),
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ],
                ),
              ),
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
                        fontSize: 12,
                        color: _getScoreColor(item.sourcingScore),
                        fontFamily: 'Pretendard',
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
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
          fontFamily: 'Pretendard',
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
                                fontFamily: 'Pretendard',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '현재가: ${numberFormat.format(item.latestPrice)}원',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF434E78),
                                fontFamily: 'Pretendard',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _buildInfoBadge(
                                  '${item.appearanceCount}회 등장',
                                  Colors.blue,
                                ),
                                _buildInfoBadge(
                                  '평균 ${item.averageRank.toStringAsFixed(1)}위',
                                  Colors.green,
                                ),
                              ],
                            ),
                            if (item.productUrl != null) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () => _launchUrl(item.productUrl!),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('상품 페이지'),
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
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
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '아이템 점수',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Pretendard'),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: _getScoreColor(item.sourcingScore).withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            item.sourcingScore.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: _getScoreColor(item.sourcingScore),
                            ),
                          ),
                          Text(
                            '종합 점수',
                            style: TextStyle(
                              fontSize: 14,
                              color: _getScoreColor(item.sourcingScore),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '점수 상세 분석',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Pretendard'),
                  ),
                  const SizedBox(height: 12),
                  _buildScoreBreakdownRow(
                    '등장 점수',
                    item.appearanceScore,
                    0.5,
                    '${item.appearanceCount}회 / ${item.totalDays}일',
                    Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  _buildScoreBreakdownRow(
                    '순위 점수',
                    item.rankScore,
                    0.5,
                    '평균 ${item.averageRank.toStringAsFixed(1)}위',
                    Colors.green,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '계산식',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '종합 = (등장 × 0.5) + (순위 × 0.5)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          '= (${item.appearanceScore.toStringAsFixed(1)} × 0.5) + (${item.rankScore.toStringAsFixed(1)} × 0.5)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          '= ${(item.appearanceScore * 0.5).toStringAsFixed(1)} + ${(item.rankScore * 0.5).toStringAsFixed(1)} = ${item.sourcingScore.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withAlpha(50)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.analytics_outlined, size: 18, color: Colors.orange[700]),
                            const SizedBox(width: 6),
                            Text(
                              '참고 지표 (종합 점수 미반영)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildStabilityRow(item),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '가격 정보',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Pretendard'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPriceItem('최저가', numberFormat.format(item.lowestPrice)),
                      _buildPriceItem('최고가', numberFormat.format(item.highestPrice)),
                      _buildPriceItem('변동률', '${item.priceVariation.toStringAsFixed(1)}%'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '순위 추이',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Pretendard'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '낮을수록 좋음 (1위가 최상위)',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600], fontFamily: 'Pretendard'),
                  ),
                  RankChart(rankHistory: item.rankHistory, height: 200),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '가격 추이',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Pretendard'),
                  ),
                  PriceChart(rankHistory: item.rankHistory, height: 150),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '날짜별 기록',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Pretendard'),
                  ),
                  const SizedBox(height: 12),
                  ...item.rankHistory.reversed.map((h) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Text(
                              DateFormat('MM/dd').format(h.date),
                              style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Pretendard'),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                                  fontFamily: 'Pretendard',
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${numberFormat.format(h.price)}원',
                              style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Pretendard'),
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

  Widget _buildScoreBreakdownRow(
    String label,
    double score,
    double weight,
    String detail,
    Color color,
  ) {
    final weightedScore = score * weight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$label (×$weight)',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Pretendard'),
            ),
            Text(
              '${score.toStringAsFixed(1)}점 → ${weightedScore.toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontFamily: 'Pretendard',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 16,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (score / 100).clamp(0, 1),
            child: Container(
              decoration: BoxDecoration(
                color: color.withAlpha(180),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Pretendard'),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey[600], fontFamily: 'Pretendard'),
        ),
      ],
    );
  }

  Widget _buildStabilityRow(ProductAnalytics item) {
    final score = item.stabilityScore;
    final stdDev = item.rankStability;

    String label;
    String detail;
    if (score >= 80) {
      label = '순위 변동 적음';
      detail = '표준편차 ${stdDev.toStringAsFixed(1)} · 꾸준히 비슷한 순위 유지';
    } else if (score >= 60) {
      label = '순위 비교적 안정';
      detail = '표준편차 ${stdDev.toStringAsFixed(1)} · 소폭 등락 있음';
    } else if (score >= 40) {
      label = '순위 변동 있음';
      detail = '표준편차 ${stdDev.toStringAsFixed(1)} · 순위 등락 주의';
    } else {
      label = '순위 변동 큼';
      detail = '표준편차 ${stdDev.toStringAsFixed(1)} · 순위 불안정';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '안정성 점수',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Pretendard'),
            ),
            Text(
              '${score.toStringAsFixed(1)}점 · $label',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontFamily: 'Pretendard',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 16,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (score / 100).clamp(0, 1),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(180),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          detail,
          style: TextStyle(fontSize: 13, color: Colors.grey[600], fontFamily: 'Pretendard'),
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
