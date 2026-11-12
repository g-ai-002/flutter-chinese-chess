import 'dart:typed_data';

import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/engine/rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试辅助：按 (棋子字符, 行, 列) 摆放的棋盘。
Uint8List boardWith(List<(String, int, int)> pieces) {
  final cells = Uint8List(cellCount);
  for (final (symbol, row, col) in pieces) {
    cells[indexOf(row, col)] = pieceFromSymbol(symbol);
  }
  return cells;
}

void main() {
  group('初始局面', () {
    test('红方共有 44 种合法着法', () {
      final cells = initialCells();
      expect(XiangqiRules.legalMoves(cells, red).length, 44);
      expect(XiangqiRules.legalMoves(cells, black).length, 44);
    });

    test('初始局面双方均未被将军', () {
      final cells = initialCells();
      expect(XiangqiRules.isKingInCheck(cells, red), isFalse);
      expect(XiangqiRules.isKingInCheck(cells, black), isFalse);
      expect(XiangqiRules.isKingInCheck(cells, red), isFalse);
    });
  });

  group('兵/卒', () {
    test('未过河只能向前', () {
      final cells = boardWith([('P', 6, 4), ('K', 9, 3), ('k', 0, 4)]);
      final targets = XiangqiRules.pseudoMovesFrom(
        cells,
        indexOf(6, 4),
      ).map(moveTo).toSet();
      expect(targets, {indexOf(5, 4)});
    });

    test('过河后可左右移动', () {
      final cells = boardWith([('P', 4, 4), ('K', 9, 3), ('k', 0, 4)]);
      final targets = XiangqiRules.pseudoMovesFrom(
        cells,
        indexOf(4, 4),
      ).map(moveTo).toSet();
      expect(targets, {indexOf(3, 4), indexOf(4, 3), indexOf(4, 5)});
    });
  });

  group('马', () {
    test('马腿被挡时无法前进', () {
      final cells = boardWith([
        ('H', 9, 1),
        ('P', 8, 1),
        ('K', 9, 4),
        ('k', 0, 4),
      ]);
      final targets = XiangqiRules.pseudoMovesFrom(
        cells,
        indexOf(9, 1),
      ).map(moveTo).toSet();
      expect(targets.contains(indexOf(7, 0)), isFalse);
      expect(targets.contains(indexOf(7, 2)), isFalse);
    });

    test('马可以走日字并吃子', () {
      final cells = boardWith([
        ('H', 9, 1),
        ('p', 7, 0),
        ('K', 9, 4),
        ('k', 0, 4),
      ]);
      final targets = XiangqiRules.pseudoMovesFrom(
        cells,
        indexOf(9, 1),
      ).map(moveTo).toSet();
      expect(targets.contains(indexOf(7, 0)), isTrue);
      expect(targets.contains(indexOf(7, 2)), isTrue);
    });
  });

  group('炮', () {
    test('无炮架时不能隔空吃子', () {
      final cells = boardWith([
        ('C', 9, 0),
        ('r', 7, 0),
        ('K', 9, 4),
        ('k', 0, 3),
      ]);
      final targets = XiangqiRules.pseudoMovesFrom(
        cells,
        indexOf(9, 0),
      ).map(moveTo).toSet();
      expect(targets.contains(indexOf(8, 0)), isTrue);
      expect(targets.contains(indexOf(7, 0)), isFalse);
    });

    test('有炮架时可以隔子吃子', () {
      final cells = boardWith([
        ('C', 9, 0),
        ('P', 8, 0),
        ('r', 7, 0),
        ('K', 9, 4),
        ('k', 0, 3),
      ]);
      final targets = XiangqiRules.pseudoMovesFrom(
        cells,
        indexOf(9, 0),
      ).map(moveTo).toSet();
      expect(targets.contains(indexOf(7, 0)), isTrue);
    });
  });

  group('相/象', () {
    test('相不能过河', () {
      final cells = boardWith([('E', 5, 2), ('K', 9, 4), ('k', 0, 4)]);
      final targets = XiangqiRules.pseudoMovesFrom(
        cells,
        indexOf(5, 2),
      ).map(moveTo).toSet();
      expect(targets, {indexOf(7, 0), indexOf(7, 4)});
    });

    test('塞象眼时不能飞', () {
      final cells = boardWith([
        ('E', 9, 2),
        ('P', 8, 3),
        ('K', 9, 4),
        ('k', 0, 4),
      ]);
      final targets = XiangqiRules.pseudoMovesFrom(
        cells,
        indexOf(9, 2),
      ).map(moveTo).toSet();
      expect(targets.contains(indexOf(7, 4)), isFalse);
      expect(targets.contains(indexOf(7, 0)), isTrue);
    });
  });

  group('仕/士', () {
    test('仕只能在九宫内斜走', () {
      final cells = boardWith([('A', 7, 3), ('K', 9, 4), ('k', 0, 4)]);
      final targets = XiangqiRules.pseudoMovesFrom(
        cells,
        indexOf(7, 3),
      ).map(moveTo).toSet();
      expect(targets, {indexOf(8, 4)});
    });
  });

  group('将/帅', () {
    test('将帅对脸判为非法', () {
      final cells = boardWith([('K', 9, 4), ('k', 0, 4)]);
      expect(XiangqiRules.isKingInCheck(cells, red), isTrue);
      expect(
        XiangqiRules.isLegalMove(cells, red, indexOf(9, 4), indexOf(8, 4)),
        isFalse,
      );
    });

    test('不能走入对方车的攻击线', () {
      final cells = boardWith([('K', 9, 4), ('k', 0, 3), ('r', 5, 4)]);
      expect(
        XiangqiRules.isLegalMove(cells, red, indexOf(9, 4), indexOf(8, 4)),
        isFalse,
      );
    });
  });

  group('将军与绝杀', () {
    test('车的直线攻击构成将军', () {
      final cells = boardWith([('K', 9, 4), ('k', 0, 3), ('r', 0, 4)]);
      expect(XiangqiRules.isKingInCheck(cells, red), isTrue);
    });

    test('马后炮式组合：炮隔子将军', () {
      final cells = boardWith([
        ('K', 9, 4),
        ('k', 0, 3),
        ('c', 0, 4),
        ('P', 5, 4),
      ]);
      expect(XiangqiRules.isKingInCheck(cells, red), isTrue);
    });

    test('双车错杀形成绝杀', () {
      final cells = boardWith([
        ('k', 0, 4),
        ('R', 0, 0),
        ('R', 1, 0),
        ('K', 9, 3),
      ]);
      final status = XiangqiRules.positionStatus(cells, black);
      expect(status.inCheck, isTrue);
      expect(status.hasLegalMoves, isFalse);
    });

    test('兵贴将门形成将军', () {
      final cells = boardWith([('k', 0, 4), ('P', 1, 4), ('K', 9, 3)]);
      expect(XiangqiRules.isKingInCheck(cells, black), isTrue);
    });
  });

  group('局面安全判定', () {
    test('未被将军且不对脸时安全', () {
      final cells = initialCells();
      expect(XiangqiRules.isPositionSafe(cells, red), isTrue);
      expect(XiangqiRules.isPositionSafe(cells, black), isTrue);
    });

    test('将帅对脸时双方都不安全', () {
      final cells = boardWith([('K', 9, 4), ('k', 0, 4)]);
      expect(XiangqiRules.isPositionSafe(cells, red), isFalse);
      expect(XiangqiRules.isPositionSafe(cells, black), isFalse);
    });

    test('被将军的一方不安全，另一方不受影响', () {
      final cells = boardWith([('K', 9, 4), ('k', 0, 3), ('r', 0, 4)]);
      expect(XiangqiRules.isPositionSafe(cells, red), isFalse);
      expect(XiangqiRules.isPositionSafe(cells, black), isTrue);
    });
  });

  group('外部着法校验', () {
    test('接受本方棋子的合法着法', () {
      final cells = initialCells();
      expect(
        XiangqiRules.isPlayable(cells, red, indexOf(7, 1), indexOf(7, 4)),
        isTrue,
        reason: '炮二平五',
      );
    });

    test('拒绝非本方棋子、空位与越界下标', () {
      final cells = initialCells();
      expect(
        XiangqiRules.isPlayable(cells, red, indexOf(0, 0), indexOf(0, 1)),
        isFalse,
        reason: '黑方棋子不能由红方走',
      );
      expect(
        XiangqiRules.isPlayable(cells, red, indexOf(4, 4), indexOf(4, 3)),
        isFalse,
        reason: '空位不能走子',
      );
      expect(XiangqiRules.isPlayable(cells, red, -1, 0), isFalse);
      expect(XiangqiRules.isPlayable(cells, red, 0, cellCount), isFalse);
    });

    test('拒绝违反走子几何或送将的着法', () {
      final cells = boardWith([('K', 9, 4), ('k', 0, 3), ('r', 0, 4)]);
      expect(
        XiangqiRules.isPlayable(cells, red, indexOf(9, 4), indexOf(8, 3)),
        isFalse,
        reason: '帅不能斜走',
      );
      expect(
        XiangqiRules.isPlayable(cells, red, indexOf(9, 4), indexOf(9, 5)),
        isTrue,
        reason: '横向避开将军是合法着法',
      );
    });
  });
}
