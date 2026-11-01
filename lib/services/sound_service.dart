import 'package:flutter/services.dart';

/// 落子反馈类型，决定提示音与震动的强弱。
enum MoveFeedback { move, capture, check, end }

/// 轻量音效与触感反馈：使用系统提示音与系统震动，不额外打包音频资源。
///
/// 开关由设置页同步；重复调用 [configure] 无副作用。
class SoundService {
  SoundService._();

  static bool soundEnabled = true;
  static bool hapticsEnabled = true;

  static void configure({required bool sound, required bool haptics}) {
    soundEnabled = sound;
    hapticsEnabled = haptics;
  }

  static void play(MoveFeedback feedback) {
    if (soundEnabled) {
      SystemSound.play(
        feedback == MoveFeedback.move
            ? SystemSoundType.click
            : SystemSoundType.alert,
      );
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
}
