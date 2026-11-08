import 'package:chinese_chess/game/board_state.dart';
import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/engine/rules.dart';
import 'package:chinese_chess/game/notation.dart';
import 'package:chinese_chess/game/replay_controller.dart';
import 'package:chinese_chess/models/move_record.dart';
import 'package:flutter_test/flutter_test.dart';

List<MoveRecord> play(List<String> notations) {
  final board = XiangqiBoard.initial();
  for (final notation in notations) {
    final move = MoveNotation.findMove(board.cells, board.sideToMove, notation);
    expect(move, isNotNull, reason: notation);
    board.applyMove(moveFrom(move!), moveTo(move));
  }
  return List.of(board.history);
}

ReplayController replayOf(List<String> notations) => ReplayController(
  moves: play(notations),
  layout: XiangqiBoard.initial().startLayout,
);

void main() {
  const opening = ['炮二平五', '马8进7', '马二进三', '马2进3'];

  test('复盘从开局局面开始，可逐手前进与后退', () {
    final replay = replayOf(opening);
    expect(replay.total, 4);
    expect(replay.cursor, 0);
    expect(replay.history, isEmpty);
    expect(replay.canPrevious, isFalse);
    expect(replay.board.cells, XiangqiBoard.initial().cells);
    expect(replay.board.sideToMove, red);

    replay.next();
    replay.next();
    expect(replay.cursor, 2);
    expect(replay.progressText, '第 2 / 4 手');
    expect(replay.history.length, 2);
    expect(replay.history.last.notation, '马8进7');
    expect(replay.board.sideToMove, red);

    replay.previous();
    expect(replay.cursor, 1);
    expect(replay.history.length, 1);
    expect(replay.board.sideToMove, black);

    replay.last();
    expect(replay.cursor, 4);
    expect(replay.canNext, isFalse);
    expect(replay.finished, isTrue);
    expect(replay.history.last.notation, '马2进3');

    replay.first();
    expect(replay.cursor, 0);
    expect(replay.board.cells, XiangqiBoard.initial().cells);

    replay.dispose();
  });

  test('跳转越界时自动收敛到有效范围', () {
    final replay = replayOf(opening);
    replay.jumpTo(99);
    expect(replay.cursor, 4);
    replay.jumpTo(-5);
    expect(replay.cursor, 0);

    replay.jumpTo(2);
    expect(replay.history.length, 2);
    expect(replay.board.cells, isNot(XiangqiBoard.initial().cells));

    replay.dispose();
  });

  test('前进与后退交替后与直接跳转的局面一致', () {
    final replay = replayOf(opening);
    replay.jumpTo(3);
    final third = [for (final record in replay.history) record.notation];

    replay.previous();
    replay.previous();
    expect(replay.cursor, 1);
    expect(replay.history.single.notation, opening.first);

    replay.next();
    replay.next();
    expect(replay.cursor, 3);
    expect([for (final record in replay.history) record.notation], third);
    expect(replay.board.sideToMove, black);

    replay.dispose();
  });

  test('复盘每手棋前留有高亮停顿，让目光先落到要走动的棋子上', () {
    final replay = replayOf(opening);
    expect(replay.moveLeadIn, const Duration(milliseconds: 320));
    replay.dispose();
  });

  test('非法的着法序列在构造时抛出异常', () {
    final records = play(['炮二平五']);
    final broken = MoveRecord(
      from: 0,
      to: 1,
      piece: records.first.piece,
      captured: 0,
      notation: '非法',
      givesCheck: false,
      noCaptureBefore: 1,
    );
    expect(
      () => ReplayController(
        moves: [...records, broken],
        layout: XiangqiBoard.initial().startLayout,
      ),
      throwsArgumentError,
    );
  });
}
