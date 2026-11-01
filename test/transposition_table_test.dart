import 'package:chinese_chess/game/engine/transposition_table.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('置换表', () {
    test('精确分数命中后可直接取用', () {
      final table = TranspositionTable(size: 64);
      table.store(0x1234, 0xABCD, 3, 120, TranspositionTable.exact, 77, 0);

      expect(table.probe(0x1234, 0xABCD, 3, -100, 100, 0), isTrue);
      expect(table.score, 120);
      expect(table.bestMove, 77);
    });

    test('未写入的局面不命中', () {
      final table = TranspositionTable(size: 64);

      expect(table.probe(0x4321, 0xABCD, 3, -100, 100, 0), isFalse);
      expect(table.bestMove, -1);
    });

    test('深度不足时只提供着法，不参与裁剪', () {
      final table = TranspositionTable(size: 64);
      table.store(0x55, 0x1111, 2, 50, TranspositionTable.exact, 12, 0);

      expect(table.probe(0x55, 0x1111, 4, -100, 100, 0), isFalse);
      expect(table.bestMove, 12);
    });

    test('下界分数未达到 beta 时不裁剪', () {
      final table = TranspositionTable(size: 64);
      table.store(0x66, 0x2222, 3, 100, TranspositionTable.lower, 5, 0);

      expect(table.probe(0x66, 0x2222, 3, -1000, 120, 0), isFalse);
      expect(table.probe(0x66, 0x2222, 3, -1000, 80, 0), isTrue);
      expect(table.score, 100);
    });

    test('上界分数高于 alpha 时不裁剪', () {
      final table = TranspositionTable(size: 64);
      table.store(0x77, 0x3333, 3, -60, TranspositionTable.upper, 6, 0);

      expect(table.probe(0x77, 0x3333, 3, -100, 1000, 0), isFalse);
      expect(table.probe(0x77, 0x3333, 3, -50, 1000, 0), isTrue);
      expect(table.score, -60);
    });

    test('杀棋分数按层数归一化后取回', () {
      final table = TranspositionTable(size: 64);
      table.store(0x88, 0x4444, 2, 999990, TranspositionTable.exact, 9, 2);

      expect(table.probe(0x88, 0x4444, 2, -1000000, 1000000, 4), isTrue);
      expect(table.score, 999988);
    });

    test('浅层结果不覆盖更深的分数，只刷新着法', () {
      final table = TranspositionTable(size: 64);
      table.store(0x99, 0x5555, 5, 10, TranspositionTable.exact, 1, 0);
      table.store(0x99, 0x5555, 2, 20, TranspositionTable.exact, 2, 0);

      expect(table.probe(0x99, 0x5555, 5, -100, 100, 0), isTrue);
      expect(table.score, 10);
      expect(table.bestMove, 2);
    });
  });
}
