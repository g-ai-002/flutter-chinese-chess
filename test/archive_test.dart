import 'package:chinese_chess/game/board_state.dart';
import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/engine/rules.dart';
import 'package:chinese_chess/game/game_archive.dart';
import 'package:chinese_chess/game/notation.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> initialLayout() => XiangqiBoard.initial().startLayout;

void main() {
  test('导出的棋谱可以原样解析回来', () {
    final board = XiangqiBoard.initial();
    for (final notation in ['炮二平五', '马8进7', '马二进三', '马2进3']) {
      final move = MoveNotation.findMove(
        board.cells,
        board.sideToMove,
        notation,
      );
      board.applyMove(moveFrom(move!), moveTo(move));
    }

    final text = GameArchive.encode(
      moves: board.history,
      layout: board.startLayout,
      title: '人机对战 · 普通',
      result: '红方胜（绝杀）',
      date: DateTime(2026, 11, 1, 21, 30),
    );
    expect(text, contains(GameArchive.tag));
    expect(text, contains('1. 炮二平五 马8进7'));
    expect(text, contains('日期: 2026-11-01 21:30'));

    final decoded = GameArchive.decode(text);
    expect(decoded, isNotNull);
    expect(decoded!.moveCount, 4);
    expect(decoded.title, '人机对战 · 普通');
    expect(decoded.result, '红方胜（绝杀）');
    expect(decoded.date, '2026-11-01 21:30');
    expect(decoded.startSide, red);
    expect(decoded.layout, initialLayout());
    expect(decoded.moves.last.notation, '马2进3');
    expect(decoded.moves.first.from, board.history.first.from);
  });

  test('缺少着法编码时按中文记法逐着匹配', () {
    const text = '''
1. 炮二平五 马8进7
2. 马二进三 马2进3
''';
    final decoded = GameArchive.decode(text);
    expect(decoded, isNotNull);
    expect(decoded!.moveCount, 4);
    expect(decoded.title, '导入棋谱');
    expect(decoded.moves.map((move) => move.notation), [
      '炮二平五',
      '马8进7',
      '马二进三',
      '马2进3',
    ]);
  });

  test('导入保留残局布局与先手方', () {
    final puzzle = XiangqiBoard.fromLayout([
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
    final move = XiangqiRules.legalMoves(puzzle.cells, red).first;
    puzzle.applyMove(moveFrom(move), moveTo(move));

    final text = GameArchive.encode(
      moves: puzzle.history,
      layout: puzzle.startLayout,
      title: '残局 · 单车擒将',
    );
    final decoded = GameArchive.decode(text);
    expect(decoded, isNotNull);
    expect(decoded!.layout, puzzle.startLayout);
    expect(decoded.moves.single.notation, puzzle.history.single.notation);
    expect(decoded.result, isNull, reason: '进行中的对局不显示结果');
  });

  test('记法非法或内容为空时返回 null', () {
    expect(GameArchive.decode(''), isNull);
    expect(GameArchive.decode('随手写点东西'), isNull);
    expect(GameArchive.decode('1. 炮二平五 马9进7'), isNull, reason: '马9进7 不是合法记法');
    expect(GameArchive.decode('[中国象棋棋谱]\n布局: bad\n#moves: 1-2'), isNull);
  });

  test('着法编码越界时返回 null', () {
    const text = '''
#moves: 0-1 0-999
''';
    expect(GameArchive.decode(text), isNull);
    expect(GameArchive.decode('#moves: 0-1'), isNull, reason: '0-1 是己方棋子，不合法');
  });
}
