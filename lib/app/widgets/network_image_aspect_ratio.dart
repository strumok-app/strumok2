import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/image_cache.dart';
import 'app_network_image.dart';

/// Natural aspect ratio (width / height) of a network image, for sizing an [AppNetworkImage] showing it.
///
/// `aspectRatio` is null until the image is decoded; `unavailable` means there is no image to show (invalid url or
/// load error). Resolves through the same provider, and so the same image cache entry, as [AppNetworkImage]:
/// a cached image is reported before the first build.
class NetworkImageAspectRatio extends ConsumerStatefulWidget {
  final String url;
  final Widget Function(BuildContext context, double? aspectRatio, bool unavailable) builder;

  const NetworkImageAspectRatio({super.key, required this.url, required this.builder});

  @override
  ConsumerState<NetworkImageAspectRatio> createState() => _NetworkImageAspectRatioState();
}

class _NetworkImageAspectRatioState extends ConsumerState<NetworkImageAspectRatio> {
  ImageStream? _stream;
  late final _listener = ImageStreamListener(_onImage, onError: _onError);
  var _resolving = false;

  double? _aspectRatio;
  var _failed = false;

  bool get _hasUrl => Uri.tryParse(widget.url)?.hasScheme == true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(NetworkImageAspectRatio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _aspectRatio = null;
      _failed = false;
      _resolve();
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  void _resolve() {
    if (!_hasUrl) {
      _stream?.removeListener(_listener);
      _stream = null;
      return;
    }
    final provider = CachedNetworkImageProvider(widget.url, cacheManager: ref.read(imageCacheManagerProvider));
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream;
    // A cached image is delivered synchronously, during this (build-phase) call: no setState then.
    _resolving = true;
    stream.addListener(_listener);
    _resolving = false;
  }

  void _update(VoidCallback change) => _resolving || !mounted ? change() : setState(change);

  void _onImage(ImageInfo info, bool synchronousCall) {
    final image = info.image;
    final ratio = image.height > 0 ? image.width / image.height : null;
    info.dispose();
    if (ratio != null && ratio != _aspectRatio) _update(() => _aspectRatio = ratio);
  }

  void _onError(Object error, StackTrace? stackTrace) {
    if (!_failed) _update(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _aspectRatio, !_hasUrl || _failed);
}
