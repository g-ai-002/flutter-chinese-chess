import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/board_view.dart';
import '../game/logic_rate.dart';
import '../theme/board_skin.dart';
import 'board_component.dart';

/// Flame 游戏入口：目前只有一个棋盘组件，后续可扩展落子特效与音效。
class XiangqiGame extends FlameGame {
  XiangqiGame({
    required this.view,
    BoardSkin skin = kDefaultBoardSkin,
    this.logicRate = LogicRate.hz60,
    this.changes,
  }) : _skin = ValueNotifier(skin) {
    _skin.addListener(_wake);
    changes?.addListener(_wake);
  }

  /// 棋盘静止 [idlePauseSeconds] 后停掉渲染循环，落子、提示与页面变化再唤醒。
  static const double idlePauseSeconds = 0.75;

  final BoardView view;

  /// 棋盘逻辑更新速率，见 [LogicRate]。
  final LogicRate logicRate;

  /// 对局或复盘控制器，状态变化时唤醒可能已休眠的渲染循环。
  final Listenable? changes;
  final ValueNotifier<BoardSkin> _skin;
  BoardComponent? _board;
  double _idle = 0;

  /// 当前棋盘皮肤，赋值后棋盘按新配色重绘。
  BoardSkin get skin => _skin.value;
  set skin(BoardSkin value) => _skin.value = value;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    final board = BoardComponent(
      view: view,
      skin: _skin,
      logicRate: logicRate,
      onInput: _wake,
    );
    _board = board;
    _fit(board);
    await add(board);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final board = _board;
    if (paused || board == null) return;
    // 落子动画与将军呼吸灯需要逐帧推进，其余静止画面没有必要重绘。
    if (board.isAnimating || view.inCheck) {
      _idle = 0;
      return;
    }
    _idle += dt;
    if (_idle < idlePauseSeconds) return;
    _idle = 0;
    pauseEngine();
  }

  void _wake() {
    _idle = 0;
    if (paused) resumeEngine();
  }

  @override
  void onDispose() {
    _skin.removeListener(_wake);
    changes?.removeListener(_wake);
    super.onDispose();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final board = _board;
    if (board != null) _fit(board);
  }

  /// 棋盘始终铺满游戏区域，随窗口或屏幕尺寸变化重建尺寸。
  void _fit(BoardComponent board) {
    board
      ..size = size.clone()
      ..position = Vector2.zero();
  }
}
