import 'package:flutter/material.dart';

import '../../game/engine/board_utils.dart';
import '../../theme/app_theme.dart';
import '../../theme/board_painting.dart';
import '../../utils/constants.dart';

/// 首页装饰：一张缩小的木纹棋盘，红黑双方各立一子。
class BoardPreview extends StatelessWidget {
  const BoardPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CustomPaint(
        size: const Size(158, 174),
        painter: _BoardPreviewPainter(
          lineColor: appWood,
          redFace: pieceFaceOf(red),
          blackFace: pieceFaceOf(black),
        ),
      ),
    );
  }
}

class _BoardPreviewPainter extends CustomPainter {
  const _BoardPreviewPainter({
    required this.lineColor,
    required this.redFace,
    required this.blackFace,
  });

  final Color lineColor;
  final PieceFace redFace;
  final PieceFace blackFace;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6E6C6), Color(0xFFE2C592)],
        ).createShader(rect),
    );

    const pad = 16.0;
    final cell = (size.width - pad * 2) / (boardCols - 1);
    final top = (size.height - cell * (boardRows - 1)) / 2;

    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.55)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    paintBoardGrid(
      canvas,
      topLeft: Offset(pad, top),
      cell: cell,
      linePaint: linePaint,
      borderPaint: Paint()
        ..color = lineColor.withValues(alpha: 0.55)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );

    _drawPiece(
      canvas,
      Offset(pad + cell * 4, top + cell * 9),
      '帅',
      redFace,
      cell,
    );
    _drawPiece(canvas, Offset(pad + cell * 4, top), '将', blackFace, cell);
  }

  void _drawPiece(
    Canvas canvas,
    Offset center,
    String text,
    PieceFace face,
    double cell,
  ) {
    final radius = cell * 0.52;
    canvas.drawCircle(
      center.translate(0, 1.5),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [face.light, face.dark],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius * 0.8,
      Paint()..color = face.dark.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = face.ink.withValues(alpha: 0.85),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: cell * 0.72,
          fontWeight: FontWeight.w700,
          color: face.ink,
          fontFamily: 'KaiTi',
          fontFamilyFallback: kKaiFontFallback,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BoardPreviewPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.redFace != redFace ||
      oldDelegate.blackFace != blackFace;
}
