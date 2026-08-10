import 'package:intl/intl.dart';

class OrderDateGroup implements Comparable<OrderDateGroup> {
  final int rank;
  final String displayName;
  
  OrderDateGroup(this.rank, this.displayName);
  
  @override
  int compareTo(OrderDateGroup other) {
    return rank.compareTo(other.rank);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderDateGroup &&
          runtimeType == other.runtimeType &&
          rank == other.rank &&
          displayName == other.displayName;

  @override
  int get hashCode => rank.hashCode ^ displayName.hashCode;

  static OrderDateGroup fromDate({
    required DateTime orderDate,
    required DateTime referenceDate,
    required bool isScheduled,
    required dynamic l10n,
  }) {
    if (isScheduled) {
      return OrderDateGroup(0, l10n.scheduledOrders);
    }

    final today = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final startOfWeek = today.subtract(Duration(days: today.weekday % 7));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    final normalizedOrderDate = DateTime(orderDate.year, orderDate.month, orderDate.day);

    if (normalizedOrderDate == today) {
      return OrderDateGroup(
        1,
        l10n.todayPrefix + DateFormat('yyyy/MM/dd').format(normalizedOrderDate),
      );
    } else if (normalizedOrderDate == yesterday) {
      return OrderDateGroup(
        2,
        l10n.yesterdayPrefix + DateFormat('yyyy/MM/dd').format(normalizedOrderDate),
      );
    } else if (normalizedOrderDate.isAfter(today)) {
      // Future dates (not scheduled) shouldn't happen, but if they do, rank them by days in future (negative ranks to appear at top)
      final daysAhead = normalizedOrderDate.difference(today).inDays;
      return OrderDateGroup(
        -daysAhead, // appears before today
        l10n.todayPrefix + DateFormat('yyyy/MM/dd').format(normalizedOrderDate),
      );
    } else if (normalizedOrderDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
               normalizedOrderDate.isBefore(endOfWeek.add(const Duration(days: 1)))) {
      return OrderDateGroup(
        3,
        l10n.thisWeekFromTo(
          DateFormat('MM/dd').format(startOfWeek),
          DateFormat('MM/dd').format(endOfWeek),
        ),
      );
    } else if (normalizedOrderDate.isAfter(today.subtract(const Duration(days: 30)))) {
      final diffDays = startOfWeek.difference(normalizedOrderDate).inDays;
      final weeksAgo = (diffDays / 7).floor() + 1;
      final wStart = startOfWeek.subtract(Duration(days: weeksAgo * 7));
      final wEnd = wStart.add(const Duration(days: 6));
      return OrderDateGroup(
        100 + weeksAgo, // e.g. 101, 102
        l10n.agoPrefix +
            weeksAgo.toString() +
            l10n.weekFromTo(
              DateFormat('MM/dd').format(wStart),
              DateFormat('MM/dd').format(wEnd),
            ),
      );
    } else if (normalizedOrderDate.year == today.year) {
      final monthRank = 12 - normalizedOrderDate.month; // 1 to 11
      return OrderDateGroup(
        1000 + monthRank,
        l10n.monthPrefix + DateFormat('MMMM').format(normalizedOrderDate),
      );
    } else {
      final yearRank = 9999 - normalizedOrderDate.year;
      return OrderDateGroup(
        10000 + yearRank,
        l10n.yearPrefix + DateFormat('yyyy').format(normalizedOrderDate),
      );
    }
  }
}
