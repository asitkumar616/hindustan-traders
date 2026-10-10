import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';
import '../utils/transaction_period_stats.dart';
import 'app_card.dart';

String _compactAmount(double value) {
  if (value >= 100000) return '${(value / 100000).toStringAsFixed(value >= 1000000 ? 0 : 1)}L';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return value.toStringAsFixed(0);
}

int? _percentDelta(num current, num previous) {
  if (previous == 0) return null;
  return (((current - previous) / previous) * 100).round();
}

/// "Transaction Overview" card -- a combined revenue-bars + orders-line
/// chart covering the complete history (from the very first order, not a
/// fixed "this year" window), with a Monthly/Yearly toggle and This
/// Month/This Year totals underneath. Shared by the Owner dashboard
/// (revenue = paid orders) and the Customer dashboard (spend = every
/// non-cancelled order) -- only the label and the already-aggregated
/// [history] differ between the two.
class TransactionOverviewCard extends StatefulWidget {
  const TransactionOverviewCard({
    super.key,
    required this.history,
    required this.loading,
    this.amountLabel = 'Revenue (₹)',
    this.monthLabel = 'This Month',
    this.yearLabel = 'This Year',
    this.onTap,
  });

  final TransactionHistory history;
  final bool loading;
  final String amountLabel;
  final String monthLabel;
  final String yearLabel;
  final VoidCallback? onTap;

  @override
  State<TransactionOverviewCard> createState() => _TransactionOverviewCardState();
}

class _TransactionOverviewCardState extends State<TransactionOverviewCard> {
  bool _isYearly = false;

  @override
  Widget build(BuildContext context) {
    final points = _isYearly ? widget.history.yearly : widget.history.monthly;
    final monthDelta = _percentDelta(widget.history.thisMonthTotal, widget.history.lastMonthTotal);
    final yearDelta = _percentDelta(widget.history.thisYearTotal, widget.history.lastYearTotal);

    return AppCard(
      onTap: widget.onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: const Color(0xFFE1F7E8), borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 17),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text('Transaction Overview', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              _TogglePill(
                isYearly: _isYearly,
                onChanged: (value) => setState(() => _isYearly = value),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _LegendDot(color: AppColors.success, label: widget.amountLabel),
              const SizedBox(width: AppSpacing.md),
              const _LegendDot(color: AppColors.primary, label: 'Orders'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (widget.loading)
            const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)))
          else if (points.isEmpty)
            const SizedBox(
              height: 160,
              child: Center(
                child: Text('No transactions yet', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ),
            )
          else
            _ComboChart(points: points, isYearly: _isYearly),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _TotalFigure(
                  label: widget.monthLabel,
                  value: widget.loading ? '—' : '₹${formatIndianAmount(widget.history.thisMonthTotal)}',
                  deltaPercent: widget.loading ? null : monthDelta,
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.divider),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _TotalFigure(
                  label: widget.yearLabel,
                  value: widget.loading ? '—' : '₹${formatIndianAmount(widget.history.thisYearTotal)}',
                  deltaPercent: widget.loading ? null : yearDelta,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({required this.isYearly, required this.onChanged});

  final bool isYearly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.pill), border: Border.all(color: AppColors.divider)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TogglePillOption(label: 'Monthly', selected: !isYearly, onTap: () => onChanged(false)),
          _TogglePillOption(label: 'Yearly', selected: isYearly, onTap: () => onChanged(true)),
        ],
      ),
    );
  }
}

class _TogglePillOption extends StatelessWidget {
  const _TogglePillOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.success : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _TotalFigure extends StatelessWidget {
  const _TotalFigure({required this.label, required this.value, this.deltaPercent});

  final String label;
  final String value;
  final int? deltaPercent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (deltaPercent != null && deltaPercent != 0) ...[
              const SizedBox(width: 4),
              Icon(
                deltaPercent! > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 12,
                color: deltaPercent! > 0 ? AppColors.success : AppColors.danger,
              ),
              Text(
                '${deltaPercent!.abs()}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: deltaPercent! > 0 ? AppColors.success : AppColors.danger),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Revenue bars + orders line overlaid in a [Stack], sharing one X axis.
/// fl_chart has no built-in dual-axis combo chart, so the orders line is
/// scaled into the bar chart's 0..revenueMax Y range to share the same
/// pixel space, with its own right-side axis labels reverse-computed from
/// that same scale factor. `BarChartAlignment.spaceBetween` on the bars and
/// `minX: 0, maxX: n-1` on the line are what keep bar centers and line
/// points pixel-aligned at each index.
class _ComboChart extends StatelessWidget {
  const _ComboChart({required this.points, required this.isYearly});

  final List<TransactionPeriodPoint> points;
  final bool isYearly;

  static const double _leftReserved = 38;
  static const double _rightReserved = 30;
  static const double _bottomReserved = 22;
  static const double _barWidthPerPoint = 34;

  @override
  Widget build(BuildContext context) {
    final n = points.length;
    final rawRevenueMax = points.map((p) => p.amount).fold(0.0, (a, b) => a > b ? a : b);
    final rawOrdersMax = points.map((p) => p.orderCount).fold(0, (a, b) => a > b ? a : b);
    final revenueMax = rawRevenueMax <= 0 ? 10.0 : rawRevenueMax * 1.25;
    final ordersMax = rawOrdersMax <= 0 ? 1 : (rawOrdersMax * 1.25).ceil();
    final scale = ordersMax == 0 ? 1.0 : revenueMax / ordersMax;

    String bottomLabel(int index) {
      final period = points[index].period;
      if (isYearly) return period.year.toString();
      final spansMultipleYears = points.first.period.year != points.last.period.year;
      return DateFormat(spansMultipleYears ? 'MMM yy' : 'MMM').format(period);
    }

    final titlesData = FlTitlesData(
      show: true,
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _leftReserved,
          interval: revenueMax / 4,
          getTitlesWidget: (value, meta) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(_compactAmount(value), style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary)),
          ),
        ),
      ),
      rightTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _rightReserved,
          interval: revenueMax / 4,
          getTitlesWidget: (value, meta) => Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text((value / scale).round().toString(), style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary)),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _bottomReserved,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (index < 0 || index >= n) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(bottomLabel(index), style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary)),
            );
          },
        ),
      ),
    );

    final hiddenTitlesData = FlTitlesData(
      show: true,
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: _leftReserved, getTitlesWidget: (_, __) => const SizedBox.shrink())),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: _rightReserved, getTitlesWidget: (_, __) => const SizedBox.shrink())),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: _bottomReserved, getTitlesWidget: (_, __) => const SizedBox.shrink())),
    );

    final chartWidth = (n * _barWidthPerPoint).clamp(240.0, double.infinity);

    final barChart = BarChart(
      BarChartData(
        minY: 0,
        maxY: revenueMax,
        // spaceBetween is what keeps bar centers pixel-aligned with the
        // overlaid line's x=0..n-1 coordinate space; with only one bar that
        // alignment is degenerate, so fall back to centering it instead.
        alignment: n > 1 ? BarChartAlignment.spaceBetween : BarChartAlignment.center,
        titlesData: titlesData,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: revenueMax / 4,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final point = points[group.x.toInt()];
              return BarTooltipItem(
                '₹${formatIndianAmount(point.amount)}\n${point.orderCount} order${point.orderCount == 1 ? '' : 's'}',
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < n; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].amount,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xFF8FD9AE), AppColors.success],
                  ),
                ),
              ],
            ),
        ],
      ),
    );

    final lineChart = n < 2
        ? const SizedBox.shrink()
        : LineChart(
            LineChartData(
              minX: 0,
              maxX: (n - 1).toDouble(),
              minY: 0,
              maxY: revenueMax,
              titlesData: hiddenTitlesData,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < n; i++) FlSpot(i.toDouble(), points[i].orderCount * scale)],
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
            ),
          );

    return SizedBox(
      height: 200,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: SizedBox(
          width: chartWidth,
          height: 200,
          child: Stack(
            children: [
              barChart,
              Positioned.fill(child: lineChart),
            ],
          ),
        ),
      ),
    );
  }
}
