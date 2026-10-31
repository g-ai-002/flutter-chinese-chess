import 'dart:typed_data';

import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/engine/rules.dart';
import 'package:chinese_chess/game/engine/search.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rules_test.dart' show boardWith;

void main() {
  group('AI 搜索', () {
    test('初始局面返回合法着法', () {
      final cells = initialCells();
      final result = XiangqiSearch.bestMove(cells: cells, side: red, depth: 2);
      expect(result.move, greaterThanOrEqualTo(0));
      expect(XiangqiRules.legalMoves(cells, red), contains(result.move));
      expect(result.nodes, greaterThan(0));
    });

    test('能够找到一步取胜的着法', () {
      final cells = boardWith([
        ('k', 0, 4),
        ('R', 1, 0),
        ('R', 2, 1),
        ('K', 9, 3),
      ]);
      final result = XiangqiSearch.bestMove(cells: cells, side: red, depth: 2);
      expect(result.score, greaterThan(900000));
      final board = Uint8List.fromList(cells);
      board[result.move % cellCount] = board[result.move ~/ cellCount];
      board[result.move ~/ cellCount] = 0;
      final status = XiangqiRules.positionStatus(board, black);
      expect(status.hasLegalMoves, isFalse);
    });

    test('优先吃掉无保护的车', () {
      final cells = boardWith([
        ('k', 0, 4),
        ('r', 5, 4),
        ('R', 5, 0),
        ('K', 9, 3),
      ]);
      final result = XiangqiSearch.bestMove(cells: cells, side: red, depth: 3);
      expect(result.move, encodeMove(indexOf(5, 0), indexOf(5, 4)));
    });

    test('无棋可走时返回 -1', () {
      final cells = boardWith([
        ('k', 0, 4),
        ('R', 0, 0),
        ('R', 1, 0),
        ('K', 9, 3),
      ]);
      final result = XiangqiSearch.bestMove(
        cells: cells,
        side: black,
        depth: 2,
      );
      expect(result.move, -1);
    });
  });
}
