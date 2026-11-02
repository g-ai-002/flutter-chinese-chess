import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'log_service.dart';
import 'tone_synth.dart';

/// 落子反馈类型，决定提示音与震动的强弱。
enum MoveFeedback { move, capture, check, end }

/// 落子音效与触感反馈。
///
/// 音效由 [synthesizeWav] 在运行时合成，不随包携带音频文件；
/// Android、Windows 与 Web 通过内存字节播放，Web 的自动播放限制会在
/// 用户首次操作页面后解除。
class SoundService {
  SoundService._();

  static bool soundEnabled = true;
  static bool hapticsEnabled = true;

  /// 测试注入的音频出口，非空时不再触碰平台播放器。
  @visibleForTesting
  static void Function(MoveFeedback feedback)? sink;

  static final Map<MoveFeedback, AudioPlayer> _players = {};
  static final Map<MoveFeedback, Uint8List> _clips = {};
  static Future<void>? _loading;
  static bool _loadFailed = false;

  /// 四级音效的乐音配方：普通落子轻脆，吃子低沉，将军上行，终局下行收束。
  static const Map<MoveFeedback, List<SynthNote>> _presets = {
    MoveFeedback.move: [
      SynthNote(
        frequency: 1180,
        start: 0,
        duration: 0.055,
        gain: 0.55,
        noise: 0.12,
      ),
      SynthNote(
        frequency: 760,
        start: 0.004,
        duration: 0.085,
        gain: 0.34,
        noise: 0.06,
      ),
    ],
    MoveFeedback.capture: [
      SynthNote(
        frequency: 430,
        start: 0,
        duration: 0.09,
        gain: 0.7,
        noise: 0.16,
      ),
      SynthNote(
        frequency: 175,
        start: 0.008,
        duration: 0.17,
        gain: 0.75,
        noise: 0.24,
      ),
    ],
    MoveFeedback.check: [
      SynthNote(frequency: 880, start: 0, duration: 0.1),
      SynthNote(frequency: 1320, start: 0.085, duration: 0.15),
    ],
    MoveFeedback.end: [
      SynthNote(frequency: 660, start: 0, duration: 0.14),
      SynthNote(frequency: 494, start: 0.11, duration: 0.16),
      SynthNote(frequency: 330, start: 0.22, duration: 0.3, gain: 0.55),
    ],
  };

  static void configure({required bool sound, required bool haptics}) {
    soundEnabled = sound;
    hapticsEnabled = haptics;
  }

  /// 预合成音效并准备播放器；失败时保持静默，不影响对局。
  static Future<void> init() => _ensureLoaded();

  static Future<void> _ensureLoaded() {
    if (_loadFailed || _players.isNotEmpty) return Future.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      for (final feedback in MoveFeedback.values) {
        final player = AudioPlayer(playerId: 'xiangqi-${feedback.name}');
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(_sourceOf(feedback));
        _players[feedback] = player;
      }
    } catch (error) {
      _loadFailed = true;
      for (final player in _players.values) {
        unawaited(player.dispose());
      }
      _players.clear();
      debugPrint('[SoundService] 音效初始化失败，已静音: $error');
      LogService.warning('音效初始化失败，已静音: $error');
    }
  }

  static BytesSource _sourceOf(MoveFeedback feedback) =>
      BytesSource(clipOf(feedback), mimeType: 'audio/wav');

  /// 某个反馈对应的合成音频，供测试校验音效配方。
  @visibleForTesting
  static Uint8List clipOf(MoveFeedback feedback) => _clips.putIfAbsent(
    feedback,
    () => synthesizeWav(_presets[feedback]!),
  );

  /// 选中棋子的轻触感：只走触感，不播放提示音。
  static void tap() {
    if (hapticsEnabled) HapticFeedback.selectionClick();
  }

  static void play(MoveFeedback feedback) {
    if (soundEnabled) {
      final target = sink;
      if (target != null) {
        target(feedback);
      } else {
        unawaited(_play(feedback));
      }
    }
    if (!hapticsEnabled) return;
    final haptic = switch (feedback) {
      MoveFeedback.move => HapticFeedback.selectionClick,
      MoveFeedback.capture => HapticFeedback.mediumImpact,
      MoveFeedback.check => HapticFeedback.heavyImpact,
      MoveFeedback.end => HapticFeedback.vibrate,
    };
    haptic();
  }

  static Future<void> _play(MoveFeedback feedback) async {
    try {
      await _ensureLoaded();
      final player = _players[feedback];
      if (player == null) return;
      await player.stop();
      await player.resume();
    } catch (error) {
      debugPrint('[SoundService] 播放失败: $error');
    }
  }

  @visibleForTesting
  static void reset() {
    sink = null;
    for (final player in _players.values) {
      unawaited(player.dispose());
    }
    _players.clear();
    _clips.clear();
    _loading = null;
    _loadFailed = false;
    soundEnabled = true;
    hapticsEnabled = true;
  }
}
