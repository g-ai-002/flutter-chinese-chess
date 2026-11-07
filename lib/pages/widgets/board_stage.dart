import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../flame/xiangqi_game.dart';

/// 棋盘显示的最大宽度，再宽只会拉长视线，不增加有效面积。
const double kBoardMaxWidth = 820;

/// 棋盘尺寸：保持 9:10 的宽高比，在可用空间内取最大尺寸。
Size boardFitSize(Size available, [double maxWidth = kBoardMaxWidth]) {
  final limit = math.max(0.0, available.width);
  final ceiling = math.max(0.0, available.height);
  if (limit <= 0 || ceiling <= 0) return Size.zero;
  var width = math.min(limit, maxWidth);
  var height = width * 10 / 9;
  if (height > ceiling) {
    height = ceiling;
    width = height * 9 / 10;
  }
  return Size(width, height);
}

/// 棋盘舞台：统一圆角、投影与 Flame 容器，对局页与复盘页共用。
///
/// 棋盘保持 9:10 的宽高比，按可用空间取最大尺寸。
class BoardStage extends StatelessWidget {
  const BoardStage({
    super.key,
    required this.game,
    required this.gameKey,
    this.maxWidth = kBoardMaxWidth,
  });

  final XiangqiGame game;
  final Key gameKey;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = boardFitSize(constraints.biggest, maxWidth);
        return Center(
          child: Container(
            width: size.width,
            height: size.height,
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
