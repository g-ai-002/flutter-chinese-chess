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

/// 对局页的悬浮骨架：棋盘居中，标题、棋钟与提示信息浮在棋盘上方与两侧，
/// 控制按钮浮在棋盘下方。
///
/// 上下两条边条按真实内容高度占位，棋盘只吃剩下的空间，所以提示信息再长、
/// 字号再大也不会盖到棋盘上；提示信息行高度固定，文字变长只在行内横向滑动，
/// 不会让棋盘移位。
class BoardHud extends StatelessWidget {
  const BoardHud({
    super.key,
    required this.board,
    this.topStart,
    this.topEnd,
    this.info,
    this.controls,
    this.maxBoardWidth = kBoardMaxWidth,
    this.padding = const EdgeInsets.all(kHudPadding),
    this.gap = kHudRowGap,
  });

  final Widget board;

  /// 左上角：返回与标题。
  final Widget? topStart;

  /// 右上角：棋钟与规则入口。
  final Widget? topEnd;

  /// 行棋方、将军与走子提示等信息：浮在棋盘上方或左侧。
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
        final compact =
            metrics.compact ||
            (metrics.sideRail &&
                math.min(metrics.rail, _maxRailWidth) < _compactRailWidth);
        return Column(
          children: [
            Expanded(
              child: metrics.sideRail
                  ? _railBody(metrics, compact)
                  : _bandBody(context, compact),
            ),
            if (controls != null)
              Padding(
                padding: padding,
                child: Center(
                  child: HudScope(compact: compact, child: controls!),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 两侧栏：标题与提示信息挂在左栏，棋钟挂在右栏，棋盘在两侧栏之间居中。
  Widget _railBody(HudMetrics metrics, bool compact) {
    final railWidth = math.min(metrics.rail, _maxRailWidth);
    final inset = metrics.rail - railWidth;
    return Stack(
      children: [
        // 棋盘宽度按两侧留白收窄，挂在栏里的卡片不会压到棋盘。
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = boardFitSize(
                Size(constraints.maxWidth - metrics.rail * 2, constraints.maxHeight),
                maxBoardWidth,
              );
              return Center(child: SizedBox.fromSize(size: size, child: board));
            },
          ),
        ),
        if (topStart != null || info != null)
          Positioned(
            left: inset,
            top: 0,
            bottom: 0,
            width: railWidth,
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (topStart != null) _card(topStart!, compact),
                  if (info != null)
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: _card(info!, compact),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (topEnd != null)
          Positioned(
            right: inset,
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
      ],
    );
  }

  /// 上下横条：标题与棋钟在上，提示信息紧随棋盘上方，棋盘吃剩下的高度。
  Widget _bandBody(BuildContext context, bool compact) {
    final hasTop = topStart != null || topEnd != null;
    return Column(
      children: [
        if (hasTop || info != null)
          Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasTop) _topWrap(compact),
                if (hasTop && info != null) SizedBox(height: gap),
                if (info != null)
                  SizedBox(
                    height: _infoRowHeight(context, compact),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _card(info!, compact),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = boardFitSize(constraints.biggest, maxBoardWidth);
              return Center(child: SizedBox.fromSize(size: size, child: board));
            },
          ),
        ),
      ],
    );
  }

  /// 标题与棋钟并排：放不下时后一个自动换到下一行，不会横向溢出。
  Widget _topWrap(bool compact) {
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      alignment: WrapAlignment.spaceBetween,
      children: [
        if (topStart != null) _card(topStart!, compact),
        if (topEnd != null) _card(topEnd!, compact),
      ],
    );
  }

  /// 提示信息行的高度按固定基数与字号缩放，内容变化不会推动棋盘。
  double _infoRowHeight(BuildContext context, bool compact) {
    final base = compact ? kHudCompactInfoRow : kHudInfoRow;
    return base * _textScale(context);
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
