import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/engine/rules.dart';
import 'package:chinese_chess/game/engine/search_board.dart';
import 'package:chinese_chess/game/engine/zobrist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('搜索棋盘', () {
    test('构造时与整盘哈希一致', () {
      final cells = initialCells();
      final board = SearchBoard(cells, red);
      final hash = Zobrist.hashOf(cells, red);

      expect(board.hashLow, hash.low);
      expect(board.hashHigh, hash.high);
      expect(board.sideToMove, red);
      expect(board.depth, 0);
    });

    test('试走后局面与哈希同步，撤销后完全还原', () {
      final cells = initialCells();
      final board = SearchBoard(cells, red);
      final move = encodeMove(indexOf(9, 0), indexOf(8, 0));

      expect(board.make(move), 0);
      final afterMove = Zobrist.hashOf(board.cells, black);
      expect(board.sideToMove, black);
      expect(board.hashLow, afterMove.low);
      expect(board.hashHigh, afterMove.high);
      expect(board.depth, 1);
      expect(board.cells[indexOf(8, 0)], pieceOf(red, typeRook));
      expect(board.cells[indexOf(9, 0)], 0);

      board.unmake();
      expect(board.sideToMove, red);
      expect(board.depth, 0);
      expect(board.cells, cells);
      final restored = Zobrist.hashOf(board.cells, red);
      expect(board.hashLow, restored.low);
      expect(board.hashHigh, restored.high);
    });

    test('吃子后撤销能放回被吃的棋子', () {
      final cells = cellsFromLayout([
        '....k....',
        '.........',
        '.........',
        '....p....',
        '.........',
        '....R....',
        '.........',
        '.........',
        '.........',
        '....K....',
      ]);
      final board = SearchBoard(cells, red);
      final move = encodeMove(indexOf(5, 4), indexOf(3, 4));

      expect(board.make(move), pieceOf(black, typePawn));
      expect(board.cells[indexOf(3, 4)], pieceOf(red, typeRook));

      board.unmake();
      expect(board.cells, cells);
      final restored = Zobrist.hashOf(board.cells, red);
      expect(board.hashLow, restored.low);
      expect(board.hashHigh, restored.high);
    });

    test('连续试走多步后逐步撤销，哈希与局面都能还原', () {
      final cells = initialCells();
      final board = SearchBoard(cells, red);
      final moves = [
        encodeMove(indexOf(6, 0), indexOf(5, 0)),
        encodeMove(indexOf(3, 0), indexOf(4, 0)),
        encodeMove(indexOf(7, 1), indexOf(7, 4)),
        encodeMove(indexOf(0, 1), indexOf(2, 2)),
      ];

      for (var index = 0; index < moves.length; index++) {
        final move = moves[index];
        expect(
          XiangqiRules.isPlayable(
            board.cells,
            board.sideToMove,
            moveFrom(move),
            moveTo(move),
          ),
          isTrue,
        );
        board.make(move);
        final expected = Zobrist.hashOf(board.cells, board.sideToMove);
        expect(board.hashLow, expected.low);
        expect(board.hashHigh, expected.high);
        expect(board.depth, index + 1);
      }

      while (board.depth > 0) {
        board.unmake();
      }
      expect(board.cells, cells);
      expect(board.sideToMove, red);
    });

    test('撤销栈为空时抛错', () {
      final board = SearchBoard(initialCells(), red);

      expect(board.unmake, throwsStateError);
    });

    test('红帅走位后增量将位同步，照面判定立即生效', () {
      final cells = cellsFromLayout([
        '....k....',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '...K.....',
      ]);
      final board = SearchBoard(cells, red);
      expect(board.isKingInCheck(red), isFalse);

      board.make(encodeMove(indexOf(9, 3), indexOf(9, 4)));
      expect(board.sideToMove, black);
      expect(board.isKingInCheck(black), isTrue);

      board.unmake();
      expect(board.isKingInCheck(black), isFalse);
    });

    test('黑将走位与撤销后增量将位保持正确', () {
      final cells = cellsFromLayout([
        '....k....',
        '.........',
        '....R....',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '.....K...',
      ]);
      final board = SearchBoard(cells, black);
      expect(board.isKingInCheck(black), isTrue);

      board.make(encodeMove(indexOf(0, 4), indexOf(0, 3)));
      expect(board.isKingInCheck(black), isFalse);

      board.unmake();
      expect(board.isKingInCheck(black), isTrue);
    });
  });
}
