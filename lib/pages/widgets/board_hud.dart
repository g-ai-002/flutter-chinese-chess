import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/board_layout.dart';

/// 侧栏窄于该宽度时改用紧凑卡片：隐藏次要文字，操作只留图标。
const double _compactRailWidth = 190;

/// 两侧栏的最大宽度，超宽屏上让 HUD 贴着棋盘而不是甩到屏幕边缘。
const double _maxRailWidth = 320;

/// HUD 密度标记：紧凑模式下卡片只保留关键信息，把空间让给棋盘。
class HudScope extends InheritedWidget {
  const HudScope({super.key, required this.compact, required super.child});

  final bool compact;

  static bool compactOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HudScope>()?.compact ?? false;

  @override
  bool updateShouldNotify(HudScope oldWidget) => oldWidget.compact != compact;
}

/// 对局页的悬浮骨架：棋盘居中，标题、棋钟与提示信息浮在棋盘上方与左侧，
/// 控制按钮浮在棋盘下方。
///
/// 卡片不参与棋盘的尺寸计算，提示信息出现、消失或变长都不会让棋盘移位；
/// 左右留白不够时提示信息改排到棋盘上方，同样预留固定高度。
class BoardHud extends StatelessWidget {
  const BoardHud({
    super.key,
    required this.board,
    this.topStart,
    this.topEnd,
    this.info,
    this.controls,
    this.maxBoardWidth = kBoardMaxWidth,
    this.padding = const EdgeInsets.all(8),
    this.gap = kHudRowGap,
  });

  final Widget board;

  /// 左上角：返回与标题。
  final Widget? topStart;

  /// 右上角：棋钟与规则入口。
  final Widget? topEnd;

  /// 行棋方、将军、走子提示与开局等信息：浮在棋盘左侧或上方。
  final Widget? info;

  /// 悔棋、重开、棋谱等控制按钮：浮在棋盘下方。
  final Widget? controls;

  final double maxBoardWidth;
  final EdgeInsets padding;
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
        final metrics = resolveHud(
          area,
          maxWidth: maxBoardWidth,
          textScale: _textScale(context),
        );
        if (metrics.sideRail) return _railLayout(metrics);
        return _bandLayout(metrics);
      },
    );
  }

  /// 两侧栏：标题在左栏顶部、提示信息在左栏垂直居中，棋钟在右栏顶部，棋盘居中。
  Widget _railLayout(HudMetrics metrics) {
    final railWidth = math.min(metrics.rail, _maxRailWidth);
    final compact = metrics.compact || railWidth < _compactRailWidth;
    final left = metrics.rail - railWidth;
    return Stack(
      children: [
        Positioned.fill(
          bottom: metrics.bottom,
          child: Center(
            child: SizedBox.fromSize(size: metrics.board, child: board),
          ),
        ),
        if (info != null)
          Positioned(
            left: left,
            top: 0,
            bottom: metrics.bottom,
            width: railWidth,
            child: Padding(
              padding: padding,
              child: Center(child: _card(info!, compact)),
            ),
          ),
        if (topStart != null)
          Positioned(
            left: left,
            top: 0,
            width: railWidth,
            child: Padding(padding: padding, child: _card(topStart!, compact)),
          ),
        if (topEnd != null)
          Positioned(
            left: metrics.rail + metrics.board.width,
            top: 0,
            width: railWidth,
            child: Padding(
              padding: padding,
              child: Align(
                alignment: Alignment.topRight,
                child: _card(topEnd!, compact),
              ),
            ),
          ),
        ?_controlsBand(compact),
      ],
    );
  }

  /// 上下横条：标题与棋钟在上，提示信息紧随其后，控制按钮贴底。
  Widget _bandLayout(HudMetrics metrics) {
    final compact = metrics.compact;
    final stacked = metrics.stacked;
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(top: metrics.top, bottom: metrics.bottom),
            child: Center(
              child: SizedBox.fromSize(size: metrics.board, child: board),
            ),
          ),
        ),
        if (topStart != null || topEnd != null || info != null)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (topStart != null || topEnd != null)
                    _topRows(compact: compact, stacked: stacked),
                  if ((topStart != null || topEnd != null) && info != null)
                    SizedBox(height: gap),
                  // 横条空间有限，提示排成一行横向滑动，不因文字变长而改变高度。
                  if (info != null)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _card(info!, compact),
                    ),
                ],
              ),
            ),
          ),
        ?_controlsBand(compact),
      ],
    );
  }

  /// 底部控制条：所有操作按钮都浮在棋盘下方，横向居中。
  Widget? _controlsBand(bool compact) {
    final controls = this.controls;
    if (controls == null) return null;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: padding,
        child: HudScope(
          compact: compact,
          child: Center(child: controls),
        ),
      ),
    );
  }

  /// 标题与棋钟：宽度够时并排一行，窄屏上棋钟换到第二行靠右。
  Widget _topRows({required bool compact, required bool stacked}) {
    if (!stacked) {
      return Row(
        children: [
          if (topStart != null) Flexible(child: _card(topStart!, compact)),
          if (topStart != null && topEnd != null) SizedBox(width: gap),
          if (topEnd != null) _card(topEnd!, compact),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topStart != null) _card(topStart!, compact),
        if (topStart != null && topEnd != null) SizedBox(height: gap),
        if (topEnd != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_card(topEnd!, compact)],
          ),
      ],
    );
  }

  double _textScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) / 14;

  /// 悬浮卡片：半透明表面配细边与浅投影，紧贴棋盘边缘时也不抢视线。
  Widget _card(Widget child, bool compact) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        return HudScope(
          compact: compact,
          child: Container(
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
                : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: isDark ? 0.90 : 0.94),
              borderRadius: BorderRadius.circular(compact ? 14 : 16),
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
          ),
        );
      },
    );
  }
}
