import 'package:chinese_chess/game/board_state.dart';
import 'package:chinese_chess/game/engine/rules.dart';
import 'package:chinese_chess/game/notation.dart';
import 'package:chinese_chess/game/opening_book.dart';
import 'package:flutter_test/flutter_test.dart';

/// 从开局局面依次走出记法序列，返回落子后的棋盘。
XiangqiBoard walk(List<String> notations) {
  final board = XiangqiBoard.initial();
  for (final notation in notations) {
    final move = MoveNotation.findMove(
      board.cells,
      board.sideToMove,
      notation,
    );
    expect(move, isNotNull, reason: '记法「$notation」在当前局面不合法');
    final from = moveFrom(move!);
    final to = moveTo(move);
    expect(
      XiangqiRules.isLegalMove(board.cells, board.sideToMove, from, to),
      isTrue,
    );
    board.applyMove(from, to);
  }
  return board;
}

void main() {
  group('开局库', () {
    test('所有线路的记法都能逐着走通', () {
      for (final line in kOpeningLines) {
        final board = walk(line.moves);
        expect(board.history.length, line.moves.length, reason: line.name);
        expect(board.history.last.notation, line.moves.last, reason: line.name);
      }
    });

    test('开局前推荐中炮起手', () {
      final info = OpeningBook.lookup(XiangqiBoard.initial());
      expect(info, isNotNull);
      expect(info!.name, '中炮');
      expect(info.next, '炮二平五');
    });

    test('识别屏风马并给出下一手', () {
      final board = walk(['炮二平五', '马8进7', '马二进三']);
      final info = OpeningBook.lookup(board);
      expect(info?.name, '中炮对屏风马');
      expect(info?.next, '马2进3');
      expect(info?.note, isNotEmpty);
    });

    test('按分支识别顺炮与反宫马', () {
      final straight = walk(['炮二平五', '炮8平5']);
      expect(OpeningBook.lookup(straight)?.name, '中炮对顺炮');

      final palace = walk(['炮二平五', '炮8平6']);
      final info = OpeningBook.lookup(palace);
      expect(info?.name, '中炮对反宫马');
      expect(info?.next, '马二进三');
    });

    test('脱离棋谱后保留已匹配的开局名称', () {
      final board = walk(['炮二平五', '马8进7', '兵三进一']);
      final info = OpeningBook.lookup(board);
      expect(info?.name, '中炮对屏风马');
      expect(info?.next, isNull);
    });

    test('超出提示步数后不再识别', () {
      final board = XiangqiBoard.initial();
      while (board.history.length <= OpeningBook.maxPlies) {
        final moves = XiangqiRules.legalMoves(board.cells, board.sideToMove);
        final move = moves.first;
        board.applyMove(moveFrom(move), moveTo(move));
      }
      expect(OpeningBook.lookup(board), isNull);
    });
  });
}
