import 'package:chinese_chess/game/engine/transposition_table.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('置换表', () {
    test('写入后可按局面键取回条目', () {
      final table = TranspositionTable(size: 64);
      table.store(
        low: 0x1234,
        high: 0xABCD,
        ply: 0,
        depth: 3,
        score: 120,
        bound: TranspositionTable.exact,
        move: 77,
      );

      final entry = table.lookup(0x1234, 0xABCD, 0);
      expect(entry, isNotNull);
      expect(entry!.score, 120);
      expect(entry.depth, 3);
      expect(entry.move, 77);
      expect(entry.bound, TranspositionTable.exact);
    });

    test('未写入的局面返回 null', () {
      final table = TranspositionTable(size: 64);

      expect(table.lookup(0x4321, 0xABCD, 0), isNull);
    });

    test('只匹配低半、高半不符时不命中', () {
      final table = TranspositionTable(size: 64);
      table.store(
        low: 0x55,
        high: 0x1111,
        ply: 0,
        depth: 2,
        score: 50,
        bound: TranspositionTable.exact,
        move: 12,
      );

      expect(table.lookup(0x55, 0x2222, 0), isNull);
    });

    test('杀棋分数按层数归一化后取回', () {
      final table = TranspositionTable(size: 64);
      table.store(
        low: 0x88,
        high: 0x4444,
        ply: 2,
        depth: 2,
        score: 999990,
        bound: TranspositionTable.exact,
        move: 9,
      );

      expect(table.lookup(0x88, 0x4444, 4)!.score, 999988);
    });

    test('浅层结果不覆盖更深的分数，只刷新着法', () {
      final table = TranspositionTable(size: 64);
      table.store(
        low: 0x99,
        high: 0x5555,
        ply: 0,
        depth: 5,
        score: 10,
        bound: TranspositionTable.exact,
        move: 1,
      );
      table.store(
        low: 0x99,
        high: 0x5555,
        ply: 0,
        depth: 2,
        score: 20,
        bound: TranspositionTable.exact,
        move: 2,
      );

      final entry = table.lookup(0x99, 0x5555, 0)!;
      expect(entry.score, 10);
      expect(entry.depth, 5);
      expect(entry.move, 2);
    });
  });
}
