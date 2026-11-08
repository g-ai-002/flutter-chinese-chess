import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../flame/xiangqi_game.dart';
import '../../utils/board_layout.dart';

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
