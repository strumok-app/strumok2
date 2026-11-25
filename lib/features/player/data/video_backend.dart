import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../domain/equalizer.dart';
import '../domain/upscaling.dart';

@immutable
final class PlaybackStatus {
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final bool playing;
  final bool buffering;

  /// 0..100.
  final double volume;

  /// Width / height of the video; null until known.
  final double? aspectRatio;

  const PlaybackStatus({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.volume = 100,
    this.aspectRatio,
  });

  PlaybackStatus copyWith({
    Duration? position,
    Duration? duration,
    Duration? buffered,
    bool? playing,
    bool? buffering,
    double? volume,
    double? aspectRatio,
  }) => PlaybackStatus(
    position: position ?? this.position,
    duration: duration ?? this.duration,
    buffered: buffered ?? this.buffered,
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    volume: volume ?? this.volume,
    aspectRatio: aspectRatio ?? this.aspectRatio,
  );

  @override
  bool operator ==(Object other) =>
      other is PlaybackStatus &&
      other.position == position &&
      other.duration == duration &&
      other.buffered == buffered &&
      other.playing == playing &&
      other.buffering == buffering &&
      other.volume == volume &&
      other.aspectRatio == aspectRatio;

  @override
  int get hashCode => Object.hash(position, duration, buffered, playing, buffering, volume, aspectRatio);
}

/// A video or audio track of the current media.
@immutable
final class MediaTrack {
  final String id;
  final String? title;
  final String? language;
  final int? height;
  final int? bitrate;

  const MediaTrack(this.id, {this.title, this.language, this.height, this.bitrate});

  @override
  bool operator ==(Object other) =>
      other is MediaTrack &&
      other.id == id &&
      other.title == title &&
      other.language == language &&
      other.height == height &&
      other.bitrate == bitrate;

  @override
  int get hashCode => Object.hash(id, title, language, height, bitrate);
}

/// Video and audio tracks of the current media; a null selected id means automatic.
@immutable
final class PlaybackTracks {
  final List<MediaTrack> video;
  final List<MediaTrack> audio;
  final String? videoId;
  final String? audioId;

  /// The video track actually playing, resolved by the backend even while selection is automatic ([videoId] null);
  /// null until known. Lets the UI show the real quality behind "Auto" (spec-06 §6.5).
  final String? activeVideoId;

  const PlaybackTracks({this.video = const [], this.audio = const [], this.videoId, this.audioId, this.activeVideoId});

  @override
  bool operator ==(Object other) =>
      other is PlaybackTracks &&
      listEquals(other.video, video) &&
      listEquals(other.audio, audio) &&
      other.videoId == videoId &&
      other.audioId == audioId &&
      other.activeVideoId == activeVideoId;

  @override
  int get hashCode => Object.hash(Object.hashAll(video), Object.hashAll(audio), videoId, audioId, activeVideoId);
}

final class VideoOpenRequest {
  final Uri link;
  final Map<String, String>? headers;
  final Duration start;

  /// Play through the local dejunking HLS proxy (spec-06 §6.4).
  final bool hlsProxy;

  /// Preferred audio/video track languages, most preferred first.
  final List<String> languages;

  const VideoOpenRequest({
    required this.link,
    this.headers,
    this.start = Duration.zero,
    this.hlsProxy = false,
    this.languages = const [],
  });

  @override
  String toString() =>
      'VideoOpenRequest(link: $link, headers: $headers, start: $start, hlsProxy: $hlsProxy, languages: $languages)';
}

/// Playback engine behind the player controller (spec-06 §6.1); one instance per player session.
abstract interface class VideoBackend {
  /// High-frequency playback state; listen narrowly.
  ValueListenable<PlaybackStatus> get status;

  /// The current media reached its end (with the near-EOF tolerance).
  Stream<void> get ended;

  /// Playback of the current media stopped with an error.
  Stream<String> get errors;

  ValueListenable<PlaybackTracks> get tracks;

  /// Replaces the current media and starts playing. Subtitles are not the backend's concern: the player loads and
  /// renders supplier subtitles itself.
  Future<void> open(VideoOpenRequest request);

  Future<void> play();
  Future<void> pause();
  Future<void> playOrPause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> frameStep({required bool forward});

  /// Null selects automatically.
  Future<void> selectVideoTrack(String? id);

  /// Null selects automatically (by the preferred languages).
  Future<void> selectAudioTrack(String? id);

  /// Playback rate, 0.5–2.0.
  Future<void> setSpeed(double speed);

  /// Replaces the audio effects; [AudioEffects.isNeutral] removes them. How they are realized is up to the backend.
  Future<void> setAudioEffects(AudioEffects effects);

  /// Upscalers this backend can run on this device; empty when unsupported (the setting is hidden, spec-13).
  List<Upscaler> get supportedUpscalers;

  /// Null turns upscaling off; an unsupported upscaler counts as off.
  Future<void> setUpscaler(Upscaler? upscaler);

  /// The active upscaler failed and was turned off. Not a playback error: playback continues without it.
  Stream<Upscaler> get upscalerFailures;

  /// The video surface; build it in one place per backend.
  Widget buildView();

  Future<void> dispose();
}
