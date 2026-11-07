import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'board_stage.dart';

/// 顶部横条并排放得下标题与棋钟所需的宽度，更窄时两者改为一上一下。
const double _wideBandWidth = 480;

/// 底部横条并排放得下状态与操作所需的宽度，更窄时改为上下两行。
const double _rowBandWidth = 640;

/// 两侧栏的最大宽度，超宽屏上让 HUD 贴着棋盘而不是甩到屏幕边缘。
const double _maxRailWidth = 320;

/// 上下排布时预留给标题行与状态、操作行的固定高度。
///
/// 用固定值而不是测量结果，棋盘尺寸只随窗口大小变化，不会因为提示文字
/// 变长或消失而重新计算布局。
const double _wideTopReserve = 64;
const double _narrowTopReserve = 118;
const double _wideBottomReserve = 76;
const double _narrowBottomReserve = 132;

/// 对局页的悬浮 HUD 骨架：棋盘始终居中占满可用空间，标题、棋钟、状态与操作
/// 挂在棋盘四周的留白里。
///
/// 左右留白足够时 HUD 竖排在棋盘两侧；否则排在棋盘上下，并从可用高度里
/// 预留固定的横条高度。HUD 内容本身不参与棋盘的尺寸与位置计算，
/// 因此提示信息出现、消失或变长都不会让棋盘移位。
class BoardHud extends StatelessWidget {
  const BoardHud({
    super.key,
    required this.board,
    this.topStart,
    this.topEnd,
    this.bottomStart,
    this.bottomEnd,
    this.maxBoardWidth = kBoardMaxWidth,
    this.padding = const EdgeInsets.all(8),
    this.minRailWidth = 150,
    this.gap = 8,
  });

  final Widget board;

  /// 左上角：返回与标题。
  final Widget? topStart;

  /// 右上角：棋钟与规则入口。
  final Widget? topEnd;

  /// 左下角：行棋方、将军、走子提示与开局等信息。
  final Widget? bottomStart;

  /// 右下角：悔棋、重开等操作。
  final Widget? bottomEnd;

  final double maxBoardWidth;
  final EdgeInsets padding;

  /// 左右留白达到该宽度才把 HUD 竖排到棋盘两侧。
  final double minRailWidth;

  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : maxBoardWidth,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : maxBoardWidth * 10 / 9,
        );
        final full = boardFitSize(area, maxBoardWidth);
        final rail = math.max(0.0, (area.width - full.width) / 2);
        final band = math.max(0.0, (area.height - full.height) / 2);
        if (rail >= minRailWidth && rail >= band) {
          return _railLayout(context, full, rail);
        }
        return _bandLayout(context, area);
      },
    );
  }

  /// 两侧栏：左侧标题与状态，右侧棋钟与操作，棋盘独占中间。
  ///
  /// 侧栏贴着棋盘摆放，超宽窗口下不会把 HUD 甩到屏幕边缘。
  Widget _railLayout(BuildContext context, Size size, double rail) {
    final railWidth = math.min(rail, _maxRailWidth);
    return Stack(
      children: [
        Positioned.fill(
          child: Center(child: SizedBox.fromSize(size: size, child: board)),
        ),
        Positioned(
          left: rail - railWidth,
          top: 0,
          bottom: 0,
          width: railWidth,
          child: _rail(
            cross: CrossAxisAlignment.start,
            top: [topStart],
            bottom: bottomStart,
          ),
        ),
        Positioned(
          left: rail + size.width,
          top: 0,
          bottom: 0,
          width: railWidth,
          child: _rail(
            cross: CrossAxisAlignment.end,
            top: [topEnd],
            bottom: bottomEnd,
          ),
        ),
      ],
    );
  }

  /// 上下横条：棋盘在扣掉两条预留高度后居中，横条贴屏幕上下边缘。
  Widget _bandLayout(BuildContext context, Size area) {
    final top = area.width >= _wideBandWidth
        ? _wideTopReserve
        : _narrowTopReserve;
    final bottom = area.width >= _rowBandWidth
        ? _wideBottomReserve
        : _narrowBottomReserve;
    final size = boardFitSize(
      Size(area.width, math.max(0, area.height - top - bottom)),
      maxBoardWidth,
    );
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(top: top, bottom: bottom),
            child: Center(child: SizedBox.fromSize(size: size, child: board)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Padding(
            padding: padding,
            child: _topBand(context, area.width),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: padding,
            child: _bottomBand(context, area.width),
          ),
        ),
      ],
    );
  }

  Widget _topBand(BuildContext context, double width) {
    if (topStart == null && topEnd == null) return const SizedBox.shrink();
    if (width >= _wideBandWidth) {
      return Row(
        children: [
          if (topStart != null) Flexible(child: _card(context, topStart!)),
          const Spacer(),
          if (topEnd != null) _card(context, topEnd!),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topStart != null) _card(context, topStart!),
        if (topStart != null && topEnd != null) SizedBox(height: gap),
        if (topEnd != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_card(context, topEnd!)],
          ),
      ],
    );
  }

  Widget _bottomBand(BuildContext context, double width) {
    if (bottomStart == null && bottomEnd == null) {
      return const SizedBox.shrink();
    }
    if (width >= _rowBandWidth) {
      return Row(
        children: [
          if (bottomStart != null)
            Flexible(child: _card(context, bottomStart!)),
          if (bottomStart != null && bottomEnd != null)
            SizedBox(width: gap),
          if (bottomEnd != null) _card(context, bottomEnd!),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (bottomStart != null)
          Row(
            children: [Flexible(child: _card(context, bottomStart!))],
          ),
        if (bottomStart != null && bottomEnd != null) SizedBox(height: gap),
        if (bottomEnd != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_card(context, bottomEnd!)],
          ),
      ],
    );
  }

  /// 两侧栏：上方一组靠外，下方一组贴底，中间留白随窗口高度伸缩。
  Widget _rail({
    required CrossAxisAlignment cross,
    required List<Widget?> top,
    required Widget? bottom,
  }) {
    final cards = [for (final item in top) ?item];
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: cross,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: cross,
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      if (index > 0) SizedBox(height: gap),
                      _card(context, cards[index]),
                    ],
                  ],
                ),
                if (bottom != null) _card(context, bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 悬浮卡片：半透明表面配细边与浅投影，紧贴棋盘边缘时也不抢视线。
  Widget _card(BuildContext context, Widget child) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: isDark ? 0.90 : 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
