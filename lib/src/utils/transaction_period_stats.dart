/// One bucket (a calendar month or calendar year) of transaction totals.
class TransactionPeriodPoint {
  const TransactionPeriodPoint({required this.period, required this.amount, required this.orderCount});

  /// The 1st of the month (for monthly points) or Jan 1 (for yearly points).
  final DateTime period;
  final double amount;
  final int orderCount;
}

/// Complete transaction history derived from a full order list -- bucketed
/// by month and by year, starting from the first order ever placed (not a
/// fixed "this calendar year" window), so the chart always shows the whole
/// relationship from day 1 instead of silently dropping earlier history.
class TransactionHistory {
  const TransactionHistory({
    required this.monthly,
    required this.yearly,
    required this.thisMonthTotal,
    required this.lastMonthTotal,
    required this.thisYearTotal,
    required this.lastYearTotal,
  });

  /// Ascending, one point per calendar month from the first order's month
  /// through the current month (gaps filled with zero, never skipped).
  final List<TransactionPeriodPoint> monthly;

  /// Ascending, one point per calendar year from the first order's year
  /// through the current year.
  final List<TransactionPeriodPoint> yearly;

  final double thisMonthTotal;
  final double lastMonthTotal;
  final double thisYearTotal;
  final double lastYearTotal;

  /// [include] decides which orders count toward the total -- e.g. an owner
  /// only counts paid orders as revenue, while a customer counts every
  /// non-cancelled order as spend regardless of payment status, matching
  /// each dashboard's existing convention elsewhere on the same screen.
  static TransactionHistory compute(
    List<Map<String, dynamic>> orders, {
    required bool Function(Map<String, dynamic> order) include,
  }) {
    final byMonth = <DateTime, _Bucket>{};
    final byYear = <DateTime, _Bucket>{};
    DateTime? earliest;

    for (final order in orders) {
      if (!include(order)) continue;
      final createdRaw = order['created_at']?.toString();
      final created = createdRaw == null ? null : DateTime.tryParse(createdRaw)?.toLocal();
      if (created == null) continue;

      final amount = (order['total_amount'] as num?)?.toDouble() ?? 0;
      final monthKey = DateTime(created.year, created.month, 1);
      final yearKey = DateTime(created.year, 1, 1);

      (byMonth[monthKey] ??= _Bucket()).add(amount);
      (byYear[yearKey] ??= _Bucket()).add(amount);

      if (earliest == null || created.isBefore(earliest)) earliest = created;
    }

    final now = DateTime.now();
    final monthly = <TransactionPeriodPoint>[];
    final yearly = <TransactionPeriodPoint>[];

    if (earliest != null) {
      var cursor = DateTime(earliest.year, earliest.month, 1);
      final lastMonth = DateTime(now.year, now.month, 1);
      while (!cursor.isAfter(lastMonth)) {
        final bucket = byMonth[cursor];
        monthly.add(TransactionPeriodPoint(period: cursor, amount: bucket?.amount ?? 0, orderCount: bucket?.count ?? 0));
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }

      for (var year = earliest.year; year <= now.year; year++) {
        final key = DateTime(year, 1, 1);
        final bucket = byYear[key];
        yearly.add(TransactionPeriodPoint(period: key, amount: bucket?.amount ?? 0, orderCount: bucket?.count ?? 0));
      }
    }

    double totalFor(DateTime key, Map<DateTime, _Bucket> map) => map[key]?.amount ?? 0;

    return TransactionHistory(
      monthly: monthly,
      yearly: yearly,
      thisMonthTotal: totalFor(DateTime(now.year, now.month, 1), byMonth),
      lastMonthTotal: totalFor(DateTime(now.year, now.month - 1, 1), byMonth),
      thisYearTotal: totalFor(DateTime(now.year, 1, 1), byYear),
      lastYearTotal: totalFor(DateTime(now.year - 1, 1, 1), byYear),
    );
  }
}

class _Bucket {
  double amount = 0;
  int count = 0;
  void add(double value) {
    amount += value;
    count++;
  }
}
