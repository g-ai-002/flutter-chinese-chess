import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/notation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rules_test.dart' show boardWith;

void main() {
  group('棋谱记法', () {
    final initial = initialCells();

    test('红炮平中：炮二平五', () {
      final from = indexOf(7, 7);
      final to = indexOf(7, 4);
      expect(MoveNotation.describe(initial, from, to), '炮二平五');
    });

    test('黑马起马：马8进7', () {
      final from = indexOf(0, 7);
      final to = indexOf(2, 6);
      expect(MoveNotation.describe(initial, from, to), '马8进7');
    });

    test('红车挺进：车九进一', () {
      final from = indexOf(9, 0);
      final to = indexOf(8, 0);
      expect(MoveNotation.describe(initial, from, to), '车九进一');
    });

    test('红兵前进：兵七进一', () {
      final from = indexOf(6, 2);
      final to = indexOf(5, 2);
      expect(MoveNotation.describe(initial, from, to), '兵七进一');
    });

    test('红马起马：马二进三', () {
      final from = indexOf(9, 7);
      final to = indexOf(7, 6);
      expect(MoveNotation.describe(initial, from, to), '马二进三');
    });

    test('同列双车用前后区分', () {
      final cells = boardWith([
        ('R', 9, 0),
        ('R', 5, 0),
        ('K', 9, 4),
        ('k', 0, 3),
      ]);
      expect(
        MoveNotation.describe(cells, indexOf(5, 0), indexOf(4, 0)),
        '前车进一',
      );
      expect(
        MoveNotation.describe(cells, indexOf(9, 0), indexOf(8, 0)),
        '后车进一',
      );
    });

    test('黑方使用阿拉伯数字路数', () {
      final cells = boardWith([('c', 2, 7), ('K', 9, 4), ('k', 0, 4)]);
      expect(
        MoveNotation.describe(cells, indexOf(2, 7), indexOf(2, 4)),
        '炮8平5',
      );
    });
  });
}
