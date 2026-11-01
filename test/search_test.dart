import 'dart:typed_data';

import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/engine/rules.dart';
import 'package:chinese_chess/game/engine/search.dart';
import 'package:chinese_chess/game/puzzles.dart';
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

    test('静态搜索能看穿有保护的兵，不用车换兵', () {
      final cells = boardWith([
        ('k', 0, 4),
        ('r', 4, 4),
        ('p', 5, 4),
        ('R', 5, 1),
        ('K', 9, 3),
      ]);
      final result = XiangqiSearch.bestMove(cells: cells, side: red, depth: 1);
      expect(result.move, isNot(encodeMove(indexOf(5, 1), indexOf(5, 4))));
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

    test('迭代加深记录实际完成的层数', () {
      final cells = initialCells();
      final result = XiangqiSearch.bestMove(
        cells: cells,
        side: red,
        depth: 4,
        timeLimitMillis: 30000,
      );

      expect(result.depth, inInclusiveRange(1, 4));
      expect(result.nodes, greaterThan(0));
      expect(XiangqiRules.legalMoves(cells, red), contains(result.move));
    });

    test('节点预算耗尽时仍返回合法着法', () {
      final cells = initialCells();
      final result = XiangqiSearch.bestMove(
        cells: cells,
        side: red,
        depth: 6,
        maxNodes: 300,
        timeLimitMillis: 30000,
      );

      expect(XiangqiRules.legalMoves(cells, red), contains(result.move));
    });

    test('同一局面重复搜索结果一致', () {
      final first = XiangqiSearch.bestMove(
        cells: initialCells(),
        side: red,
        depth: 3,
        maxNodes: 200000,
      );
      final second = XiangqiSearch.bestMove(
        cells: initialCells(),
        side: red,
        depth: 3,
        maxNodes: 200000,
      );

      expect(second.move, first.move);
      expect(second.score, first.score);
    });

    test('两步杀残局能搜到杀棋', () {
      final puzzle = kPuzzles.firstWhere((item) => item.id == 'p5');
      final cells = cellsFromLayout(puzzle.layout);
      final result = XiangqiSearch.bestMove(
        cells: cells,
        side: red,
        depth: 4,
        timeLimitMillis: 30000,
      );

      expect(result.score, greaterThan(900000));
      expect(XiangqiRules.legalMoves(cells, red), contains(result.move));
    });
  });

  group('搜索预算', () {
    test('节点达到上限后耗尽', () {
      final budget = SearchBudget(maxNodes: 2, timeLimitMillis: 0);

      expect(budget.consume(), isFalse);
      expect(budget.consume(), isTrue);
      expect(budget.spent, isTrue);
      expect(budget.nodes, 2);
      expect(budget.consume(), isTrue);
    });

    test('不限时且节点未满时不会耗尽', () {
      final budget = SearchBudget(maxNodes: 1000, timeLimitMillis: 0);

      for (var index = 0; index < 999; index++) {
        expect(budget.consume(), isFalse);
      }
      expect(budget.spent, isFalse);
    });

    test('时限为零表示不限时', () {
      final budget = SearchBudget(maxNodes: 10000, timeLimitMillis: 0);

      expect(budget.consume(), isFalse);
      expect(budget.spent, isFalse);
    });
  });
}
