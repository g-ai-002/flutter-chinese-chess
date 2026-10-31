import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import 'board_component.dart';

/// Flame 游戏入口：目前只有一个棋盘组件，后续可扩展落子特效与音效。
class XiangqiGame extends FlameGame {
  XiangqiGame({required this.controller});

  final GameController controller;
  BoardComponent? _board;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    final board = BoardComponent(controller: controller)
      ..size = size.clone()
      ..position = Vector2.zero();
    _board = board;
    await add(board);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final board = _board;
    if (board != null) {
      board.size = size.clone();
      board.position = Vector2.zero();
    }
  }
}
