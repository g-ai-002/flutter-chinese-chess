import 'package:flutter/material.dart';

import '../../game/engine/board_utils.dart';
import '../../theme/board_painting.dart';
import '../../theme/board_skin.dart';

/// 首页装饰：一张缩小的棋盘，红黑双方各立一子，配色跟随当前皮肤。
class BoardPreview extends StatelessWidget {
  const BoardPreview({super.key, this.skin = kDefaultBoardSkin});

  final BoardSkin skin;

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
        painter: _BoardPreviewPainter(skin: skin),
      ),
    );
  }
}

class _BoardPreviewPainter extends CustomPainter {
  const _BoardPreviewPainter({required this.skin});

  final BoardSkin skin;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(rrect, Paint()..shader = skin.gradient.createShader(rect));

    const pad = 16.0;
    final cell = (size.width - pad * 2) / (boardCols - 1);
    final top = (size.height - cell * (boardRows - 1)) / 2;

    final linePaint = Paint()
      ..color = skin.line.withValues(alpha: 0.55)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    paintBoardGrid(
      canvas,
      topLeft: Offset(pad, top),
      cell: cell,
      linePaint: linePaint,
      borderPaint: Paint()
        ..color = skin.line.withValues(alpha: 0.55)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );

    _drawPiece(
      canvas,
      Offset(pad + cell * 4, top + cell * 9),
      '帅',
      skin.redFace,
      cell,
    );
    _drawPiece(canvas, Offset(pad + cell * 4, top), '将', skin.blackFace, cell);
  }

  void _drawPiece(
    Canvas canvas,
    Offset center,
    String text,
    PieceFace face,
    double cell,
  ) {
    paintPieceDisc(
      canvas,
      center: center,
      radius: cell * 0.52,
      face: face,
      label: pieceLabelPainter(text, fontSize: cell * 0.72, color: face.ink),
    );
  }

  @override
  bool shouldRepaint(covariant _BoardPreviewPainter oldDelegate) =>
      oldDelegate.skin != skin;
}
