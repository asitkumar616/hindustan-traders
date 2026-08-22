/// Formats a number using Indian digit grouping (e.g. 1250000 -> "12,50,000"),
/// matching the reference design's revenue/amount figures.
String formatIndianAmount(num value) {
  final negative = value < 0;
  final str = value.abs().round().toString();
  if (str.length <= 3) return (negative ? '-' : '') + str;

  final lastThree = str.substring(str.length - 3);
  var remaining = str.substring(0, str.length - 3);
  final groups = <String>[];
  while (remaining.length > 2) {
    groups.insert(0, remaining.substring(remaining.length - 2));
    remaining = remaining.substring(0, remaining.length - 2);
  }
  if (remaining.isNotEmpty) groups.insert(0, remaining);

  return '${negative ? '-' : ''}${groups.join(',')},$lastThree';
}
