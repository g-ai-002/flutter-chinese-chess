import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 棋盘与 HUD 的几何规则：对局页排版、棋盘舞台与横竖屏判定共用一份尺寸计算。
///
/// 棋盘是 9:10 的竖向网格，所以最好的显示效果通常是竖屏：横屏要把屏幕高度
/// 对折给棋盘，棋盘反而更小。只有横屏确实能给棋盘更大面积时才值得强制横屏。

/// 棋盘显示的最大宽度，再宽只会拉长视线，不增加有效面积。
const double kBoardMaxWidth = 820;

/// 左右留白达到该宽度才把悬浮卡片挂到棋盘两侧，否则排到棋盘上方。
const double kHudRailWidth = 120;

/// 窄于该宽度时标题与棋钟改为上下两行，避免互相挤压。
const double kHudStackedWidth = 480;

/// 可用高度不足该值时改用紧凑横条，避免预留高度把棋盘压得过小。
const double kHudCompactHeight = 520;

/// 顶部各行的预留基数（未乘字号缩放）：标题行、提示信息行与行间距。
const double kHudTitleRow = 46;
const double kHudInfoRow = 34;
const double kHudCompactTitleRow = 34;
const double kHudCompactInfoRow = 30;
const double kHudRowGap = 8;

/// 底部控制按钮行的预留基数。
const double kHudBottomRow = 46;
const double kHudCompactBottomRow = 38;

/// 棋盘按 9:10 宽高比在可用空间内取最大尺寸。
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

/// 一次 HUD 排版的尺寸结果。
class HudMetrics {
  const HudMetrics({
    required this.board,
    required this.top,
    required this.bottom,
    required this.rail,
    required this.compact,
    required this.stacked,
    required this.sideRail,
  });

  /// 棋盘尺寸。
  final Size board;

  /// 顶部横条预留高度，侧栏排版时为 0（标题与棋钟挂在侧栏顶部）。
  final double top;

  /// 底部控制条预留高度。
  final double bottom;

  /// 棋盘左右留白宽度。
  final double rail;

  /// 是否使用紧凑卡片。
  final bool compact;

  /// 标题与棋钟是否上下两行排布。
  final bool stacked;

  /// 是否把提示信息挂到棋盘两侧。
  final bool sideRail;
}

/// 计算对局页的棋盘尺寸与预留：控制按钮固定在下方，标题与棋钟在上方，
/// 左右留白够宽时提示信息挂到棋盘左侧，否则排到棋盘上方。
HudMetrics resolveHud(
  Size area, {
  double maxWidth = kBoardMaxWidth,
  double textScale = 1,
}) {
  final scale = textScale.clamp(1.0, 1.35).toDouble();
  final compact = area.height < kHudCompactHeight;
  final stacked = area.width < kHudStackedWidth;
  final bottom = _bottomReserve(compact, scale);
  final full = boardFitSize(
    Size(area.width, math.max(0, area.height - bottom)),
    maxWidth,
  );
  final rail = math.max(0.0, (area.width - full.width) / 2);
  if (rail >= kHudRailWidth) {
    return HudMetrics(
      board: full,
      top: 0,
      bottom: bottom,
      rail: rail,
      compact: compact,
      stacked: stacked,
      sideRail: true,
    );
  }
  final top = _topReserve(stacked, compact, scale);
  final board = boardFitSize(
    Size(area.width, math.max(0, area.height - top - bottom)),
    maxWidth,
  );
  return HudMetrics(
    board: board,
    top: top,
    bottom: bottom,
    rail: rail,
    compact: compact,
    stacked: stacked,
    sideRail: false,
  );
}

/// 横屏是否给棋盘带来更大的显示面积。
///
/// 手机等窄屏竖屏设备上 9:10 的棋盘几乎总是竖屏更大，此时应保持竖屏，
/// 不再强行旋转并隐藏系统栏。
bool gridFitsBetterLandscape(
  Size area, {
  double maxWidth = kBoardMaxWidth,
  double textScale = 1,
}) {
  if (area.width <= 0 || area.height <= 0) return false;
  final portrait = resolveHud(
    area,
    maxWidth: maxWidth,
    textScale: textScale,
  ).board;
  final landscape = resolveHud(
    Size(area.height, area.width),
    maxWidth: maxWidth,
    textScale: textScale,
  ).board;
  return landscape.width * landscape.height > portrait.width * portrait.height;
}

double _topReserve(bool stacked, bool compact, double scale) {
  final rows = stacked ? 2.0 : 1.0;
  final title = compact ? kHudCompactTitleRow : kHudTitleRow;
  final info = compact ? kHudCompactInfoRow : kHudInfoRow;
  return (title * rows + info + kHudRowGap * rows) * scale;
}

double _bottomReserve(bool compact, double scale) =>
    ((compact ? kHudCompactBottomRow : kHudBottomRow) + 16) * scale;
