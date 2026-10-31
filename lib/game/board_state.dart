import 'dart:typed_data';

import '../models/move_record.dart';
import 'engine/board_utils.dart';
import 'engine/rules.dart';
import 'notation.dart';

/// 可撤销的棋局状态。
class XiangqiBoard {
  XiangqiBoard._(this.cells, this.sideToMove);

  factory XiangqiBoard.initial() => XiangqiBoard._(initialCells(), red);

  /// 测试用：从 10 行布局字符串构造（大写为红）。
  factory XiangqiBoard.fromLayout(List<String> rows, {int sideToMove = red}) {
    final cells = Uint8List(cellCount);
    const mapping = {
      'K': typeKing,
      'A': typeAdvisor,
      'E': typeElephant,
      'H': typeHorse,
      'R': typeRook,
      'C': typeCannon,
      'P': typePawn,
    };
    for (var row = 0; row < boardRows; row++) {
      for (var col = 0; col < boardCols; col++) {
        final ch = rows[row][col];
        if (ch == '.') continue;
        final isRed = ch == ch.toUpperCase();
        cells[indexOf(row, col)] = pieceOf(
          isRed ? red : black,
          mapping[ch.toUpperCase()]!,
        );
      }
    }
    return XiangqiBoard._(cells, sideToMove);
  }

  final Uint8List cells;
  int sideToMove;
  final List<MoveRecord> history = [];
  int noCapturePlies = 0;
  int? lastFrom;
  int? lastTo;

  /// 落子（调用方需先保证着法合法），返回记录。
  MoveRecord applyMove(int from, int to) {
    final piece = cells[from];
    final captured = cells[to];
    final mover = sideOf(piece);
    final notation = MoveNotation.describe(cells, from, to);
    final previousNoCapture = noCapturePlies;

    cells[to] = piece;
    cells[from] = 0;
    sideToMove = opponentOf(mover);
    noCapturePlies = captured == 0 ? previousNoCapture + 1 : 0;
    final givesCheck = XiangqiRules.isKingInCheck(cells, sideToMove);

    final record = MoveRecord(
      from: from,
      to: to,
      piece: piece,
      captured: captured,
      notation: notation,
      givesCheck: givesCheck,
      noCaptureBefore: previousNoCapture,
    );
    history.add(record);
    lastFrom = from;
    lastTo = to;
    return record;
  }

  void reset() {
    cells.setAll(0, initialCells());
    sideToMove = red;
    history.clear();
    noCapturePlies = 0;
    lastFrom = null;
    lastTo = null;
  }

  MoveRecord? undoLast() {
    if (history.isEmpty) return null;
    final record = history.removeLast();
    cells[record.from] = record.piece;
    cells[record.to] = record.captured;
    sideToMove = sideOf(record.piece);
    noCapturePlies = record.noCaptureBefore;
    if (history.isEmpty) {
      lastFrom = null;
      lastTo = null;
    } else {
      lastFrom = history.last.from;
      lastTo = history.last.to;
    }
    return record;
  }
}
