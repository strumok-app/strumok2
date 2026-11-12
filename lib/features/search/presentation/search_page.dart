import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/content_row.dart';
import '../../../app/widgets/state_views.dart';
import '../../../core/localization.dart';
import '../../../core/platform/device_class.dart';
import '../domain/search.dart';
import 'search_filters_sheet.dart';
import 'search_providers.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final _controller = TextEditingController(text: ref.read(searchQueryProvider));
  final _focusNode = FocusNode(debugLabel: 'searchField');

  /// Has focus while any suggestion does, so suggestions stay visible when focus leaves the field.
  final _suggestionsArea = FocusNode(debugLabel: 'searchSuggestions', canRequestFocus: false, skipTraversal: true);
  final _firstSuggestion = FocusNode(debugLabel: 'firstSuggestion');
  var _suggestionsVisible = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _focusNode.addListener(() => setState(() {}));
    _suggestionsArea.addListener(() => setState(() {}));
    _focusNode.onKeyEvent = _onFieldKey;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _suggestionsArea.dispose();
    _firstSuggestion.dispose();
    super.dispose();
  }

  // A single-line field swallows arrow down; use it to leave the field: recent searches first, else results.
  KeyEventResult _onFieldKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.arrowDown) return KeyEventResult.ignored;
    if (_suggestionsVisible) {
      _firstSuggestion.requestFocus();
      return KeyEventResult.handled;
    }
    return node.focusInDirection(TraversalDirection.down) ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  void _submit(String query) {
    _controller.text = query.trim();
    ref.read(searchQueryProvider.notifier).submit(query);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = ref.watch(searchQueryProvider);
    final isTv = ref.watch(deviceClassProvider) == DeviceClass.tv;
    final suggestions = searchSuggestions(ref.watch(searchHistoryProvider), _controller.text);
    final showSuggestions =
        (_focusNode.hasFocus || _suggestionsArea.hasFocus) &&
        suggestions.isNotEmpty &&
        _controller.text.trim() != query;
    _suggestionsVisible = showSuggestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  // No autofocus on TV: it would pop up the on-screen keyboard.
                  autofocus: !isTv && query == null,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _submit,
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.searchClear,
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _controller.clear();
                              _focusNode.requestFocus();
                            },
                          ),
                  ),
                ),
              ),
              IconButton.filledTonal(
                key: const Key('searchFiltersButton'),
                tooltip: l10n.searchFilters,
                icon: const Icon(Icons.tune),
                onPressed: () => showSearchFiltersSheet(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: showSuggestions
              ? Focus(
                  focusNode: _suggestionsArea,
                  child: _Suggestions(suggestions: suggestions, firstFocus: _firstSuggestion, onSelected: _submit),
                )
              : _Results(query: query),
        ),
      ],
    );
  }
}

class _Suggestions extends ConsumerWidget {
  final List<String> suggestions;
  final FocusNode firstFocus;
  final ValueChanged<String> onSelected;

  const _Suggestions({required this.suggestions, required this.firstFocus, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    children: [
      for (final (index, s) in suggestions.indexed)
        ListTile(
          focusNode: index == 0 ? firstFocus : null,
          leading: const Icon(Icons.history),
          title: Text(s),
          onTap: () => onSelected(s),
          trailing: IconButton(
            tooltip: context.l10n.searchRemoveFromHistory,
            icon: const Icon(Icons.close),
            onPressed: () => ref.read(searchHistoryProvider.notifier).remove(s),
          ),
        ),
    ],
  );
}

class _Results extends ConsumerWidget {
  final String? query;

  const _Results({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final query = this.query;
    if (query == null) return EmptyStateView(icon: Icons.search, message: l10n.searchEnterQuery);

    final suppliers = ref.watch(searchSupplierNamesProvider);
    if (suppliers.isEmpty) return EmptyStateView(icon: Icons.filter_alt_off_outlined, message: l10n.searchNoSuppliers);
    if (ref.watch(searchNothingFoundProvider)) {
      return EmptyStateView(icon: Icons.search_off, message: l10n.searchNothingFound);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: suppliers.length,
      itemBuilder: (context, index) {
        final provider = searchItemsProvider(suppliers[index], query);
        return ContentRow(
          title: suppliers[index],
          state: ref.watch(provider),
          onLoadMore: ref.read(provider.notifier).loadMore,
          onRetry: ref.read(provider.notifier).retry,
          hideWhenEmpty: true,
        );
      },
    );
  }
}
