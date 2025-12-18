import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/product_analytics.dart';

/// 순위 추이 차트 위젯
class RankChart extends StatelessWidget {
  final List<RankHistory> rankHistory;
  final double height;

  const RankChart({
    super.key,
    required this.rankHistory,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (rankHistory.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('데이터가 없습니다', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final sortedHistory = List<RankHistory>.from(rankHistory)
      ..sort((a, b) => a.date.compareTo(b.date));

    // 순위 범위 계산 (Y축은 역순: 1위가 위)
    final ranks = sortedHistory.map((h) => h.rank).toList();
    final minRank = ranks.reduce((a, b) => a < b ? a : b);
    final maxRank = ranks.reduce((a, b) => a > b ? a : b);

    // Y축 범위 설정 (여유 공간 추가)
    final yMin = (minRank - 5).clamp(1, 100).toDouble();
    final yMax = (maxRank + 5).clamp(1, 100).toDouble();

    return Container(
      height: height,
      padding: const EdgeInsets.only(right: 16, top: 16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 10,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: _calculateDateInterval(sortedHistory.length),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= sortedHistory.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('MM/dd').format(sortedHistory[index].date),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 10,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}위',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (sortedHistory.length - 1).toDouble(),
          minY: yMin,
          maxY: yMax,
          lineBarsData: [
            LineChartBarData(
              spots: sortedHistory.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  entry.value.rank.toDouble(),
                );
              }).toList(),
              isCurved: true,
              curveSmoothness: 0.3,
              color: const Color(0xFF434E78),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: const Color(0xFF434E78),
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF434E78).withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.black87,
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index < 0 || index >= sortedHistory.length) {
                    return null;
                  }
                  final history = sortedHistory[index];
                  final priceFormatted = NumberFormat('#,###').format(history.price);
                  return LineTooltipItem(
                    '${DateFormat('MM/dd').format(history.date)}\n'
                    '${history.rank}위\n'
                    '$priceFormatted원',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  double _calculateDateInterval(int dataCount) {
    if (dataCount <= 7) return 1;
    if (dataCount <= 14) return 2;
    if (dataCount <= 30) return 5;
    return 7;
  }
}

/// 가격 추이 차트 (보조)
class PriceChart extends StatelessWidget {
  final List<RankHistory> rankHistory;
  final double height;

  const PriceChart({
    super.key,
    required this.rankHistory,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    if (rankHistory.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('데이터가 없습니다', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final sortedHistory = List<RankHistory>.from(rankHistory)
      ..sort((a, b) => a.date.compareTo(b.date));

    final prices = sortedHistory.map((h) => h.price.toDouble()).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);

    // Y축 범위 설정 (여유 공간 추가)
    final priceRange = maxPrice - minPrice;
    final yMin = (minPrice - priceRange * 0.1).clamp(0.0, double.infinity);
    final yMax = maxPrice + priceRange * 0.1;

    return Container(
      height: height,
      padding: const EdgeInsets.only(right: 16, top: 16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: _calculateDateInterval(sortedHistory.length),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= sortedHistory.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('MM/dd').format(sortedHistory[index].date),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    NumberFormat.compact(locale: 'ko').format(value),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (sortedHistory.length - 1).toDouble(),
          minY: yMin,
          maxY: yMax,
          lineBarsData: [
            LineChartBarData(
              spots: sortedHistory.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  entry.value.price.toDouble(),
                );
              }).toList(),
              isCurved: true,
              curveSmoothness: 0.3,
              color: Colors.green,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: Colors.green,
                    strokeWidth: 1,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.black87,
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index < 0 || index >= sortedHistory.length) {
                    return null;
                  }
                  final history = sortedHistory[index];
                  final priceFormatted = NumberFormat('#,###').format(history.price);
                  return LineTooltipItem(
                    '${DateFormat('MM/dd').format(history.date)}\n$priceFormatted원',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  double _calculateDateInterval(int dataCount) {
    if (dataCount <= 7) return 1;
    if (dataCount <= 14) return 2;
    if (dataCount <= 30) return 5;
    return 7;
  }
}
