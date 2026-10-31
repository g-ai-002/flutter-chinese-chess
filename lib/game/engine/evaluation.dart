import 'dart:typed_data';

import 'board_utils.dart';

/// 局面评估：子力价值 + 简单位置分，返回值以红方视角为正。
class XiangqiEvaluation {
  XiangqiEvaluation._();

  /// 索引为棋子类型：空、帅/将、仕/士、相/象、马、车、炮、兵/卒。
  static const List<int> pieceValues = [0, 10000, 220, 220, 420, 900, 460, 100];

  static int evaluate(Uint8List cells) {
    var score = 0;
    var redAdvisors = 0;
    var blackAdvisors = 0;
    var redElephants = 0;
    var blackElephants = 0;

    for (var index = 0; index < cellCount; index++) {
      final piece = cells[index];
      if (piece == 0) continue;
      final side = sideOf(piece);
      final type = typeOf(piece);
      final row = rowOf(index);
      final col = colOf(index);
      var value = pieceValues[type];

      switch (type) {
        case typePawn:
          if (hasCrossedRiver(side, row)) {
            value += 90;
            final advancement = side == red ? 4 - row : row - 5;
            value += advancement * 12;
            value += (4 - (col - 4).abs()) * 4;
          }
        case typeHorse:
          value += (4 - (col - 4).abs()) * 8;
          value += side == red ? (6 - row) * 4 : (row - 3) * 4;
        case typeCannon:
          value += (4 - (col - 4).abs()) * 6;
          if (hasCrossedRiver(side, row)) value += 12;
        case typeRook:
          value += (4 - (col - 4).abs()) * 4;
          value += side == red ? (8 - row) * 3 : (row - 1) * 3;
        case typeAdvisor:
          if (side == red) {
            redAdvisors++;
          } else {
            blackAdvisors++;
          }
        case typeElephant:
          if (side == red) {
            redElephants++;
          } else {
            blackElephants++;
          }
      }
      score += side == red ? value : -value;
    }

    // 缺士少象的一方，帅/将安全感下降。
    score -= (2 - redAdvisors) * 25;
    score -= (2 - redElephants) * 15;
    score += (2 - blackAdvisors) * 25;
    score += (2 - blackElephants) * 15;
    return score;
  }

  static int evaluateForSide(Uint8List cells, int side) =>
      side == red ? evaluate(cells) : -evaluate(cells);
}
