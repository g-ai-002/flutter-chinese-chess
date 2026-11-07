import 'package:chinese_chess/game/logic_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('未设置或未知速率回退到 60Hz', () {
    expect(LogicRate.byName(null), LogicRate.hz60);
    expect(LogicRate.byName('unknown'), LogicRate.hz60);
    expect(LogicRate.byName('hz120'), LogicRate.hz120);
    expect(LogicRate.hz30.step, closeTo(1 / 30, 1e-9));
  });

  test('未满一个固定步长时不推进逻辑', () {
    final clock = FixedStepClock(LogicRate.hz30.step);
    final spans = <double>[];

    expect(clock.advance(0.02, spans.add), 0);
    expect(spans, isEmpty);

    expect(clock.advance(0.02, spans.add), 1);
    expect(spans.single, closeTo(1 / 30, 1e-9));

    // 余量留到下一次累计，未满一步仍不推进。
    expect(clock.advance(0.02, spans.add), 0);
    expect(clock.advance(0.01, spans.add), 1);
    expect(spans, hasLength(2));
    expect(spans.last, closeTo(1 / 30, 1e-9));
  });

  test('120Hz 下一帧可以推进多个逻辑步', () {
    final clock = FixedStepClock(LogicRate.hz120.step);
    final spans = <double>[];

    expect(clock.advance(0.02, spans.add), 2);
    expect(spans.single, closeTo(1 / 60, 1e-9));
  });

  test('卡顿积压合并成一次大步，动画不被拖慢', () {
    final clock = FixedStepClock(LogicRate.hz60.step);
    final spans = <double>[];

    expect(clock.advance(1.0, spans.add), 4);
    expect(spans.single, closeTo(1.0, 1e-9));
  });
}
