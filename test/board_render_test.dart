import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:chinese_chess/flame/board_component.dart';
import 'package:chinese_chess/game/game_controller.dart';
import 'package:chinese_chess/models/game_models.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

const double _width = 480;
const double _height = 540;

Future<ByteData> _renderBoard() async {
  final controller = GameController(
    mode: GameMode.twoPlayers,
    difficulty: Difficulty.entry,
    humanSide: 0,
  );
  final board = BoardComponent(view: controller)
    ..size = Vector2(_width, _height);
  final recorder = ui.PictureRecorder();
  board.render(ui.Canvas(recorder));
  final image = await recorder.endRecording().toImage(
    _width.toInt(),
    _height.toInt(),
  );
  return (await image.toByteData())!;
}

/// 取棋子棋面上、文字右侧的像素，避开文字与描边。
({int r, int g, int b}) _facePixel(ByteData data, int row) {
  const cell = _width / 9;
  final centerY = (row + 0.5) * cell;
  const centerX = 4.5 * cell;
  final x = (centerX + cell * 0.43 * 0.75).round();
  final y = centerY.round();
  final offset = (y * _width.toInt() + x) * 4;
  return (
    r: data.getUint8(offset),
    g: data.getUint8(offset + 1),
    b: data.getUint8(offset + 2),
  );
}

void main() {
  testWidgets('棋盘渲染时红黑棋子棋面颜色明显不同', (tester) async {
    await tester.runAsync(() async {
      final pixels = await _renderBoard();
      // 第 9 行是红方九宫，第 0 行是黑方九宫。
      final redFace = _facePixel(pixels, 9);
      final blackFace = _facePixel(pixels, 0);

      final redWarmth = redFace.r - redFace.b;
      final blackWarmth = blackFace.r - blackFace.b;
      expect(
        redWarmth - blackWarmth,
        greaterThan(20),
        reason:
            '红方棋面应明显偏暖，黑方棋面偏中性，实际 '
            'red=$redFace black=$blackFace',
      );
    });
  });
}
