import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'log_service.dart';
import 'tone_synth.dart';

/// 落子反馈类型，决定提示音与震动的强弱。
enum MoveFeedback { move, capture, check, end }

/// 落子音效与触感反馈。
///
/// 音效由 [synthesizeWav] 在运行时合成，不随包携带音频文件；合成好的
/// WAV 交给 flutter_soloud 的内存音源播放，Android、Windows 与 Web 共用
/// 同一套实现，Web 的自动播放限制会在用户首次操作页面后解除。
class SoundService {
  SoundService._();

  static bool soundEnabled = true;
  static bool hapticsEnabled = true;

  /// 测试注入的音频出口，非空时不再触碰平台播放器。
  @visibleForTesting
  static void Function(MoveFeedback feedback)? sink;

  static final Map<MoveFeedback, AudioSource> _sources = {};
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
        frequency: 960,
        start: 0,
        duration: 0.035,
        gain: 0.42,
        noise: 0.55,
      ),
      SynthNote(
        frequency: 430,
        start: 0,
        duration: 0.09,
        gain: 0.7,
        noise: 0.22,
      ),
      SynthNote(
        frequency: 175,
        start: 0.008,
        duration: 0.17,
        gain: 0.75,
        noise: 0.3,
      ),
      SynthNote(
        frequency: 720,
        start: 0.045,
        duration: 0.12,
        gain: 0.28,
        noise: 0.42,
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

  /// 预合成音效并载入 SoLoud 音源；失败时保持静默，不影响对局。
  static Future<void> init() => _ensureLoaded();

  static Future<void> _ensureLoaded() {
    if (_loadFailed || _sources.isNotEmpty) return Future.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) await soloud.init();
      for (final feedback in MoveFeedback.values) {
        _sources[feedback] = await soloud.loadMem(
          'xiangqi-${feedback.name}.wav',
          clipOf(feedback),
        );
      }
    } catch (error) {
      _loadFailed = true;
      _disposeAll();
      debugPrint('[SoundService] 音效初始化失败，已静音: $error');
      LogService.warning('音效初始化失败，已静音: $error');
    }
  }

  /// 某个反馈对应的合成音频，供测试校验音效配方。
  @visibleForTesting
  static Uint8List clipOf(MoveFeedback feedback) =>
      _clips.putIfAbsent(feedback, () => synthesizeWav(_presets[feedback]!));

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
      final source = _sources[feedback];
      if (source == null) return;
      final soloud = SoLoud.instance;
      soloud.stopAudioSource(source);
      soloud.play(source);
    } catch (error) {
      debugPrint('[SoundService] 播放失败: $error');
    }
  }

  static void _disposeAll() {
    final sources = _sources.values.toList();
    _sources.clear();
    for (final source in sources) {
      unawaited(_dispose(source));
    }
  }

  static Future<void> _dispose(AudioSource source) async {
    try {
      await SoLoud.instance.disposeSource(source);
    } catch (_) {
      // 音源已失效时无需再处理。
    }
  }

  @visibleForTesting
  static void reset() {
    sink = null;
    _disposeAll();
    _clips.clear();
    _loading = null;
    _loadFailed = false;
    soundEnabled = true;
    hapticsEnabled = true;
  }
}
