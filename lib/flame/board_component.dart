import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/engine/board_utils.dart';
import '../game/engine/rules.dart';
import '../game/board_view.dart';
import '../theme/app_theme.dart';
import '../theme/board_painting.dart';
import '../theme/board_skin.dart';
import '../utils/constants.dart';

const double _moveDurationSeconds = 0.17;

/// Flame 棋盘组件：绘制棋盘、棋子、走子提示与落子动画，并处理点击。
///
/// 皮肤通过 [skin] 监听，切换皮肤时清空文字缓存并按新配色重绘。
class BoardComponent extends PositionComponent with TapCallbacks {
  BoardComponent({required this.view, required this.skin});

  final BoardView view;
  final ValueListenable<BoardSkin> skin;

  BoardSkin get _skin => skin.value;

  double _cell = 0;
  double _time = 0;
  int _seenMoves = -1;
  _MoveAnim? _anim;
  double _cacheCell = 0;
  final Map<int, TextPainter> _piecePainters = {};
  final Map<String, TextPainter> _textPainters = {};

  @override
  Future<void> onLoad() async {
    skin.addListener(_clearTextCaches);
  }

  @override
  void onRemove() {
    skin.removeListener(_clearTextCaches);
    super.onRemove();
  }

  void _clearTextCaches() {
    _piecePainters.clear();
    _textPainters.clear();
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
      if (anim.elapsed >= _moveDurationSeconds) _anim = null;
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
    }

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    _drawBoard(canvas, cell);
    _drawHighlights(canvas, cell);
    _drawPieces(canvas, cell);
    canvas.restore();
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

    final riverStyle = TextStyle(
      fontSize: cell * 0.42,
      letterSpacing: cell * 0.16,
      fontWeight: FontWeight.w600,
      color: skin.line.withValues(alpha: 0.62),
      fontFamily: 'KaiTi',
      fontFamilyFallback: kKaiFontFallback,
      height: 1,
    );
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
            ..strokeWidth = cell * 0.045
            ..color = _skin.redInk.withValues(alpha: 0.35 + 0.35 * pulse)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.05),
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

  void _drawPieces(Canvas canvas, double cell) {
    final anim = _anim;
    for (var index = 0; index < cellCount; index++) {
      final piece = view.board.cells[index];
      if (piece == 0) continue;
      if (anim != null && index == anim.to) continue;
      _drawPiece(canvas, _center(index, cell), piece, cell);
    }

    if (anim == null) return;
    final progress = (anim.elapsed / _moveDurationSeconds).clamp(0.0, 1.0);
    final eased = progress * progress * (3 - 2 * progress);
    if (anim.captured != 0) {
      _drawPiece(
        canvas,
        _center(anim.to, cell),
        anim.captured,
        cell,
        opacity: 0.35,
      );
    }
    final from = _center(anim.from, cell);
    final to = _center(anim.to, cell);
    final position = Offset.lerp(from, to, eased)!;
    _drawPiece(
      canvas,
      position,
      anim.piece,
      cell,
      scale: 1 + 0.05 * math.sin(math.pi * progress),
    );
  }

  void _drawPiece(
    Canvas canvas,
    Offset center,
    int piece,
    double cell, {
    double scale = 1,
    double opacity = 1,
  }) {
    final face = _skin.faceOf(sideOf(piece));
    paintPieceDisc(
      canvas,
      center: center,
      radius: cell * 0.43 * scale,
      face: face,
      label: _piecePainter(piece, cell, face.ink, opacity),
      borderWidth: cell * 0.045,
      innerRingWidth: cell * 0.013,
      shadowBlur: cell * 0.05,
      opacity: opacity,
    );
  }

  TextPainter _piecePainter(
    int piece,
    double cell,
    Color color,
    double opacity,
  ) {
    final cached = _piecePainters[piece];
    if (cached != null && opacity >= 0.999) return cached;
    final painter = TextPainter(
      text: TextSpan(
        text: pieceName(piece),
        style: TextStyle(
          fontSize: cell * 0.5,
          fontWeight: FontWeight.w600,
          color: color.withValues(alpha: opacity),
          fontFamily: 'KaiTi',
          fontFamilyFallback: kKaiFontFallback,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    if (opacity >= 0.999) _piecePainters[piece] = painter;
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
    view.tapCell(indexOf(row, col));
    if (view.history.length > before) {
      HapticFeedback.selectionClick();
    }
  }
}

class _MoveAnim {
  _MoveAnim({
    required this.from,
    required this.to,
    required this.piece,
    required this.captured,
  });

  final int from;
  final int to;
  final int piece;
  final int captured;
  double elapsed = 0;
}
