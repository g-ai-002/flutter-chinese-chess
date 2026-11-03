import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/engine/board_utils.dart';
import '../game/engine/rules.dart';
import '../game/board_view.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../theme/board_painting.dart';
import '../theme/board_skin.dart';

const double _moveDurationSeconds = 0.24;
const double _landingDurationSeconds = 0.34;
const double _shatterDurationSeconds = 0.55;
const double _trailGap = 0.10;
const Color _hintColor = Color(0xFF8C5A0F);
const Color _hintOutline = Color(0xE62A1C08);

/// Flame 棋盘组件：绘制棋盘、棋子、走子提示与落子动画，并处理点击。
///
/// 皮肤通过 [skin] 监听，切换皮肤时清空文字缓存并按新配色重绘。
class BoardComponent extends PositionComponent with TapCallbacks {
  BoardComponent({required this.view, required this.skin});

  final BoardView view;
  final ValueListenable<BoardSkin> skin;

  BoardSkin get _skin => skin.value;

  @visibleForTesting
  bool get isAnimating => _anim != null;

  double _cell = 0;
  double _time = 0;
  int _seenMoves = -1;
  _MoveAnim? _anim;
  double _cacheCell = 0;
  final Map<int, TextPainter> _piecePainters = {};
  final Map<String, TextPainter> _textPainters = {};

  ui.Picture? _boardLayer;
  ui.Picture? _pieceLayer;
  int _pieceSignature = 0;
  double _layerCell = 0;
  String _layerSkin = '';
  final Map<int, ui.Picture> _sprites = {};

  @override
  Future<void> onLoad() async {
    skin.addListener(_clearTextCaches);
  }

  @override
  void onRemove() {
    skin.removeListener(_clearTextCaches);
    _clearTextCaches();
    super.onRemove();
  }

  void _clearTextCaches() {
    _piecePainters.clear();
    _textPainters.clear();
    for (final sprite in _sprites.values) {
      sprite.dispose();
    }
    _sprites.clear();
    _invalidateLayers();
  }

  void _invalidateLayers() {
    _boardLayer?.dispose();
    _pieceLayer?.dispose();
    _boardLayer = null;
    _pieceLayer = null;
    _layerCell = 0;
    _layerSkin = '';
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    final count = view.history.length;
    if (count != _seenMoves) {
      if (count > _seenMoves && _seenMoves >= 0 && view.history.isNotEmpty) {
        final last = view.history.last;
        _anim = _MoveAnim(
          from: last.from,
          to: last.to,
          piece: last.piece,
          captured: last.captured,
        );
      } else {
        _anim = null;
      }
      _seenMoves = count;
    }

    final anim = _anim;
    if (anim != null) {
      anim.elapsed += dt;
      if (anim.elapsed >= anim.totalDuration) _anim = null;
    }
  }

  @override
  void render(Canvas canvas) {
    if (size.x <= 0 || size.y <= 0) return;
    final cell = math.min(size.x / boardCols, size.y / boardRows);
    _cell = cell;
    final origin = Offset(
      (size.x - cell * boardCols) / 2,
      (size.y - cell * boardRows) / 2,
    );
    if ((_cacheCell - cell).abs() > 0.5) {
      _cacheCell = cell;
      _piecePainters.clear();
      _textPainters.clear();
      for (final sprite in _sprites.values) {
        sprite.dispose();
      }
      _sprites.clear();
      _invalidateLayers();
    }

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.drawPicture(_boardPicture(cell));
    _drawHighlights(canvas, cell);
    if (_anim == null) {
      canvas.drawPicture(_piecesPicture(cell));
    } else {
      _drawAnimatedPieces(canvas, cell);
    }
    _drawHint(canvas, cell);
    canvas.restore();
  }

  /// 棋盘底色、网格与河界文字只随尺寸和皮肤变化，录制为图片后逐帧复用。
  ui.Picture _boardPicture(double cell) {
    final cached = _boardLayer;
    if (cached != null &&
        (_layerCell - cell).abs() < 0.01 &&
        _layerSkin == _skin.id) {
      return cached;
    }
    _boardLayer?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _drawBoard(canvas, cell);
    _boardLayer = recorder.endRecording();
    _layerCell = cell;
    _layerSkin = _skin.id;
    return _boardLayer!;
  }

  /// 静止棋子整层缓存，局面或尺寸变化时重录；落子动画期间改用棋子小图。
  ui.Picture _piecesPicture(double cell) {
    final signature = Object.hash(
      Object.hashAll(view.board.cells),
      view.history.length,
      cell,
      _skin.id,
    );
    final cached = _pieceLayer;
    if (cached != null && _pieceSignature == signature) return cached;
    _pieceLayer?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var index = 0; index < cellCount; index++) {
      final piece = view.board.cells[index];
      if (piece == 0) continue;
      _drawPiece(canvas, _center(index, cell), piece, cell);
    }
    _pieceLayer = recorder.endRecording();
    _pieceSignature = signature;
    return _pieceLayer!;
  }

  Offset _center(int index, double cell) =>
      Offset((colOf(index) + 0.5) * cell, (rowOf(index) + 0.5) * cell);

  void _drawBoard(Canvas canvas, double cell) {
    final skin = _skin;
    final rect = Rect.fromLTWH(0, 0, cell * boardCols, cell * boardRows);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.22));
    canvas.drawRRect(rrect, Paint()..shader = skin.gradient.createShader(rect));

    canvas.drawRRect(
      rrect.deflate(cell * 0.10),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.018
        ..color = skin.line.withValues(alpha: 0.35),
    );

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.9, cell * 0.014)
      ..color = skin.line.withValues(alpha: 0.78);

    final left = cell * 0.5;
    final top = cell * 0.5;

    paintBoardGrid(
      canvas,
      topLeft: Offset(left, top),
      cell: cell,
      linePaint: linePaint,
      palacePaint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = linePaint.strokeWidth
        ..color = skin.line.withValues(alpha: 0.6),
      borderPaint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.032
        ..color = skin.line.withValues(alpha: 0.9),
    );

    final riverStyle = pieceTextStyle(
      fontSize: cell * 0.42,
      fontWeight: FontWeight.w600,
      color: skin.line.withValues(alpha: 0.62),
    ).copyWith(letterSpacing: cell * 0.16);
    _drawText(
      canvas,
      '楚  河',
      Offset(left + cell * 2.5, top + cell * 4.5),
      riverStyle,
      key: 'river-left',
    );
    _drawText(
      canvas,
      '漢  界',
      Offset(left + cell * 5.5, top + cell * 4.5),
      riverStyle,
      key: 'river-right',
    );

    _drawMarkers(canvas, cell, left, top);
  }

  void _drawMarkers(Canvas canvas, double cell, double left, double top) {
    const points = [
      (2, 1),
      (2, 7),
      (7, 1),
      (7, 7),
      (3, 0),
      (3, 2),
      (3, 4),
      (3, 6),
      (3, 8),
      (6, 0),
      (6, 2),
      (6, 4),
      (6, 6),
      (6, 8),
    ];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.025
      ..strokeCap = StrokeCap.round
      ..color = _skin.line.withValues(alpha: 0.55);
    final gap = cell * 0.09;
    final length = cell * 0.13;
    for (final (row, col) in points) {
      final center = Offset(left + col * cell, top + row * cell);
      for (final sx in const [-1.0, 1.0]) {
        for (final sy in const [-1.0, 1.0]) {
          if (col == 0 && sx < 0) continue;
          if (col == boardCols - 1 && sx > 0) continue;
          final corner = center + Offset(sx * gap, sy * gap);
          canvas.drawLine(corner, corner + Offset(sx * length, 0), paint);
          canvas.drawLine(corner, corner + Offset(0, sy * length), paint);
        }
      }
    }
  }

  void _drawHighlights(Canvas canvas, double cell) {
    final lastFrom = view.board.lastFrom;
    final lastTo = view.board.lastTo;
    if (lastFrom != null && lastTo != null) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.03
        ..strokeCap = StrokeCap.round
        ..color = _skin.redInk.withValues(alpha: 0.45);
      _drawCellBrackets(canvas, _center(lastFrom, cell), cell, paint);
      _drawCellBrackets(canvas, _center(lastTo, cell), cell, paint);
    }

    final selected = view.selected;
    if (selected != null) {
      final center = _center(selected, cell);
      final radius = cell * 0.47;
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = _skin.redInk.withValues(alpha: 0.10),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.028
          ..color = _skin.redInk.withValues(alpha: 0.55),
      );
    }

    if (view.showHints && view.legalTargets.isNotEmpty) {
      for (final index in view.legalTargets) {
        final center = _center(index, cell);
        if (view.board.cells[index] == 0) {
          canvas.drawCircle(
            center,
            cell * 0.075,
            Paint()..color = _skin.line.withValues(alpha: 0.42),
          );
        } else {
          canvas.drawCircle(
            center,
            cell * 0.46,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.028
              ..color = _skin.redInk.withValues(alpha: 0.55),
          );
        }
      }
    }

    if (view.inCheck) {
      final king = XiangqiRules.findKing(
        view.board.cells,
        view.board.sideToMove,
      );
      if (king != null) {
        final pulse = 0.55 + 0.45 * math.sin(_time * 5.5);
        final center = _center(king, cell);
        canvas.drawCircle(
          center,
          cell * 0.48,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.06
            ..color = _skin.redInk.withValues(alpha: 0.15 + 0.15 * pulse),
        );
        canvas.drawCircle(
          center,
          cell * 0.47,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.025
            ..color = _skin.redInk.withValues(alpha: 0.55 + 0.3 * pulse),
        );
      }
    }
  }

  /// 提示箭头画在棋子之上，保证被提示的起点与落点清晰可见。
  void _drawHint(Canvas canvas, double cell) {
    final from = view.hintFrom;
    final to = view.hintTo;
    if (from != null && to != null && from != to) {
      _drawHintArrow(canvas, cell, from, to);
    }
  }

  /// 提示箭头：从起点圈向落点圈引一条带箭头的实线，采用与红黑提示都区分开的金色。
  ///
  /// 先铺一层深色描边再画金色主体，浅色与深色棋盘上都能看清。
  void _drawHintArrow(Canvas canvas, double cell, int from, int to) {
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.095
      ..strokeCap = StrokeCap.round
      ..color = _hintOutline;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.052
      ..strokeCap = StrokeCap.round
      ..color = _hintColor.withValues(alpha: 0.96);
    final start = _center(from, cell);
    final end = _center(to, cell);
    final radius = cell * 0.46;
    canvas.drawCircle(start, radius, outline);
    canvas.drawCircle(start, radius, paint);
    canvas.drawCircle(end, radius, outline);
    canvas.drawCircle(end, radius, paint);

    final delta = end - start;
    final distance = delta.distance;
    if (distance <= cell * 0.9) return;
    final unit = delta / distance;
    final lineStart = start + unit * (cell * 0.42);
    final lineEnd = end - unit * (cell * 0.42);
    canvas.drawLine(lineStart, lineEnd, outline);
    canvas.drawLine(lineStart, lineEnd, paint);

    final angle = math.atan2(unit.dy, unit.dx);
    const spread = 0.55;
    for (final side in const [-1.0, 1.0]) {
      final tip =
          lineEnd -
          Offset(
                math.cos(angle + side * spread),
                math.sin(angle + side * spread),
              ) *
              (cell * 0.30);
      canvas.drawLine(lineEnd, tip, outline);
      canvas.drawLine(lineEnd, tip, paint);
    }
  }

  void _drawCellBrackets(
    Canvas canvas,
    Offset center,
    double cell,
    Paint paint,
  ) {
    final half = cell * 0.42;
    final length = cell * 0.18;
    final corners = [
      (Offset(-half, -half), const Offset(1, 0), const Offset(0, 1)),
      (Offset(half, -half), const Offset(-1, 0), const Offset(0, 1)),
      (Offset(-half, half), const Offset(1, 0), const Offset(0, -1)),
      (Offset(half, half), const Offset(-1, 0), const Offset(0, -1)),
    ];
    for (final (offset, dx, dy) in corners) {
      final corner = center + offset;
      canvas.drawLine(corner, corner + dx * length, paint);
      canvas.drawLine(corner, corner + dy * length, paint);
    }
  }

  void _drawAnimatedPieces(Canvas canvas, double cell) {
    final anim = _anim!;
    for (var index = 0; index < cellCount; index++) {
      final piece = view.board.cells[index];
      if (piece == 0) continue;
      if (index == anim.to) continue;
      _drawPiece(canvas, _center(index, cell), piece, cell);
    }

    final from = _center(anim.from, cell);
    final to = _center(anim.to, cell);
    final progress = anim.travel;
    final eased = _ease(progress);
    if (anim.captured != 0 && !anim.landed) {
      _drawPiece(canvas, to, anim.captured, cell);
    }

    // 残影：沿路径取三个更早的位置，合并到同一图层绘制，避免逐帧多次 saveLayer。
    if (!anim.landed) {
      final ghosts = <(Offset, double)>[];
      for (var step = 3; step >= 1; step--) {
        final trail = progress - _trailGap * step;
        if (trail <= 0) continue;
        ghosts.add((Offset.lerp(from, to, _ease(trail))!, 1 - 0.015 * step));
      }
      if (ghosts.isNotEmpty) {
        canvas.saveLayer(
          Rect.fromLTWH(0, 0, size.x, size.y),
          Paint()..color = Colors.white.withValues(alpha: 0.18),
        );
        for (final (position, scale) in ghosts) {
          _drawPiece(canvas, position, anim.piece, cell, scale: scale);
        }
        canvas.restore();
      }
    }

    _drawPiece(
      canvas,
      Offset.lerp(from, to, eased)!,
      anim.piece,
      cell,
      scale: 1 + 0.06 * math.sin(math.pi * progress),
    );

    if (anim.landed) {
      _drawLanding(canvas, to, cell, anim);
      if (anim.captured != 0) _drawPowder(canvas, to, cell, anim);
    }
  }

  /// 落点涟漪：一圈由内向外扩散的细环，移动与吃子都会出现。
  void _drawLanding(Canvas canvas, Offset center, double cell, _MoveAnim anim) {
    final t = anim.landing;
    if (t >= 1) return;
    final fade = 1 - t;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.045 * fade
      ..color = _skin.redInk.withValues(alpha: 0.42 * fade);
    canvas.drawCircle(center, cell * (0.30 + 0.30 * t), paint);
    canvas.drawCircle(
      center,
      cell * (0.22 + 0.20 * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.03 * fade
        ..color = _skin.redInk.withValues(alpha: 0.24 * fade),
    );
  }

  /// 被吃棋子碎裂：落点闪白后向四周飞散木质粉末，受重力逐渐下坠。
  void _drawPowder(Canvas canvas, Offset center, double cell, _MoveAnim anim) {
    final t = anim.shatter;
    if (t <= 0) return;
    final face = _skin.faceOf(sideOf(anim.captured));
    final colors = [face.light, face.dark, face.ink];
    if (t < 0.35) {
      final flash = 1 - t / 0.35;
      canvas.drawCircle(
        center,
        cell * (0.18 + 0.22 * (t / 0.35)),
        Paint()..color = face.light.withValues(alpha: 0.55 * flash),
      );
    }
    for (final particle in anim.powder) {
      final local = ((t - particle.delay) / (1 - particle.delay)).clamp(
        0.0,
        1.0,
      );
      if (local <= 0) continue;
      final travel = 1 - math.pow(1 - local, 3).toDouble();
      final distance = particle.distance * cell * travel;
      final offset = Offset(
        math.cos(particle.angle) * distance,
        math.sin(particle.angle) * distance + cell * 0.55 * local * local,
      );
      final alpha = (1 - local) * (1 - local);
      canvas.drawCircle(
        center + offset,
        particle.size * cell * (1 - 0.45 * local),
        Paint()..color = colors[particle.shade].withValues(alpha: 0.95 * alpha),
      );
    }
  }

  double _ease(double t) => t * t * (3 - 2 * t);

  void _drawPiece(
    Canvas canvas,
    Offset center,
    int piece,
    double cell, {
    double scale = 1,
    double opacity = 1,
  }) {
    final sprite = _pieceSprite(piece, cell);
    final box = cell * 0.43 * 2.6;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (scale != 1) canvas.scale(scale);
    canvas.translate(-box / 2, -box / 2);
    if (opacity < 0.999) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, box, box),
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
      canvas.drawPicture(sprite);
      canvas.restore();
    } else {
      canvas.drawPicture(sprite);
    }
    canvas.restore();
  }

  /// 单枚棋子录成小图，落子动画期间只做平移缩放，避免逐帧重建渐变与文字。
  ui.Picture _pieceSprite(int piece, double cell) {
    final cached = _sprites[piece];
    if (cached != null) return cached;
    final radius = cell * 0.43;
    final box = radius * 2.6;
    final face = _skin.faceOf(sideOf(piece));
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paintPieceDisc(
      canvas,
      center: Offset(box / 2, box / 2),
      radius: radius,
      face: face,
      label: _piecePainter(piece, cell, face.ink),
      borderWidth: cell * 0.045,
      innerRingWidth: cell * 0.013,
    );
    final sprite = recorder.endRecording();
    _sprites[piece] = sprite;
    return sprite;
  }

  TextPainter _piecePainter(int piece, double cell, Color color) {
    final cached = _piecePainters[piece];
    if (cached != null) return cached;
    final painter = pieceLabelPainter(
      pieceName(piece),
      fontSize: cell * 0.5,
      fontWeight: FontWeight.w600,
      color: color,
    );
    _piecePainters[piece] = painter;
    return painter;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style, {
    required String key,
  }) {
    var painter = _textPainters[key];
    if (painter == null) {
      painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      _textPainters[key] = painter;
    }
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_cell <= 0) return;
    final local = event.localPosition;
    final col = ((local.x - _cell * 0.5) / _cell).round();
    final row = ((local.y - _cell * 0.5) / _cell).round();
    if (row < 0 || row >= boardRows || col < 0 || col >= boardCols) return;
    final center = Offset((col + 0.5) * _cell, (row + 0.5) * _cell);
    if ((local.x - center.dx).abs() > _cell * 0.55 ||
        (local.y - center.dy).abs() > _cell * 0.55) {
      return;
    }
    final before = view.history.length;
    final selectedBefore = view.selected;
    view.tapCell(indexOf(row, col));
    // 落子反馈由对局页按吃子/将军统一播放，棋盘只负责选子的轻触感。
    if (view.history.length == before && view.selected != selectedBefore) {
      SoundService.tap();
    }
  }
}

class _MoveAnim {
  _MoveAnim({
    required this.from,
    required this.to,
    required this.piece,
    required this.captured,
  }) : powder = captured == 0 ? const [] : _buildPowder(from, to, captured);

  final int from;
  final int to;
  final int piece;
  final int captured;
  final List<_Powder> powder;
  double elapsed = 0;

  double get totalDuration =>
      _moveDurationSeconds +
      (captured == 0 ? _landingDurationSeconds : _shatterDurationSeconds);

  /// 棋子从起点到落点的进度。
  double get travel => (elapsed / _moveDurationSeconds).clamp(0.0, 1.0);

  bool get landed => elapsed >= _moveDurationSeconds;

  /// 落点涟漪进度。
  double get landing =>
      ((elapsed - _moveDurationSeconds) / _landingDurationSeconds).clamp(
        0.0,
        1.0,
      );

  /// 粉末飞散进度。
  double get shatter =>
      ((elapsed - _moveDurationSeconds) / _shatterDurationSeconds).clamp(
        0.0,
        1.0,
      );
}

class _Powder {
  const _Powder({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
    required this.shade,
  });

  final double angle;
  final double distance;
  final double size;
  final double delay;
  final int shade;
}

/// 以着法坐标作种子，同一手棋的粉末每次播放保持一致。
List<_Powder> _buildPowder(int from, int to, int captured) {
  final random = math.Random((from + 1) * 7919 + (to + 1) * 104729 + captured);
  return List.generate(20, (_) {
    return _Powder(
      angle: random.nextDouble() * math.pi * 2,
      distance: 0.32 + random.nextDouble() * 0.95,
      size: 0.012 + random.nextDouble() * 0.022,
      delay: random.nextDouble() * 0.18,
      shade: random.nextInt(3),
    );
  });
}
