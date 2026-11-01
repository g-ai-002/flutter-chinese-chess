import 'package:chinese_chess/game/engine/mate_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('杀棋分数', () {
    test('层数越大杀棋分越低', () {
      expect(MateScore.at(0), MateScore.mate);
      expect(MateScore.at(3), MateScore.mate - 3);
      expect(MateScore.at(3), greaterThan(MateScore.at(6)));
    });

    test('超过阈值的分数才被认定为杀棋', () {
      expect(MateScore.isMate(MateScore.at(1)), isTrue);
      expect(MateScore.isMate(-MateScore.at(1)), isTrue);
      expect(MateScore.isMate(500), isFalse);
      expect(MateScore.isMate(-500), isFalse);
    });

    test('普通分数存取后保持不变', () {
      expect(MateScore.toStored(120, 4), 120);
      expect(MateScore.fromStored(120, 4), 120);
      expect(MateScore.toStored(-999, 2), -999);
      expect(MateScore.fromStored(-999, 2), -999);
    });

    test('杀棋分数存取互为逆运算', () {
      const score = 999995;
      expect(MateScore.toStored(score, 2), score + 2);
      expect(MateScore.fromStored(MateScore.toStored(score, 2), 5), score - 3);
      expect(MateScore.fromStored(MateScore.toStored(-score, 2), 5), -score + 3);
    });
  });
}
