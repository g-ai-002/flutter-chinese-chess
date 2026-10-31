import 'package:chinese_chess/game/ai_player.dart';
import 'package:chinese_chess/game/board_state.dart';
import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/engine/rules.dart';
import 'package:chinese_chess/game/game_controller.dart';
import 'package:chinese_chess/models/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

AiReply replyFor(int fromRow, int fromCol, int toRow, int toCol) => AiReply(
  move: encodeMove(indexOf(fromRow, fromCol), indexOf(toRow, toCol)),
  score: 0,
  nodes: 1,
  depth: 1,
);

void main() {
  test('人类落子后 AI 自动应招', () async {
    final controller = GameController(
      mode: GameMode.vsAi,
      difficulty: Difficulty.entry,
      humanSide: red,
      aiMove: (cells, side, difficulty) async => replyFor(3, 0, 4, 0),
    );
    controller.start();

    controller.tapCell(indexOf(9, 0));
    expect(controller.selected, indexOf(9, 0));
    expect(controller.legalTargets, contains(indexOf(8, 0)));

    controller.tapCell(indexOf(8, 0));
    expect(controller.history.length, 1);
    expect(controller.thinking, isTrue);

    await pumpEventQueue();
    expect(controller.history.length, 2);
    expect(controller.thinking, isFalse);
    expect(controller.board.sideToMove, red);
    expect(controller.history.last.notation, '卒1进1');

    controller.dispose();
  });

  test('人类执黑时 AI 先行，且此时不能悔棋', () async {
    final controller = GameController(
      mode: GameMode.vsAi,
      difficulty: Difficulty.entry,
      humanSide: black,
      aiMove: (cells, side, difficulty) async => replyFor(9, 0, 8, 0),
    );
    controller.start();
    await pumpEventQueue();

    expect(controller.history.length, 1);
    expect(controller.board.sideToMove, black);
    expect(controller.canUndo, isFalse);

    controller.dispose();
  });

  test('悔棋在 AI 模式下回退一个回合', () async {
    final controller = GameController(
      mode: GameMode.vsAi,
      difficulty: Difficulty.entry,
      humanSide: red,
      aiMove: (cells, side, difficulty) async => replyFor(3, 0, 4, 0),
    );
    controller.start();
    controller.tapCell(indexOf(9, 0));
    controller.tapCell(indexOf(8, 0));
    await pumpEventQueue();
    expect(controller.history.length, 2);

    controller.undo();
    expect(controller.history, isEmpty);
    expect(controller.board.sideToMove, red);
    expect(controller.selected, isNull);

    controller.dispose();
  });

  test('双人模式不触发 AI，红方将死黑方判胜', () async {
    final board = XiangqiBoard.fromLayout([
      '....k....',
      'R........',
      '.R.......',
      '.........',
      '.........',
      '.........',
      '.........',
      '.........',
      '.........',
      '...K.....',
    ]);
    final controller = GameController(
      mode: GameMode.twoPlayers,
      difficulty: Difficulty.entry,
      humanSide: red,
      board: board,
      aiMove: (cells, side, difficulty) async =>
          const AiReply(move: -1, score: 0, nodes: 0, depth: 0),
    );
    controller.start();

    controller.tapCell(indexOf(2, 1));
    controller.tapCell(indexOf(0, 1));

    final result = controller.result;
    expect(result, isNotNull);
    expect(result!.winner, red);
    expect(result.reason, '绝杀');
    expect(controller.canInteractive, isFalse);

    controller.dispose();
  });

  test('认输直接结束对局', () {
    final controller = GameController(
      mode: GameMode.vsAi,
      difficulty: Difficulty.entry,
      humanSide: red,
      aiMove: (cells, side, difficulty) async =>
          const AiReply(move: -1, score: 0, nodes: 0, depth: 0),
    );
    controller.start();
    controller.resign();
    expect(controller.result?.winner, black);
    expect(controller.result?.reason, '认输');
    controller.dispose();
  });

  test('非法选择不会改变棋盘', () {
    final controller = GameController(
      mode: GameMode.twoPlayers,
      difficulty: Difficulty.entry,
      humanSide: red,
      aiMove: (cells, side, difficulty) async =>
          const AiReply(move: -1, score: 0, nodes: 0, depth: 0),
    );
    controller.start();
    expect(XiangqiRules.legalMoves(controller.board.cells, red).length, 44);
    controller.tapCell(indexOf(3, 0));
    expect(controller.selected, isNull);
    controller.dispose();
  });
}
