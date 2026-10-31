/// 中文棋谱记法：如「炮二平五」「马8进7」。
library;

import 'dart:typed_data';

import 'engine/board_utils.dart';

class MoveNotation {
  MoveNotation._();

  /// 依据走子前的棋盘生成该步的中文记法。
  static String describe(Uint8List cells, int from, int to) {
    final piece = cells[from];
    if (piece == 0) return '';
    final side = sideOf(piece);
    final type = typeOf(piece);
    final fromRow = rowOf(from);
    final toRow = rowOf(to);
    final fromCol = colOf(from);
    final toCol = colOf(to);
    final name = pieceName(piece);
    final prefix = _positionPrefix(cells, side, type, fromRow, fromCol);
    final head = prefix ?? '$name${_number(side, fileNumber(side, fromCol))}';

    if (fromRow == toRow) {
      return '$head平${_number(side, fileNumber(side, toCol))}';
    }
    final movingForward = side == red ? toRow < fromRow : toRow > fromRow;
    final action = movingForward ? '进' : '退';
    final straight =
        type == typeRook ||
        type == typeCannon ||
        type == typePawn ||
        type == typeKing;
    final value = straight ? (toRow - fromRow).abs() : fileNumber(side, toCol);
    return '$head$action${_number(side, value)}';
  }

  /// 同一列存在同类棋子时用「前/后」区分。
  static String? _positionPrefix(
    Uint8List cells,
    int side,
    int type,
    int fromRow,
    int fromCol,
  ) {
    final target = pieceOf(side, type);
    final rows = <int>[];
    for (var row = 0; row < boardRows; row++) {
      if (cells[indexOf(row, fromCol)] == target) rows.add(row);
    }
    if (rows.length != 2) return null;
    final isFront = side == red ? fromRow == rows.first : fromRow == rows.last;
    return '${isFront ? '前' : '后'}${pieceName(pieceOf(side, type))}';
  }

  /// 红方从右向左数（一至九），黑方从左向右数（1 至 9）。
  static int fileNumber(int side, int col) =>
      side == red ? boardCols - col : col + 1;

  static String _number(int side, int value) {
    if (side == black) return value.toString();
    const digits = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
    if (value >= 0 && value < digits.length) return digits[value];
    return value.toString();
  }
}
