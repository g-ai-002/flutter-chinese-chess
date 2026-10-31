import 'dart:math' as math;

import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color fg, Color bg) {
  final a = fg.computeLuminance();
  final b = bg.computeLuminance();
  final hi = math.max(a, b);
  final lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

int _warmth(Color color) => (color.r * 255).round() - (color.b * 255).round();

void main() {
  test('红黑棋面底色可明显区分', () {
    final redFace = pieceFaceOf(red);
    final blackFace = pieceFaceOf(black);

    expect(redFace.dark, isNot(blackFace.dark));
    expect(redFace.light, isNot(blackFace.light));
    // 红方棋面偏暖，黑方棋面偏中性冷色，色相差异足够肉眼分辨。
    expect(_warmth(redFace.dark) - _warmth(blackFace.dark), greaterThan(40));
    expect(
      (redFace.dark.computeLuminance() - blackFace.dark.computeLuminance())
          .abs(),
      greaterThan(0.02),
    );
  });

  test('棋面与棋子文字保持足够对比度', () {
    for (final side in [red, black]) {
      final face = pieceFaceOf(side);
      expect(
        _contrast(face.ink, face.dark),
        greaterThanOrEqualTo(4.0),
        reason: '第 $side 方棋子文字在棋面上应清晰可读',
      );
      expect(_contrast(face.ink, face.light), greaterThanOrEqualTo(5.0));
    }
  });
}
