import 'package:chinese_chess/game/board_state.dart';
import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/engine/rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('棋局状态', () {
    test('初始布局与红方先行', () {
      final board = XiangqiBoard.initial();
      expect(board.sideToMove, red);
      expect(board.history, isEmpty);
      expect(cellsToLayout(board.cells), [
        'rheakaehr',
        '.........',
        '.c.....c.',
        'p.p.p.p.p',
        '.........',
        '.........',
        'P.P.P.P.P',
        '.C.....C.',
        '.........',
        'RHEAKAEHR',
      ]);
    });

    test('落子后切换行棋方并记录棋谱', () {
      final board = XiangqiBoard.initial();
      final record = board.applyMove(indexOf(7, 7), indexOf(7, 4));
      expect(record.notation, '炮二平五');
      expect(board.sideToMove, black);
      expect(board.history.length, 1);
      expect(board.cells[indexOf(7, 7)], 0);
      expect(board.cells[indexOf(7, 4)], pieceOf(red, typeCannon));
    });

    test('悔棋完整恢复棋盘与行棋方', () {
      final board = XiangqiBoard.initial();
      final before = List<int>.from(board.cells);
      board.applyMove(indexOf(7, 7), indexOf(7, 4));
      board.applyMove(indexOf(0, 1), indexOf(2, 2));
      board.undoLast();
      board.undoLast();
      expect(board.cells, before);
      expect(board.sideToMove, red);
      expect(board.history, isEmpty);
      expect(board.lastFrom, isNull);
    });

    test('重复初始局面可用于重新开始', () {
      final board = XiangqiBoard.initial();
      board.applyMove(indexOf(7, 7), indexOf(7, 4));
      board.reset();
      expect(board.sideToMove, red);
      expect(board.history, isEmpty);
      expect(XiangqiRules.legalMoves(board.cells, red).length, 44);
    });
  });
}
