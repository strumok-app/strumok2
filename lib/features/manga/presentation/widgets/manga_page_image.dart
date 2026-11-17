import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization.dart';
import '../../data/manga_page_images.dart';
import '../../domain/auto_crop.dart';

/// How pages are shown; shared by every page of the reader.
class MangaPageConfig {
  final MangaPageImages images;
  final Map<String, String>? headers;
  final bool autoCrop;

  /// Long strip: pages continue each other vertically, so only side borders are cropped.
  final bool strip;
  final ReaderPageRetries retries;

  const MangaPageConfig({
    required this.images,
    required this.headers,
    required this.autoCrop,
    required this.strip,
    required this.retries,
  });

  bool get cropVertical => !strip;
}

/// Retry actions of pages that failed to load, so the D-pad OK key can retry the current page (the retry
/// buttons on the page are for touch and mouse).
class ReaderPageRetries {
  final _retries = <String, VoidCallback>{};

  void _register(String page, VoidCallback retry) => _retries[page] = retry;

  void _unregister(String page, VoidCallback retry) {
    if (_retries[page] == retry) _retries.remove(page);
  }

  /// Retries [page] when it failed; false when it did not.
  bool retry(String page) {
    final retry = _retries[page];
    retry?.call();
    return retry != null;
  }
}

/// One manga page: loads with the source headers, shows download progress, crops borders, and offers Retry when
/// loading failed. Paged: fitted into the available space; strip: full width at the page's aspect ratio.
class MangaPageImage extends StatefulWidget {
  /// Placeholder aspect ratio of a page in a long strip before it is loaded.
  static const placeholderAspectRatio = 0.7;

  final String page;
  final int number;
  final MangaPageConfig config;

  const MangaPageImage({super.key, required this.page, required this.number, required this.config});

  @override
  State<MangaPageImage> createState() => _MangaPageImageState();
}

class _MangaPageImageState extends State<MangaPageImage> {
  ImageStream? _stream;
  late final _listener = ImageStreamListener(_onImage, onChunk: _onChunk, onError: _onError);
  ImageInfo? _info;
  Rect? _source;
  Object? _error;
  double? _progress;
  int _token = 0;

  MangaPageConfig get _config => widget.config;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(MangaPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.config;
    if (oldWidget.page != widget.page || !mapEquals(old.headers, _config.headers) || old.images != _config.images) {
      _clear();
      _resolve();
    } else if (old.autoCrop != _config.autoCrop || old.cropVertical != _config.cropVertical) {
      final info = _info;
      if (info != null) unawaited(_show(info.clone()));
    }
    if (old.retries != _config.retries && _error != null) {
      old.retries._unregister(widget.page, _retry);
      _config.retries._register(widget.page, _retry);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _config.retries._unregister(widget.page, _retry);
    _info?.dispose();
    super.dispose();
  }

  ImageProvider get _provider => _config.images.provider(widget.page, headers: _config.headers);

  void _resolve() {
    final stream = _provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _clear() {
    _token++;
    _stream?.removeListener(_listener);
    _stream = null;
    _info?.dispose();
    _info = null;
    _source = null;
    _error = null;
    _progress = null;
    _config.retries._unregister(widget.page, _retry);
  }

  void _onImage(ImageInfo info, bool synchronousCall) => unawaited(_show(info));

  /// Takes ownership of [info].
  Future<void> _show(ImageInfo info) async {
    final token = ++_token;
    final image = info.image;
    final full = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    Rect source = full;
    if (_config.autoCrop) {
      final vertical = _config.cropVertical;
      final images = _config.images;
      final CropRect? bounds = images.hasCrop(widget.page, vertical: vertical)
          ? images.cachedCrop(widget.page, vertical: vertical)
          : await images.crop(widget.page, image, vertical: vertical);
      if (bounds != null) {
        source = Rect.fromLTRB(
          bounds.left.toDouble(),
          bounds.top.toDouble(),
          bounds.right.toDouble(),
          bounds.bottom.toDouble(),
        );
      }
    }
    if (!mounted || token != _token) {
      info.dispose();
      return;
    }
    if (source.width > 0 && source.height > 0) {
      _config.images.rememberAspectRatio(widget.page, source.width / source.height);
    }
    _config.retries._unregister(widget.page, _retry);
    setState(() {
      _info?.dispose();
      _info = info;
      _source = source;
      _error = null;
    });
  }

  void _onChunk(ImageChunkEvent event) {
    final total = event.expectedTotalBytes;
    if (total == null || total <= 0) return;
    setState(() => _progress = event.cumulativeBytesLoaded / total);
  }

  void _onError(Object error, StackTrace? stackTrace) {
    if (!mounted) return;
    _config.retries._register(widget.page, _retry);
    setState(() => _error = error);
  }

  void _retry() {
    unawaited(_provider.evict());
    _clear();
    setState(_resolve);
  }

  @override
  Widget build(BuildContext context) {
    final info = _info, source = _source;
    final Widget content;
    final double aspectRatio;
    if (info != null && source != null) {
      aspectRatio = source.width / source.height;
      content = CustomPaint(painter: _PagePainter(info.image, source));
    } else {
      aspectRatio = _config.images.aspectRatio(widget.page) ?? MangaPageImage.placeholderAspectRatio;
      content = _error != null
          ? _PageError(number: widget.number, onRetry: _retry)
          : _PageLoading(number: widget.number, progress: _progress);
    }
    if (_config.strip) return AspectRatio(aspectRatio: aspectRatio, child: content);
    return info == null
        ? content
        : Center(
            child: AspectRatio(aspectRatio: aspectRatio, child: content),
          );
  }
}

class _PagePainter extends CustomPainter {
  final ui.Image image;
  final Rect source;

  _PagePainter(this.image, this.source);

  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
    image,
    source,
    Offset.zero & size,
    Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true,
  );

  @override
  bool shouldRepaint(_PagePainter oldDelegate) => oldDelegate.image != image || oldDelegate.source != source;
}

class _PageLoading extends StatelessWidget {
  final int number;
  final double? progress;

  const _PageLoading({required this.number, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          CircularProgressIndicator(value: progress),
          Text('$number', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _PageError extends StatelessWidget {
  final int number;
  final VoidCallback onRetry;

  const _PageError({required this.number, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Icon(Icons.broken_image_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant),
            Text(context.l10n.readerPageFailed(number), textAlign: TextAlign.center),
            // The D-pad retries the current page with OK; the button is for touch and mouse.
            ExcludeFocus(
              child: FilledButton.tonal(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
            ),
          ],
        ),
      ),
    );
  }
}
