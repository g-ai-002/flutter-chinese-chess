import 'dart:typed_data';

import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/engine/zobrist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('局面哈希', () {
    test('同一局面的键稳定，且落在 32 位范围内', () {
      final cells = initialCells();
      final first = Zobrist.hashOf(cells, red);
      final second = Zobrist.hashOf(Uint8List.fromList(cells), red);

      expect(second.low, first.low);
      expect(second.high, first.high);
      expect(first.low, greaterThanOrEqualTo(0));
      expect(first.low, lessThan(1 << 32));
    });

    test('行棋方不同则键不同', () {
      final cells = initialCells();
      final redHash = Zobrist.hashOf(cells, red);
      final blackHash = Zobrist.hashOf(cells, black);

      expect(blackHash.low, isNot(redHash.low));
      expect(blackHash.high, isNot(redHash.high));
    });

    test('走子后键随即改变', () {
      final cells = initialCells();
      final before = Zobrist.hashOf(cells, red);
      cells[indexOf(6, 0)] = 0;
      cells[indexOf(5, 0)] = pieceOf(red, typePawn);

      expect(Zobrist.hashOf(cells, black).low, isNot(before.low));
    });

    test('不同棋子落在不同格子的键互不相同', () {
      final keys = <int>{
        Zobrist.lowKey(pieceOf(red, typeRook), indexOf(9, 0)),
        Zobrist.lowKey(pieceOf(red, typeRook), indexOf(9, 8)),
        Zobrist.lowKey(pieceOf(black, typeRook), indexOf(9, 0)),
        Zobrist.sideLowKey,
      };

      expect(keys.length, 4);
    });
  });
}
