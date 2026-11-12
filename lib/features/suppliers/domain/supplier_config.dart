import 'package:content_suppliers_api/content_suppliers_api.dart';

final class SupplierConfig {
  final ContentSupplier supplier;
  final bool enabled;
  final Set<String> channels;

  const SupplierConfig({required this.supplier, required this.enabled, required this.channels});

  String get name => supplier.name;

  SupplierConfig copyWith({bool? enabled, Set<String>? channels}) =>
      SupplierConfig(supplier: supplier, enabled: enabled ?? this.enabled, channels: channels ?? this.channels);
}

/// Applies persisted settings to the available suppliers (spec-02 §2.5):
/// saved order first (missing removed), new suppliers appended; enabled defaults to UI language support;
/// saved channels are intersected with current ones, defaulting to the supplier's default channels.
List<SupplierConfig> resolveSupplierConfigs({
  required List<ContentSupplier> available,
  required List<String> savedOrder,
  required bool? Function(String name) savedEnabled,
  required List<String>? Function(String name) savedChannels,
  required ContentLanguage uiLanguage,
}) {
  final byName = {for (final s in available) s.name: s};
  final orderedNames = [
    ...savedOrder.where(byName.containsKey),
    ...available.map((s) => s.name).where((n) => !savedOrder.contains(n)),
  ];

  SupplierConfig resolve(ContentSupplier supplier) {
    final channels = savedChannels(supplier.name);
    return SupplierConfig(
      supplier: supplier,
      enabled: savedEnabled(supplier.name) ?? supplier.supportedLanguages.contains(uiLanguage),
      channels: channels == null ? supplier.defaultChannels : channels.toSet().intersection(supplier.channels),
    );
  }

  return [for (final name in orderedNames) resolve(byName[name]!)];
}
