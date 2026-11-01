import 'package:flutter/material.dart';

/// 对局页与复盘页共用的棋盘布局骨架。
///
/// 宽屏为「左侧棋盘 + 右侧 292 棋谱栏」两栏，窄屏为上下堆叠；
/// 两页只需提供棋盘、棋谱栏与各自的顶部状态区和底部操作区。
class PlayLayout extends StatelessWidget {
  const PlayLayout({
    super.key,
    required this.board,
    required this.sidePanel,
    this.status,
    this.actions,
    this.compactBottom,
    this.compactStatusPadding = const EdgeInsets.fromLTRB(16, 2, 16, 8),
  });

  final Widget board;
  final Widget sidePanel;

  /// 棋盘上方的状态区，窄屏时同样显示在棋盘上方。
  final Widget? status;

  /// 宽屏棋盘下方的操作区。
  final Widget? actions;

  /// 窄屏棋盘下方的区域，缺省时使用 [actions]。
  final Widget? compactBottom;

  final EdgeInsets compactStatusPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= 880 ? _buildWide() : _buildCompact(),
    );
  }

  Widget _buildWide() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                if (status != null) ...[status!, const SizedBox(height: 10)],
                Expanded(child: board),
                if (actions != null) ...[const SizedBox(height: 8), actions!],
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(width: 292, child: sidePanel),
        ],
      ),
    );
  }

  Widget _buildCompact() {
    final bottom = compactBottom ?? actions;
    return Column(
      children: [
        if (status != null)
          Padding(padding: compactStatusPadding, child: status!),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: board,
          ),
        ),
        ?bottom,
      ],
    );
  }
}
