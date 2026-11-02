import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'log_service.dart';

/// 落子反馈类型，决定提示音与震动的强弱。
enum MoveFeedback { move, capture, check, end }

/// 落子音效与触感反馈。
///
/// 音效使用随包音频资源，Android、Windows 与 Web 走同一套播放器；
/// Web 端的自动播放限制会在用户首次操作页面后解除。
class SoundService {
  SoundService._();

  static bool soundEnabled = true;
  static bool hapticsEnabled = true;

  /// 测试注入的音频出口，非空时不再触碰平台播放器。
  @visibleForTesting
  static void Function(MoveFeedback feedback)? sink;

  static final Map<MoveFeedback, AudioPlayer> _players = {};
  static Future<void>? _loading;
  static bool _loadFailed = false;

  static const Map<MoveFeedback, String> _assets = {
    MoveFeedback.move: 'audio/move.wav',
    MoveFeedback.capture: 'audio/capture.wav',
    MoveFeedback.check: 'audio/check.wav',
    MoveFeedback.end: 'audio/end.wav',
  };

  static void configure({required bool sound, required bool haptics}) {
    soundEnabled = sound;
    hapticsEnabled = haptics;
  }

  /// 预加载音频资源；失败时保持静默，不影响对局。
  static Future<void> init() => _ensureLoaded();

  static Future<void> _ensureLoaded() {
    if (_loadFailed || _players.isNotEmpty) return Future.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      for (final entry in _assets.entries) {
        final player = AudioPlayer(playerId: 'xiangqi-${entry.key.name}');
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(AssetSource(entry.value));
        _players[entry.key] = player;
      }
    } catch (error) {
      _loadFailed = true;
      debugPrint('[SoundService] 音频资源加载失败，已静音: $error');
      LogService.warning('音频资源加载失败，已静音: $error');
    }
  }

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
        unawaited(_playAsset(feedback));
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

  static Future<void> _playAsset(MoveFeedback feedback) async {
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
    _loading = null;
    _loadFailed = false;
    soundEnabled = true;
    hapticsEnabled = true;
  }
}
