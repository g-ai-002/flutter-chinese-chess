import 'package:chinese_chess/game/board_state.dart';
import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:flutter_test/flutter_test.dart';

const List<String> _emptyBoard = [
  '.........',
  '.........',
  '.........',
  '.........',
  '.........',
  '.........',
  '.........',
  '.........',
  '.........',
  '.........',
];

void main() {
  group('布局解析', () {
    test('大写为红、小写为黑、点为空格', () {
      expect(pieceFromSymbol('K'), pieceOf(red, typeKing));
      expect(pieceFromSymbol('k'), pieceOf(black, typeKing));
      expect(pieceFromSymbol('P'), pieceOf(red, typePawn));
      expect(pieceFromSymbol('.'), 0);
      expect(() => pieceFromSymbol('x'), throwsA(isA<ArgumentError>()));
    });

    test('解析与序列化可以往返', () {
      final rows = [
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
      ];
      final cells = cellsFromLayout(rows);
      expect(cellsToLayout(cells), rows);
      expect(cells, initialCells());
    });

    test('行数不符时抛出异常', () {
      expect(
        () => cellsFromLayout(_emptyBoard.sublist(1)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('行宽不符时抛出异常', () {
      final rows = [..._emptyBoard]..[4] = '........';
      expect(() => cellsFromLayout(rows), throwsA(isA<ArgumentError>()));
    });

    test('出现未知棋子字符时抛出异常', () {
      final rows = [..._emptyBoard]..[4] = '....x....';
      expect(() => cellsFromLayout(rows), throwsA(isA<ArgumentError>()));
    });

    test('棋局可以从布局构造并指定行棋方', () {
      final rows = [..._emptyBoard];
      rows[0] = '....k....';
      rows[9] = '....K....';
      final board = XiangqiBoard.fromLayout(rows, sideToMove: black);
      expect(board.sideToMove, black);
      expect(board.cells[indexOf(0, 4)], pieceOf(black, typeKing));
      expect(board.cells[indexOf(9, 4)], pieceOf(red, typeKing));
      expect(board.history, isEmpty);
    });
  });
}
