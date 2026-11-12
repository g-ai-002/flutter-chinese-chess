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

/// 窄于该宽度时标题与棋钟预计要上下两行（只用于棋盘尺寸估算）。
const double kHudStackedWidth = 480;

/// 可用高度不足该值时改用紧凑卡片，状态并入标题行。
const double kHudCompactHeight = 520;

const double kHudPadding = 8;

const double kHudTitleRow = 58;
const double kHudInfoRow = 48;
const double kHudCompactTitleRow = 54;
const double kHudCompactInfoRow = 40;
const double kHudRowGap = 8;
const double kHudBottomRow = 64;
const double kHudCompactBottomRow = 54;

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

class HudMetrics {
  const HudMetrics({
    required this.board,
    required this.rail,
    required this.compact,
    required this.sideRail,
  });

  final Size board;

  final double rail;

  final bool compact;

  final bool sideRail;
}

/// 计算对局页的排版决策：操作按钮固定在下方，左右留白够宽时标题、棋钟与
/// 提示信息挂到棋盘两侧，否则排到棋盘上方。
HudMetrics resolveHud(
  Size area, {
  double maxWidth = kBoardMaxWidth,
  double textScale = 1,
}) {
  final scale = _scale(textScale);
  final compact = area.height < kHudCompactHeight;
  final bottom = _bottomReserve(compact, scale);
  final railBoard = boardFitSize(
    Size(area.width, math.max(0, area.height - bottom)),
    maxWidth,
  );
  final rail = math.max(0.0, (area.width - railBoard.width) / 2);
  if (rail >= kHudRailWidth) {
    return HudMetrics(
      board: railBoard,
      rail: rail,
      compact: compact,
      sideRail: true,
    );
  }
  final top = _topReserve(area.width < kHudStackedWidth, compact, scale);
  return HudMetrics(
    board: boardFitSize(
      Size(area.width, math.max(0, area.height - top - bottom)),
      maxWidth,
    ),
    rail: rail,
    compact: compact,
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

double _scale(double textScale) => textScale.clamp(1.0, 1.35).toDouble();

double _topReserve(bool stacked, bool compact, double scale) {
  final title = compact ? kHudCompactTitleRow : kHudTitleRow;
  final info = compact ? kHudCompactInfoRow : kHudInfoRow;
  final rows = stacked ? 2.0 : 1.0;
  return kHudPadding * 2 + (rows * (title + kHudRowGap) + info) * scale;
}

double _bottomReserve(bool compact, double scale) =>
    (compact ? kHudCompactBottomRow : kHudBottomRow) * scale;
