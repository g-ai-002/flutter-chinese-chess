import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../flame/xiangqi_game.dart';

/// 棋盘舞台：统一圆角、投影与 Flame 容器，对局页与复盘页共用。
///
/// 棋盘保持 9:10 的宽高比，按可用空间取最大尺寸。
class BoardStage extends StatelessWidget {
  const BoardStage({
    super.key,
    required this.game,
    required this.gameKey,
    this.maxWidth = 660,
  });

  final XiangqiGame game;
  final Key gameKey;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = math.min(constraints.maxWidth, maxWidth);
        var height = width * 10 / 9;
        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * 9 / 10;
        }
        return Center(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: GameWidget<XiangqiGame>(key: gameKey, game: game),
            ),
          ),
        );
      },
    );
  }
}
