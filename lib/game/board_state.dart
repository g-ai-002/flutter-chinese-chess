import 'dart:typed_data';

import '../models/move_record.dart';
import 'engine/board_utils.dart';
import 'engine/rules.dart';
import 'notation.dart';

/// 可撤销的棋局状态。
class XiangqiBoard {
  XiangqiBoard._(this.cells, this.sideToMove)
    : _startCells = Uint8List.fromList(cells),
      _startSide = sideToMove {
    positionKeys.add(positionKeyOf(cells, sideToMove));
  }

  factory XiangqiBoard.initial() => XiangqiBoard._(initialCells(), red);

  /// 测试与残局用：从 10 行布局字符串构造（大写为红）。
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

  /// 局面键：行棋方 + 九十个格子的棋子编码，用于重复局面判定。
  static String positionKeyOf(Uint8List cells, int side) =>
      String.fromCharCodes([side, ...cells]);

  final Uint8List cells;
  final Uint8List _startCells;
  final int _startSide;
  int sideToMove;
  final List<MoveRecord> history = [];

  /// 每一步之后的局面键，首项为开局局面。
  final List<String> positionKeys = [];

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
    positionKeys.add(positionKeyOf(cells, sideToMove));
    lastFrom = from;
    lastTo = to;
    return record;
  }

  void reset() {
    cells.setAll(0, _startCells);
    sideToMove = _startSide;
    history.clear();
    positionKeys
      ..clear()
      ..add(positionKeyOf(cells, sideToMove));
    noCapturePlies = 0;
    lastFrom = null;
    lastTo = null;
  }

  MoveRecord? undoLast() {
    if (history.isEmpty) return null;
    final record = history.removeLast();
    positionKeys.removeLast();
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

  /// 当前局面在本次对局中出现的次数（含当前）。
  int get repetitionCount {
    final key = positionKeys.last;
    var count = 0;
    for (final item in positionKeys) {
      if (item == key) count++;
    }
    return count;
  }

  /// 重复循环中步步将军的一方；若无长将或双方互将则返回 null。
  int? get perpetualCheckingSide {
    if (repetitionCount < 3) return null;
    final key = positionKeys.last;
    var start = 0;
    for (var index = 0; index < positionKeys.length; index++) {
      if (positionKeys[index] == key) {
        start = index;
        break;
      }
    }
    return XiangqiRules.perpetualChecker(history.skip(start));
  }
}
