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
