import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'glass_card.dart';
import '../theme/app_theme.dart';

class InteractiveChartWidget extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> history; // [{'time': String, 'value': num}]
  final double min;
  final double max;
  final Color color;
  final bool isEditMode;
  final String? unit;

  const InteractiveChartWidget({
    key,
    required this.title,
    required this.history,
    this.min = 0,
    this.max = 100,
    this.color = AppTheme.primaryCyan,
    this.isEditMode = false,
    this.unit,
  }) : super(key: key);

  @override
  State<InteractiveChartWidget> createState() => _InteractiveChartWidgetState();
}

class _InteractiveChartWidgetState extends State<InteractiveChartWidget> {
  String _selectedFilter = '24h'; // Default filter: 24 hours

  double _getBottomTitleInterval(String filter) {
    switch (filter) {
      case '1h':
        return 10 * 60 * 1000.0; // 10 minutes in ms
      case '24h':
        return 2 * 60 * 60 * 1000.0; // 2 hours in ms
      case '7d':
        return 24 * 60 * 60 * 1000.0; // 1 day in ms
      case '30d':
        return 2 * 24 * 60 * 60 * 1000.0; // 2 days in ms
      default:
        return 24 * 60 * 60 * 1000.0;
    }
  }

  String _formatBottomTitle(String filter, double value) {
    final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    switch (filter) {
      case '1h':
        return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      case '24h':
        return "${dt.hour.toString().padLeft(2, '0')}:00";
      case '7d':
        const weekdays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
        if (dt.weekday >= 1 && dt.weekday <= 7) {
          return weekdays[dt.weekday - 1];
        }
        return "";
      case '30d':
        return "${dt.day}/${dt.month}";
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Current value
    double currentVal = 0.0;
    if (widget.history.isNotEmpty) {
      final lastVal = widget.history.last['value'];
      if (lastVal is num) {
        currentVal = lastVal.toDouble();
      }
    }

    // Time calculations
    final DateTime now = DateTime.now();
    DateTime startTime;
    switch (_selectedFilter) {
      case '1h':
        startTime = now.subtract(const Duration(hours: 1));
        break;
      case '24h':
        startTime = now.subtract(const Duration(hours: 24));
        break;
      case '7d':
        startTime = now.subtract(const Duration(days: 7));
        break;
      case '30d':
        startTime = now.subtract(const Duration(days: 30));
        break;
      default:
        startTime = now.subtract(const Duration(hours: 24));
    }

    final double minX = startTime.millisecondsSinceEpoch.toDouble();
    final double maxX = now.millisecondsSinceEpoch.toDouble();

    // Filter points in range
    List<Map<String, dynamic>> filteredHistory = [];
    for (var point in widget.history) {
      try {
        final timeStr = point['time'];
        if (timeStr == null) continue;
        final DateTime time = DateTime.parse(timeStr.toString());
        final value = point['value'];
        if (value == null) continue;

        if (time.isAfter(startTime) && time.isBefore(now)) {
          filteredHistory.add({
            'time': time,
            'value': (value as num).toDouble(),
          });
        }
      } catch (e) {
        debugPrint('Error parsing history point: $e');
      }
    }

    // Prepare FlSpot list
    List<FlSpot> spots = [];
    double dynamicMinY = widget.min;
    double dynamicMaxY = widget.max;

    if (filteredHistory.isEmpty) {
      // If empty, add a flat line from minX to maxX at currentVal
      spots.add(FlSpot(minX, currentVal));
      spots.add(FlSpot(maxX, currentVal));
      dynamicMinY = currentVal - 10;
      dynamicMaxY = currentVal + 10;
    } else {
      // Sort by time
      filteredHistory.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));
      
      double minVal = filteredHistory.first['value'] as double;
      double maxVal = minVal;
      
      // If we only have 1 point, create a line from minX to the point, then to maxX
      if (filteredHistory.length == 1) {
        final val = filteredHistory.first['value'] as double;
        final pointX = (filteredHistory.first['time'] as DateTime).millisecondsSinceEpoch.toDouble();
        spots.add(FlSpot(minX, val));
        spots.add(FlSpot(pointX, val));
        spots.add(FlSpot(maxX, val));
        dynamicMinY = val - 10;
        dynamicMaxY = val + 10;
      } else {
        for (var point in filteredHistory) {
          final x = (point['time'] as DateTime).millisecondsSinceEpoch.toDouble();
          final y = point['value'] as double;
          spots.add(FlSpot(x, y));
          if (y < minVal) minVal = y;
          if (y > maxVal) maxVal = y;
        }
        if (minVal == maxVal) {
          dynamicMinY = minVal - 10;
          dynamicMaxY = maxVal + 10;
        } else {
          double padding = (maxVal - minVal) * 0.25; // 25% padding
          dynamicMinY = minVal - padding;
          dynamicMaxY = maxVal + padding;
        }
      }
    }

    return GlassCard(
      borderColor: widget.color,
      baseColor: AppTheme.cardBaseColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxHeight < 60;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: isCompact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentVal.toStringAsFixed(1),
                          style: TextStyle(
                              color: widget.color,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                        if (widget.unit != null && widget.unit!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Text(
                              widget.unit!,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (!isCompact) const SizedBox(height: 12),
                
                // Chart
                if (!isCompact)
                  Expanded(
                    child: IgnorePointer(
                ignoring: widget.isEditMode, // prevent interacting with chart if in edit mode
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double chartWidth = constraints.maxWidth;
                      switch (_selectedFilter) {
                        case '1h':
                          chartWidth = constraints.maxWidth * 1.2;
                          break;
                        case '24h':
                          chartWidth = constraints.maxWidth * 2.5;
                          break;
                        case '7d':
                          chartWidth = constraints.maxWidth * 1.5;
                          break;
                        case '30d':
                          chartWidth = constraints.maxWidth * 3.0;
                          break;
                      }
                      if (chartWidth < constraints.maxWidth) {
                        chartWidth = constraints.maxWidth;
                      }

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true, // Start scrolled to the right (newest data)
                        child: SizedBox(
                          width: chartWidth,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                horizontalInterval: ((dynamicMaxY - dynamicMinY) / 4) > 0 ? ((dynamicMaxY - dynamicMinY) / 4) : 1,
                                verticalInterval: _getBottomTitleInterval(_selectedFilter),
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    strokeWidth: 0.8,
                                  );
                                },
                                getDrawingVerticalLine: (value) {
                                  return FlLine(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    strokeWidth: 0.8,
                                  );
                                },
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: _getBottomTitleInterval(_selectedFilter),
                                    reservedSize: 22,
                                    getTitlesWidget: (value, meta) {
                                      // Avoid drawing edge labels that fl_chart forces, to prevent overlaps and weird ordering.
                                      if (value == meta.min || value == meta.max) {
                                        return const SizedBox.shrink();
                                      }
                                      // Avoid drawing labels outside our min/max window
                                      if (value < minX || value > maxX) {
                                        return const SizedBox.shrink();
                                      }
                                      final label = _formatBottomTitle(_selectedFilter, value);
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6.0),
                                        child: Text(
                                          label,
                                          style: const TextStyle(
                                              color: Colors.white38, fontSize: 8),
                                          textDirection: TextDirection.rtl,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: ((dynamicMaxY - dynamicMinY) / 4) > 0 ? ((dynamicMaxY - dynamicMinY) / 4) : 1,
                                    reservedSize: 26,
                                    getTitlesWidget: (value, meta) {
                                      // Avoid drawing edge labels that fl_chart forces, to prevent overlaps
                                      if (value == meta.min || value == meta.max) {
                                        return const SizedBox.shrink();
                                      }
                                      return Text(
                                        value.toInt().toString(),
                                        style: const TextStyle(
                                            color: Colors.white38, fontSize: 8),
                                        textAlign: TextAlign.left,
                                        textDirection: TextDirection.ltr,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              minX: minX,
                              maxX: maxX,
                              minY: dynamicMinY,
                              maxY: dynamicMaxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: widget.color,
                          barWidth: 2.2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                widget.color.withValues(alpha: 0.25),
                                widget.color.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
            const SizedBox(height: 12),
            
            // Time range selector
                if (!isCompact)
                  Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterButton('1h', 'ساعة'),
                      _buildFilterButton('24h', '٢٤ ساعة'),
                      _buildFilterButton('7d', 'أسبوع'),
                      _buildFilterButton('30d', 'شهر'),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterButton(String filterCode, String label) {
    final isSelected = _selectedFilter == filterCode;
    return InkWell(
      onTap: widget.isEditMode
          ? null
          : () {
              setState(() {
                _selectedFilter = filterCode;
              });
            },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? widget.color.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: isSelected ? widget.color.withValues(alpha: 0.3) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? widget.color : Colors.white38,
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
