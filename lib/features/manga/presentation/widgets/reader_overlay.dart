import 'dart:async';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/refresh_sources_button.dart';
import '../../../../app/widgets/side_sheet.dart';
import '../../../../core/localization.dart';
import '../../../collection/presentation/collection_providers.dart';
import '../../../details/presentation/media_items_list.dart';
import '../../../downloads/presentation/downloads_providers.dart';
import '../../../downloads/presentation/widgets/download_widgets.dart';
import '../../domain/manga_reader_preferences.dart';
import '../../domain/manga_reader_state.dart';
import '../manga_reader_settings.dart';

/// Back, content and chapter titles, translation / chapters / settings actions.
class ReaderTopBar extends StatelessWidget {
  final MangaReaderState state;

  /// TV leaves it out: the remote's Back key hides the controls, then exits.
  final bool back;
  final ValueChanged<int> onSelectChapter;
  final ValueChanged<int> onSelectSource;
  final VoidCallback onRefreshSources;

  const ReaderTopBar({
    super.key,
    required this.state,
    required this.back,
    required this.onSelectChapter,
    required this.onSelectSource,
    required this.onRefreshSources,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final chapter = state.item?.title;
    return _Bar(
      top: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          children: [
            if (back) ...[const BackButton(), const SizedBox(width: 8)] else const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.title, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (chapter != null && chapter.isNotEmpty)
                    Text(chapter, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (state.sources.isNotEmpty)
              IconButton(
                key: const Key('readerTranslationButton'),
                tooltip: l10n.readerTranslation,
                onPressed: () => showReaderSources(context, state, onSelectSource, onRefreshSources),
                icon: const Icon(Icons.translate),
              ),
            IconButton(
              key: const Key('readerSettingsButton'),
              tooltip: l10n.readerSettings,
              onPressed: () => showReaderSettings(context),
              icon: const Icon(Icons.settings_outlined),
            ),
            if (state.items.length > 1)
              IconButton(
                key: const Key('readerChaptersButton'),
                tooltip: l10n.detailsChapters,
                onPressed: () => showReaderChapters(context, state, onSelectChapter),
                icon: const Icon(Icons.format_list_bulleted),
              ),
          ],
        ),
      ),
    );
  }
}

/// Previous / next chapter and the page slider with "N / total". Right-to-left reading mirrors it.
class ReaderBottomBar extends StatefulWidget {
  final MangaReaderState state;
  final bool rightToLeft;
  final FocusNode sliderFocus;
  final ValueChanged<int> onJump;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;

  const ReaderBottomBar({
    super.key,
    required this.state,
    required this.rightToLeft,
    required this.sliderFocus,
    required this.onJump,
    required this.onPreviousChapter,
    required this.onNextChapter,
  });

  @override
  State<ReaderBottomBar> createState() => _ReaderBottomBarState();
}

class _ReaderBottomBarState extends State<ReaderBottomBar> {
  double? _dragging;

  int get _last => widget.state.pages.length - 1;

  /// ←/→ move one page in the slider's visual direction; ↑/↓ leave it.
  KeyEventResult _onSliderKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final direction = switch (key) {
      LogicalKeyboardKey.arrowRight => 1,
      LogicalKeyboardKey.arrowLeft => -1,
      _ => 0,
    };
    if (direction == 0) return KeyEventResult.ignored;
    final page = (widget.state.page + (widget.rightToLeft ? -direction : direction)).clamp(0, _last);
    if (page != widget.state.page) widget.onJump(page);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = widget.state;
    final value = (_dragging ?? state.page.toDouble()).clamp(0, _last.toDouble()).toDouble();
    Widget flipped(IconData icon) => Transform.flip(flipX: widget.rightToLeft, child: Icon(icon));

    return _Bar(
      top: false,
      child: Directionality(
        textDirection: widget.rightToLeft ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          height: 64,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(
            children: [
              IconButton(
                key: const Key('readerPreviousChapter'),
                tooltip: l10n.readerPreviousChapter,
                onPressed: state.hasPrevious ? widget.onPreviousChapter : null,
                icon: flipped(Icons.skip_previous),
              ),
              Expanded(
                child: Focus(
                  focusNode: widget.sliderFocus,
                  onKeyEvent: _onSliderKey,
                  child: Builder(
                    builder: (context) => DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(Radius.circular(24)),
                        border: Border.all(
                          width: 2,
                          color: Focus.of(context).hasFocus ? theme.colorScheme.primary : Colors.transparent,
                        ),
                      ),
                      // Keys are handled by the wrapping focus: one page per press, in reading direction.
                      child: ExcludeFocus(
                        child: Slider(
                          key: const Key('readerPageSlider'),
                          value: value,
                          max: _last > 0 ? _last.toDouble() : 1,
                          divisions: _last > 0 ? _last : null,
                          label: '${value.round() + 1}',
                          semanticFormatterCallback: (v) => l10n.readerPageCounter(v.round() + 1, state.pages.length),
                          onChanged: _last > 0 ? (v) => setState(() => _dragging = v) : null,
                          onChangeEnd: (v) {
                            setState(() => _dragging = null);
                            if (v.round() != state.page) widget.onJump(v.round());
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  l10n.readerPageCounter(value.round() + 1, state.pages.length),
                  key: const Key('readerPageCounter'),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              IconButton(
                key: const Key('readerNextChapter'),
                tooltip: l10n.readerNextChapter,
                onPressed: state.hasNext ? widget.onNextChapter : null,
                icon: flipped(Icons.skip_next),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final bool top;
  final Widget child;

  const _Bar({required this.top, required this.child});

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.94),
    child: SafeArea(top: top, bottom: !top, child: child),
  );
}

/// Chapters grouped by section with collection progress, focused on the current one.
Future<void> showReaderChapters(BuildContext context, MangaReaderState state, ValueChanged<int> onSelected) =>
    showSideSheet(
      context,
      title: context.l10n.detailsChapters,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final item = ref.watch(collectionItemProvider(state.supplier, state.id));
          return MediaItemsList(
            items: state.items,
            mediaType: MediaType.manga,
            positions: item?.positions ?? const {},
            currentItem: state.item?.number,
            onSelected: (selected) {
              Navigator.of(context).pop();
              onSelected(state.items.indexOf(selected));
            },
          );
        },
      ),
    );

const _refreshSources = -1;

/// Translations (manga sources) of the chapter, focused on the current one; the header refreshes them.
Future<void> showReaderSources(
  BuildContext context,
  MangaReaderState state,
  ValueChanged<int> onSelected,
  VoidCallback onRefresh,
) async {
  final selected = await showSideSheet<int>(
    context,
    title: context.l10n.readerTranslation,
    actions: [
      Builder(builder: (context) => RefreshSourcesButton(onPressed: () => Navigator.of(context).pop(_refreshSources))),
    ],
    builder: (context) => ListView(
      children: [
        for (final (index, source) in state.sources.indexed)
          _Choice(
            key: ValueKey('readerSource-$index'),
            label: context.sourceLabel(source),
            leading: isLocalSource(source) ? const DownloadedMark() : null,
            selected: index == state.sourceIndex,
            onTap: () => Navigator.of(context).pop(index),
          ),
      ],
    ),
  );
  if (selected == _refreshSources) {
    onRefresh();
  } else if (selected != null && selected != state.sourceIndex) {
    onSelected(selected);
  }
}

Future<void> showReaderSettings(BuildContext context) =>
    showSideSheet<void>(context, title: context.l10n.readerSettings, builder: (_) => const ReaderSettingsPanel());

/// Mode, background and auto-crop; applied immediately and persisted (spec-09).
class ReaderSettingsPanel extends ConsumerWidget {
  const ReaderSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(mangaReaderSettingsProvider);
    final notifier = ref.read(mangaReaderSettingsProvider.notifier);
    return ListView(
      children: [
        _Header(l10n.readerModeTitle),
        for (final mode in MangaReaderMode.values)
          _Choice(
            key: ValueKey('readerMode-${mode.name}'),
            label: readerModeLabel(l10n, mode),
            selected: settings.mode == mode,
            onTap: () => unawaited(notifier.setMode(mode)),
          ),
        _Header(l10n.readerBackground),
        for (final background in MangaReaderBackground.values)
          _Choice(
            key: ValueKey('readerBackground-${background.name}'),
            label: readerBackgroundLabel(l10n, background),
            selected: settings.background == background,
            autofocus: false,
            onTap: () => unawaited(notifier.setBackground(background)),
          ),
        SwitchListTile(
          key: const ValueKey('readerAutoCrop'),
          title: Text(l10n.readerAutoCrop),
          subtitle: Text(l10n.readerAutoCropDescription),
          value: settings.autoCrop,
          onChanged: (value) => unawaited(notifier.setAutoCrop(value)),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String text;

  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}

/// One option of a single-choice list; the selected one is checked (and takes initial focus by default).
class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final bool? autofocus;
  final Widget? leading;
  final VoidCallback onTap;

  const _Choice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.autofocus,
    this.leading,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    autofocus: autofocus ?? selected,
    selected: selected,
    leading: leading,
    title: Text(label),
    trailing: selected ? const Icon(Icons.check) : null,
    onTap: onTap,
  );
}
