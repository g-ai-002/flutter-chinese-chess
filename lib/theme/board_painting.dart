import 'package:flutter/material.dart';

import '../game/engine/board_utils.dart';
import 'app_theme.dart';

/// 绘制一枚棋子：投影、棋面渐变、外圈与内圈，字面以传入的 [label] 居中绘制。
///
/// Flame 棋盘与首页缩略图共用同一套棋子质感；[innerRingWidth] 为 0 时不画内圈。
void paintPieceDisc(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required PieceFace face,
  required TextPainter label,
  double borderWidth = 1.6,
  double innerRingWidth = 0,
  double shadowBlur = 2,
  double opacity = 1,
}) {
  canvas.drawCircle(
    center.translate(0, radius * 0.08),
    radius * 1.02,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.18 * opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur),
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 0.95,
        colors: [
          face.light.withValues(alpha: opacity),
          face.dark.withValues(alpha: opacity),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius)),
  );
  canvas.drawCircle(
    center,
    radius * 0.82,
    Paint()..color = face.dark.withValues(alpha: 0.35 * opacity),
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..color = face.ink.withValues(alpha: 0.9 * opacity),
  );
  if (innerRingWidth > 0) {
    canvas.drawCircle(
      center,
      radius * 0.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = innerRingWidth
        ..color = face.ink.withValues(alpha: 0.5 * opacity),
    );
  }
  label.paint(canvas, center - Offset(label.width / 2, label.height / 2));
}

/// 绘制棋盘网格：十条横线、九条竖线（楚河汉界处断开）、两处九宫斜线与外框。
///
/// [topLeft] 是棋盘左上角交叉点的位置，[cell] 是格宽；Flame 棋盘与首页缩略图共用。
void paintBoardGrid(
  Canvas canvas, {
  required Offset topLeft,
  required double cell,
  required Paint linePaint,
  Paint? palacePaint,
  Paint? borderPaint,
}) {
  final left = topLeft.dx;
  final top = topLeft.dy;
  final right = left + cell * (boardCols - 1);
  final bottom = top + cell * (boardRows - 1);
  final palace = palacePaint ?? linePaint;

  for (var row = 0; row < boardRows; row++) {
    final y = top + row * cell;
    canvas.drawLine(Offset(left, y), Offset(right, y), linePaint);
  }

  for (var col = 0; col < boardCols; col++) {
    final x = left + col * cell;
    if (col == 0 || col == boardCols - 1) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), linePaint);
      continue;
    }
    canvas.drawLine(Offset(x, top), Offset(x, top + cell * 4), linePaint);
    canvas.drawLine(Offset(x, top + cell * 5), Offset(x, bottom), linePaint);
  }

  for (final topRow in const [0, 7]) {
    final y0 = top + topRow * cell;
    final y1 = y0 + cell * 2;
    canvas.drawLine(
      Offset(left + cell * 3, y0),
      Offset(left + cell * 5, y1),
      palace,
    );
    canvas.drawLine(
      Offset(left + cell * 5, y0),
      Offset(left + cell * 3, y1),
      palace,
    );
  }

  if (borderPaint != null) {
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), borderPaint);
  }
}
