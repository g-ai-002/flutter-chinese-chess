import '../models/game_models.dart';
import 'engine/board_utils.dart';

/// 对局棋钟：只扣除当前行棋方的剩余时间，扣到 0 即超时。
class MatchClock {
  MatchClock(this.control) : _remaining = [control.millis, control.millis];

  final TimeControl control;

  /// 双方剩余毫秒，下标沿用 [red] / [black]。
  final List<int> _remaining;
  int? _active;

  int remainingMs(int side) => _remaining[side];

  int? get activeSide => _active;

  bool get isRunning => _active != null;

  /// 交给 [side] 走棋，开始为他计时。
  void start(int side) => _active = side;

  void stop() => _active = null;

  /// 清零并停表，用于重开一局。
  void reset() {
    _remaining[red] = control.millis;
    _remaining[black] = control.millis;
    _active = null;
  }

  /// 扣除当前行棋方 [delta] 的时间，超时返回超时方，否则返回 null。
  int? charge(Duration delta) {
    final active = _active;
    if (active == null) return null;
    _remaining[active] -= delta.inMilliseconds;
    if (_remaining[active] > 0) return null;
    _remaining[active] = 0;
    _active = null;
    return active;
  }

  /// 落子前的时间快照，供悔棋还原。
  List<int> snapshot() => List.of(_remaining);

  /// 恢复快照并把计时交给 [side]。
  void restore(List<int> snapshot, {required int side}) {
    _remaining.setAll(0, snapshot);
    _active = side;
  }
}

/// 对局计时簿记：把棋钟、真实耗时与每步落子的快照收在一处。
///
/// 界面按固定间隔 [settle] 结算，落子时再补一次，AI 思考同样计入本方用时；
/// 每步落子后 [mark] 一次快照，悔棋时由 [rewind] 回到落子前的时间。
class ClockTracker {
  ClockTracker(TimeControl control) : clock = MatchClock(control);

  final MatchClock clock;

  /// 真实耗时基准，重新交表时归零，避免把空闲时间算进本方用时。
  final Stopwatch _watch = Stopwatch()..start();
  Duration _lastMark = Duration.zero;
  final List<List<int>> _marks = [];

  /// 把计时交给 [side]。
  void resume(int side) {
    _lastMark = _watch.elapsed;
    clock.start(side);
  }

  void stop() {
    _lastMark = _watch.elapsed;
    clock.stop();
  }

  /// 结算当前行棋方从上次结算至今的用时，超时返回超时方。
  ///
  /// [elapsed] 仅测试用，传入时不再读取真实耗时。
  int? settle([Duration? elapsed]) {
    if (!clock.isRunning) return null;
    return clock.charge(elapsed ?? _consumeElapsed());
  }

  /// 落子后记录双方剩余时间，下标与棋谱长度对应。
  void mark() => _marks.add(clock.snapshot());

  /// 悔棋到只剩 [keepMoves] 手：丢弃多余快照，还原落子前的时间并交给 [side]。
  void rewind({required int keepMoves, required int side}) {
    List<int>? mark;
    while (_marks.length > keepMoves) {
      mark = _marks.removeLast();
    }
    if (mark == null) {
      clock.reset();
    } else {
      clock.restore(mark, side: side);
    }
    resume(side);
  }

  /// 重开一局：清零棋钟与快照，重新交给 [side] 计时。
  void restart(int side) {
    _marks.clear();
    clock.reset();
    resume(side);
  }

  Duration _consumeElapsed() {
    final now = _watch.elapsed;
    final delta = now - _lastMark;
    _lastMark = now;
    return delta;
  }
}
