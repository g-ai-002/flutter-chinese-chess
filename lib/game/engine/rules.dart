/// 中国象棋规则：走子生成、将军判定、将军/困毙判定。
library;

import 'dart:typed_data';

import 'board_utils.dart';

/// 一步棋编码为 `from * 90 + to`，便于在搜索中快速传递。
int encodeMove(int from, int to) => from * cellCount + to;
int moveFrom(int move) => move ~/ cellCount;
int moveTo(int move) => move % cellCount;

class XiangqiRules {
  XiangqiRules._();

  static const List<(int, int)> _orthogonal = [
    (-1, 0),
    (1, 0),
    (0, -1),
    (0, 1),
  ];

  static const List<(int, int)> _diagonal = [
    (-1, -1),
    (-1, 1),
    (1, -1),
    (1, 1),
  ];

  static const List<(int, int)> _horseSteps = [
    (-2, -1),
    (-2, 1),
    (-1, -2),
    (-1, 2),
    (1, -2),
    (1, 2),
    (2, -1),
    (2, 1),
  ];

  static int? findKing(Uint8List cells, int side) {
    final target = pieceOf(side, typeKing);
    for (var index = 0; index < cellCount; index++) {
      if (cells[index] == target) return index;
    }
    return null;
  }

  /// 生成伪合法着法（未过滤"送将"与"对脸"）。
  static List<int> pseudoMoves(Uint8List cells, int side) {
    final moves = <int>[];
    for (var index = 0; index < cellCount; index++) {
      final piece = cells[index];
      if (piece == 0 || sideOf(piece) != side) continue;
      _addPieceMoves(cells, side, index, piece, moves);
    }
    return moves;
  }

  /// 某个棋子可走的位置（伪合法）。
  static List<int> pseudoMovesFrom(Uint8List cells, int from) {
    final piece = cells[from];
    if (piece == 0) return const [];
    final moves = <int>[];
    _addPieceMoves(cells, sideOf(piece), from, piece, moves);
    return moves;
  }

  static void _addPieceMoves(
    Uint8List cells,
    int side,
    int from,
    int piece,
    List<int> moves,
  ) {
    final row = rowOf(from);
    final col = colOf(from);
    switch (typeOf(piece)) {
      case typeKing:
        for (final (dr, dc) in _orthogonal) {
          final nr = row + dr;
          final nc = col + dc;
          if (!inPalace(side, nr, nc)) continue;
          _tryAdd(cells, side, from, nr, nc, moves);
        }
      case typeAdvisor:
        for (final (dr, dc) in _diagonal) {
          final nr = row + dr;
          final nc = col + dc;
          if (!inPalace(side, nr, nc)) continue;
          _tryAdd(cells, side, from, nr, nc, moves);
        }
      case typeElephant:
        for (final (dr, dc) in _diagonal) {
          final nr = row + dr * 2;
          final nc = col + dc * 2;
          if (!inBoard(nr, nc)) continue;
          if (side == red ? nr < 5 : nr > 4) continue;
          if (cells[indexOf(row + dr, col + dc)] != 0) continue;
          _tryAdd(cells, side, from, nr, nc, moves);
        }
      case typeHorse:
        for (final (dr, dc) in _horseSteps) {
          final nr = row + dr;
          final nc = col + dc;
          if (!inBoard(nr, nc)) continue;
          final legRow = dr.abs() == 2 ? row + dr ~/ 2 : row;
          final legCol = dc.abs() == 2 ? col + dc ~/ 2 : col;
          if (cells[indexOf(legRow, legCol)] != 0) continue;
          _tryAdd(cells, side, from, nr, nc, moves);
        }
      case typeRook:
        for (final (dr, dc) in _orthogonal) {
          var nr = row + dr;
          var nc = col + dc;
          while (inBoard(nr, nc)) {
            final target = cells[indexOf(nr, nc)];
            if (target == 0) {
              moves.add(encodeMove(from, indexOf(nr, nc)));
            } else {
              if (sideOf(target) != side) {
                moves.add(encodeMove(from, indexOf(nr, nc)));
              }
              break;
            }
            nr += dr;
            nc += dc;
          }
        }
      case typeCannon:
        for (final (dr, dc) in _orthogonal) {
          var nr = row + dr;
          var nc = col + dc;
          var screenFound = false;
          while (inBoard(nr, nc)) {
            final target = cells[indexOf(nr, nc)];
            if (!screenFound) {
              if (target == 0) {
                moves.add(encodeMove(from, indexOf(nr, nc)));
              } else {
                screenFound = true;
              }
            } else if (target != 0) {
              if (sideOf(target) != side) {
                moves.add(encodeMove(from, indexOf(nr, nc)));
              }
              break;
            }
            nr += dr;
            nc += dc;
          }
        }
      case typePawn:
        final forward = pawnForward(side);
        _tryAdd(cells, side, from, row + forward, col, moves);
        if (hasCrossedRiver(side, row)) {
          _tryAdd(cells, side, from, row, col - 1, moves);
          _tryAdd(cells, side, from, row, col + 1, moves);
        }
    }
  }

  static void _tryAdd(
    Uint8List cells,
    int side,
    int from,
    int row,
    int col,
    List<int> moves,
  ) {
    if (!inBoard(row, col)) return;
    final target = cells[indexOf(row, col)];
    if (target != 0 && sideOf(target) == side) return;
    moves.add(encodeMove(from, indexOf(row, col)));
  }

  /// 将帅照面（同列且中间无子）。
  static bool kingsFacing(Uint8List cells) {
    final redKing = findKing(cells, red);
    final blackKing = findKing(cells, black);
    if (redKing == null || blackKing == null) return false;
    if (colOf(redKing) != colOf(blackKing)) return false;
    final col = colOf(redKing);
    final top = rowOf(blackKing);
    final bottom = rowOf(redKing);
    for (var row = top + 1; row < bottom; row++) {
      if (cells[indexOf(row, col)] != 0) return false;
    }
    return true;
  }

  /// 当前行动方的将/帅是否被将军（含将帅照面）。
  static bool isKingInCheck(Uint8List cells, int side) {
    final king = findKing(cells, side);
    if (king == null) return false;
    final kr = rowOf(king);
    final kc = colOf(king);
    final enemy = opponentOf(side);

    for (final (dr, dc) in _orthogonal) {
      var row = kr + dr;
      var col = kc + dc;
      var screenFound = false;
      while (inBoard(row, col)) {
        final piece = cells[indexOf(row, col)];
        if (piece != 0) {
          if (!screenFound) {
            if (sideOf(piece) == enemy) {
              final type = typeOf(piece);
              if (type == typeRook) return true;
              if (type == typeKing && dc == 0) return true;
            }
            screenFound = true;
          } else {
            if (sideOf(piece) == enemy && typeOf(piece) == typeCannon) {
              return true;
            }
            break;
          }
        }
        row += dr;
        col += dc;
      }
    }

    for (final (dr, dc) in _horseSteps) {
      final hr = kr + dr;
      final hc = kc + dc;
      if (!inBoard(hr, hc)) continue;
      final piece = cells[indexOf(hr, hc)];
      if (piece == 0 || sideOf(piece) != enemy || typeOf(piece) != typeHorse) {
        continue;
      }
      final legRow = dr.abs() == 2 ? hr - dr ~/ 2 : hr;
      final legCol = dc.abs() == 2 ? hc - dc ~/ 2 : hc;
      if (cells[indexOf(legRow, legCol)] == 0) return true;
    }

    final forwardRow = kr - pawnForward(enemy);
    if (inBoard(forwardRow, kc) &&
        cells[indexOf(forwardRow, kc)] == pieceOf(enemy, typePawn)) {
      return true;
    }
    if (hasCrossedRiver(enemy, kr)) {
      for (final dc in const [-1, 1]) {
        final pc = kc + dc;
        if (!inBoard(kr, pc)) continue;
        if (cells[indexOf(kr, pc)] == pieceOf(enemy, typePawn)) return true;
      }
    }
    return false;
  }

  /// 试走一步并判断是否合法（不送将、不对脸），结束后恢复棋盘。
  static bool isLegalMove(Uint8List cells, int side, int from, int to) {
    final piece = cells[from];
    final captured = cells[to];
    cells[to] = piece;
    cells[from] = 0;
    final legal = !kingsFacing(cells) && !isKingInCheck(cells, side);
    cells[from] = piece;
    cells[to] = captured;
    return legal;
  }

  /// 全部合法着法。
  static List<int> legalMoves(Uint8List cells, int side) {
    final result = <int>[];
    for (final move in pseudoMoves(cells, side)) {
      if (isLegalMove(cells, side, moveFrom(move), moveTo(move))) {
        result.add(move);
      }
    }
    return result;
  }

  static List<int> legalMovesFrom(Uint8List cells, int from) {
    final piece = cells[from];
    if (piece == 0) return const [];
    final side = sideOf(piece);
    return [
      for (final move in pseudoMovesFrom(cells, from))
        if (isLegalMove(cells, side, from, moveTo(move))) move,
    ];
  }

  /// 走子后对下一方的判定：是否被将军、是否还有合法着法。
  static ({bool inCheck, bool hasLegalMoves}) positionStatus(
    Uint8List cells,
    int side,
  ) {
    final moves = legalMoves(cells, side);
    return (
      inCheck: isKingInCheck(cells, side),
      hasLegalMoves: moves.isNotEmpty,
    );
  }
}
