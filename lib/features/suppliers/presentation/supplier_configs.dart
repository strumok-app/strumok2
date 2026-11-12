import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/localization.dart';
import '../../../core/storage/app_preferences.dart';
import '../data/supplier_registry.dart';
import '../domain/supplier_config.dart';

part 'supplier_configs.g.dart';

/// Ordered per-supplier configuration (spec-02 §2.5).
@Riverpod(keepAlive: true)
class SupplierConfigs extends _$SupplierConfigs {
  AppPreferences get _prefs => ref.read(appPreferencesProvider);

  @override
  List<SupplierConfig> build() {
    final prefs = ref.watch(appPreferencesProvider);
    final uiLanguage = ContentLanguage.values.asNameMap()[ref.watch(appLocaleProvider).languageCode];
    return resolveSupplierConfigs(
      available: ref.watch(suppliersProvider),
      savedOrder: prefs.getStringList(AppPreferences.suppliersOrder) ?? const [],
      savedEnabled: (name) => prefs.getBool(AppPreferences.supplierEnabled(name)),
      savedChannels: (name) => prefs.getStringList(AppPreferences.supplierChannels(name)),
      uiLanguage: uiLanguage ?? ContentLanguage.uk,
    );
  }

  Future<void> setEnabled(String name, bool enabled) async {
    state = [for (final c in state) c.name == name ? c.copyWith(enabled: enabled) : c];
    await _prefs.setBool(AppPreferences.supplierEnabled(name), enabled);
  }

  Future<void> setChannel(String name, String channel, bool selected) async {
    final config = state.firstWhere((c) => c.name == name);
    final channels = {...config.channels};
    selected ? channels.add(channel) : channels.remove(channel);
    state = [for (final c in state) c.name == name ? c.copyWith(channels: channels) : c];
    await _prefs.setStringList(AppPreferences.supplierChannels(name), channels.toList());
  }

  /// [newIndex] is the final position of the moved item.
  Future<void> move(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex || newIndex < 0 || newIndex >= state.length) return;
    final next = [...state];
    next.insert(newIndex, next.removeAt(oldIndex));
    state = next;
    await _prefs.setStringList(AppPreferences.suppliersOrder, [for (final c in next) c.name]);
  }
}
