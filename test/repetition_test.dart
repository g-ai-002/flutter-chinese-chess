import 'package:chinese_chess/game/ai_player.dart';
import 'package:chinese_chess/game/board_state.dart';
import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/engine/rules.dart';
import 'package:chinese_chess/game/game_controller.dart';
import 'package:chinese_chess/models/game_models.dart';
import 'package:chinese_chess/models/move_record.dart';
import 'package:flutter_test/flutter_test.dart';

GameController twoPlayerController(List<String> layout) {
  final controller = GameController(
    mode: GameMode.twoPlayers,
    difficulty: Difficulty.entry,
    humanSide: red,
    board: XiangqiBoard.fromLayout(layout),
    aiMove: (cells, side, difficulty) async =>
        const AiReply(move: -1, score: 0, nodes: 0, depth: 0),
  );
  controller.start();
  return controller;
}

void play(GameController controller, int fromRow, int fromCol, int toRow,
    int toCol) {
  controller.tapCell(indexOf(fromRow, fromCol));
  controller.tapCell(indexOf(toRow, toCol));
}

MoveRecord recordOf(int piece, {required bool givesCheck}) => MoveRecord(
  from: 0,
  to: 0,
  piece: piece,
  captured: 0,
  notation: '',
  givesCheck: givesCheck,
  noCaptureBefore: 0,
);

void main() {
  group('重复局面', () {
    test('同一局面第三次出现时判和', () {
      final controller = twoPlayerController([
        '....k....',
        '.........',
        'r........',
        '.........',
        '.........',
        'R........',
        '.........',
        '.........',
        '.........',
        '.....K...',
      ]);

      for (var cycle = 0; cycle < 2; cycle++) {
        play(controller, 5, 0, 5, 1);
        play(controller, 2, 0, 2, 1);
        play(controller, 5, 1, 5, 0);
        play(controller, 2, 1, 2, 0);
      }

      expect(controller.history.length, 8);
      expect(controller.board.repetitionCount, 3);
      expect(controller.result, isNotNull);
      expect(controller.result!.isDraw, isTrue);
      expect(controller.result!.reason, '三次重复局面');
      controller.dispose();
    });

    test('长将一方判负', () {
      final controller = twoPlayerController([
        '....k....',
        'R.......R',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '.....K...',
      ]);

      // 红方右车在第二横线循环将军，黑将往返两格。
      play(controller, 1, 8, 1, 4);
      play(controller, 0, 4, 0, 3);
      play(controller, 1, 4, 1, 3);
      play(controller, 0, 3, 0, 4);

      for (var cycle = 0; cycle < 3 && controller.result == null; cycle++) {
        play(controller, 1, 3, 1, 4);
        play(controller, 0, 4, 0, 3);
        play(controller, 1, 4, 1, 3);
        play(controller, 0, 3, 0, 4);
      }

      expect(controller.result, isNotNull);
      expect(controller.result!.reason, '长将判负');
      expect(controller.result!.winner, black);
      controller.dispose();
    });

    test('双方都长将时按重复局面判和', () {
      final cycle = [
        recordOf(pieceOf(red, typeRook), givesCheck: true),
        recordOf(pieceOf(black, typeRook), givesCheck: true),
        recordOf(pieceOf(red, typeCannon), givesCheck: true),
        recordOf(pieceOf(black, typeCannon), givesCheck: true),
      ];
      expect(XiangqiRules.perpetualChecker(cycle), isNull);
    });

    test('只有一方步步将军时认定为长将方', () {
      final cycle = [
        recordOf(pieceOf(red, typeRook), givesCheck: true),
        recordOf(pieceOf(black, typeKing), givesCheck: false),
        recordOf(pieceOf(red, typeRook), givesCheck: true),
        recordOf(pieceOf(black, typeKing), givesCheck: false),
      ];
      expect(XiangqiRules.perpetualChecker(cycle), red);
    });

    test('悔棋会撤掉重复记录', () {
      final controller = twoPlayerController([
        '....k....',
        '.........',
        'r........',
        '.........',
        '.........',
        'R........',
        '.........',
        '.........',
        '.........',
        '.....K...',
      ]);
      play(controller, 5, 0, 5, 1);
      play(controller, 2, 0, 2, 1);
      play(controller, 5, 1, 5, 0);
      play(controller, 2, 1, 2, 0);
      expect(controller.board.repetitionCount, 2);

      controller.undo();
      expect(controller.board.positionKeys.length, 4);
      expect(controller.board.repetitionCount, 1);
      controller.dispose();
    });
  });

  group('残局棋盘', () {
    test('重开恢复残局初始局面而非全局开局', () {
      final board = XiangqiBoard.fromLayout([
        '....k....',
        'R...a....',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '.........',
        '....K....',
      ]);
      board.applyMove(indexOf(1, 0), indexOf(0, 0));
      expect(board.history, hasLength(1));

      board.reset();
      expect(board.history, isEmpty);
      expect(board.cells[indexOf(0, 0)], 0);
      expect(board.cells[indexOf(1, 0)], pieceOf(red, typeRook));
      expect(board.repetitionCount, 1);
    });
  });
}
