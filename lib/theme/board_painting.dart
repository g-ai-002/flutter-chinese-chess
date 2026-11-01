import 'package:flutter/material.dart';

import '../game/engine/board_utils.dart';

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
