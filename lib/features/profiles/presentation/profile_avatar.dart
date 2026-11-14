import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/image_cache.dart';
import '../domain/profile.dart';

/// Google photo of a linked profile (spec-05 §5.1); otherwise, or while it loads/fails, the color and initial.
class ProfileAvatar extends ConsumerWidget {
  final Profile profile;
  final double radius;

  const ProfileAvatar({super.key, required this.profile, this.radius = 20});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(profile.colorSeed);
    final foreground = ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;
    final photo = profile.accountPhotoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      foregroundImage: photo == null || photo.isEmpty
          ? null
          : CachedNetworkImageProvider(photo, cacheManager: ref.watch(imageCacheManagerProvider)),
      onForegroundImageError: photo == null || photo.isEmpty ? null : (_, _) {},
      child: Text(
        profile.initial,
        style: TextStyle(color: foreground, fontSize: radius * 0.9, fontWeight: FontWeight.w600),
      ),
    );
  }
}
