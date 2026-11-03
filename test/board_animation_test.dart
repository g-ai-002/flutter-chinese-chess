import 'dart:ui' as ui;

import 'package:chinese_chess/flame/board_component.dart';
import 'package:chinese_chess/game/board_state.dart';
import 'package:chinese_chess/game/board_view.dart';
import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/models/move_record.dart';
import 'package:chinese_chess/theme/board_skin.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeView implements BoardView {
  @override
  final XiangqiBoard board = XiangqiBoard.initial();

  @override
  final List<MoveRecord> history = [];

  @override
  int? selected;

  @override
  List<int> legalTargets = const [];

  @override
  bool showHints = true;

  @override
  bool inCheck = false;

  @override
  int? hintFrom;

  @override
  int? hintTo;

  @override
  void tapCell(int index) {}

  void addMove({
    required int from,
    required int to,
    required int piece,
    int captured = 0,
  }) {
    board.cells[to] = piece;
    board.cells[from] = 0;
    history.add(
      MoveRecord(
        from: from,
        to: to,
        piece: piece,
        captured: captured,
        notation: '测试',
        givesCheck: false,
        noCaptureBefore: 0,
      ),
    );
  }
}

BoardComponent _build(_FakeView view) =>
    BoardComponent(view: view, skin: ValueNotifier(woodSkin))
      ..size = Vector2(480, 540);

void _render(BoardComponent board) {
  final recorder = ui.PictureRecorder();
  board.render(ui.Canvas(recorder));
  recorder.endRecording().dispose();
}

void main() {
  testWidgets('移动与吃子会进入动画，结束后回到静止图层', (tester) async {
    final view = _FakeView();
    final board = _build(view);
    board.update(0.016);
    expect(board.isAnimating, isFalse);

    view.addMove(
      from: indexOf(6, 0),
      to: indexOf(5, 0),
      piece: pieceOf(red, typePawn),
    );
    board.update(0.08);
    expect(board.isAnimating, isTrue);
    _render(board);
    board.update(1.0);
    expect(board.isAnimating, isFalse);

    view.addMove(
      from: indexOf(6, 8),
      to: indexOf(3, 8),
      piece: pieceOf(red, typePawn),
      captured: pieceOf(black, typePawn),
    );
    board.update(0.30);
    expect(board.isAnimating, isTrue);
    _render(board);
    board.update(1.0);
    expect(board.isAnimating, isFalse);
  });

  testWidgets('走子提示箭头可以在棋盘上绘制', (tester) async {
    final view = _FakeView()
      ..hintFrom = indexOf(7, 1)
      ..hintTo = indexOf(7, 4);
    final board = _build(view);
    board.update(0.016);

    _render(board);
  });
}
