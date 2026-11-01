import 'package:flutter/material.dart';

import '../game/engine/board_utils.dart';

/// 棋面渐变配色：红方暖象牙、黑方冷灰绿，用底色差异强化阵营辨识。
class PieceFace {
  const PieceFace({required this.light, required this.dark, required this.ink});

  final Color light;
  final Color dark;
  final Color ink;
}

/// 棋盘皮肤：棋盘底色、线条墨色、高亮色与双方棋面配色。
///
/// 皮肤只影响绘制，不参与规则与对局逻辑，对局页、复盘页与首页缩略图共用。
class BoardSkin {
  const BoardSkin({
    required this.id,
    required this.name,
    required this.description,
    required this.boardLight,
    required this.boardDark,
    required this.line,
    required this.redInk,
    required this.redFace,
    required this.blackFace,
  });

  final String id;
  final String name;
  final String description;
  final Color boardLight;
  final Color boardDark;
  final Color line;

  /// 选中、将军与落点提示使用的强调色。
  final Color redInk;
  final PieceFace redFace;
  final PieceFace blackFace;

  PieceFace faceOf(int side) => side == red ? redFace : blackFace;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [boardLight, boardDark],
  );
}

/// 檀木：经典木纹配宣纸棋面。
const BoardSkin woodSkin = BoardSkin(
  id: 'wood',
  name: '檀木',
  description: '经典木纹',
  boardLight: Color(0xFFF4E3C1),
  boardDark: Color(0xFFE3C795),
  line: Color(0xFF8A6337),
  redInk: Color(0xFF9E2F23),
  redFace: PieceFace(
    light: Color(0xFFFFF5E6),
    dark: Color(0xFFEEC9A0),
    ink: Color(0xFFA63A2B),
  ),
  blackFace: PieceFace(
    light: Color(0xFFF1F4EE),
    dark: Color(0xFFC3CEC1),
    ink: Color(0xFF39433F),
  ),
);

/// 青玉：淡青棋盘配冷调线条，适合白天久坐。
const BoardSkin jadeSkin = BoardSkin(
  id: 'jade',
  name: '青玉',
  description: '淡青素雅',
  boardLight: Color(0xFFE9F1E4),
  boardDark: Color(0xFFC9DCC8),
  line: Color(0xFF4C6B57),
  redInk: Color(0xFF9E2F23),
  redFace: PieceFace(
    light: Color(0xFFFFF9EF),
    dark: Color(0xFFEFD6B4),
    ink: Color(0xFF9E2F23),
  ),
  blackFace: PieceFace(
    light: Color(0xFFF3F7F2),
    dark: Color(0xFFC8D8CB),
    ink: Color(0xFF2F4438),
  ),
);

/// 墨韵：深墨棋盘配浅色线条，夜间观感沉静。
const BoardSkin inkSkin = BoardSkin(
  id: 'ink',
  name: '墨韵',
  description: '深墨夜局',
  boardLight: Color(0xFF4C524D),
  boardDark: Color(0xFF2E3330),
  line: Color(0xFFE2DAC8),
  redInk: Color(0xFFF0A48C),
  redFace: PieceFace(
    light: Color(0xFFF6E7D2),
    dark: Color(0xFFD9BE9A),
    ink: Color(0xFF8E2A1F),
  ),
  blackFace: PieceFace(
    light: Color(0xFFEDEFEA),
    dark: Color(0xFFC6CCC5),
    ink: Color(0xFF2E3330),
  ),
);

/// 全部可选皮肤，顺序即设置页展示顺序。
const List<BoardSkin> kBoardSkins = [woodSkin, jadeSkin, inkSkin];

/// 按 id 取皮肤，未知 id 回退檀木，兼容旧版本偏好。
BoardSkin boardSkinOf(String? id) =>
    kBoardSkins.firstWhere((skin) => skin.id == id, orElse: () => woodSkin);
