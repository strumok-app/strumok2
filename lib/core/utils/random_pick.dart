import 'dart:math';

/// Index of a random item, never one in [exclude]; with [weight] an item's chance is proportional to it.
/// Null when every item is excluded (or [items] is empty).
int? pickRandomIndex<T>(List<T> items, Random random, {Set<int> exclude = const {}, double Function(T)? weight}) {
  final candidates = [
    for (var i = 0; i < items.length; i++)
      if (!exclude.contains(i)) i,
  ];
  if (candidates.isEmpty) return null;
  if (weight == null) return candidates[random.nextInt(candidates.length)];

  final weights = [for (final i in candidates) max(0.0, weight(items[i]))];
  final total = weights.fold(0.0, (a, b) => a + b);
  if (total <= 0) return candidates[random.nextInt(candidates.length)];
  var point = random.nextDouble() * total;
  for (var i = 0; i < candidates.length; i++) {
    point -= weights[i];
    if (point < 0) return candidates[i];
  }
  return candidates.last;
}
