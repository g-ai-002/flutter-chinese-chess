import 'dart:ui' as ui;

import 'package:chinese_chess/flame/board_component.dart';
import 'package:chinese_chess/flame/xiangqi_game.dart';
import 'package:chinese_chess/game/board_state.dart';
import 'package:chinese_chess/game/board_view.dart';
import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/logic_rate.dart';
import 'package:chinese_chess/models/move_record.dart';
import 'package:chinese_chess/theme/board_skin.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeView extends ChangeNotifier implements BoardView {
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
  Duration moveLeadIn = Duration.zero;

  @override
  void tapCell(int index) => notifyListeners();

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

  void undo() {
    final record = history.removeLast();
    board.cells[record.from] = record.piece;
    board.cells[record.to] = record.captured;
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

  testWidgets('两手棋在一帧内落下时依次播放，不会被顶掉', (tester) async {
    final view = _FakeView();
    final board = _build(view);
    board.update(0.016);

    // 我方落子后 AI 立刻回棋：棋盘与历史在一帧内前进了两手。
    view.addMove(
      from: indexOf(6, 0),
      to: indexOf(5, 0),
      piece: pieceOf(red, typePawn),
    );
    view.addMove(
      from: indexOf(3, 0),
      to: indexOf(4, 0),
      piece: pieceOf(black, typePawn),
    );
    board.update(0.016);
    expect(board.isAnimating, isTrue);

    // 第一手播完后接着播第二手，而不是直接收场。
    board.update(0.62);
    expect(board.isAnimating, isTrue);
    _render(board);

    board.update(1.0);
    expect(board.isAnimating, isFalse);
    _render(board);
  });

  testWidgets('悔棋回退历史后立即回到静止图层', (tester) async {
    final view = _FakeView();
    final board = _build(view);
    board.update(0.016);

    view.addMove(
      from: indexOf(6, 0),
      to: indexOf(5, 0),
      piece: pieceOf(red, typePawn),
    );
    board.update(0.05);
    expect(board.isAnimating, isTrue);

    view.undo();
    board.update(0.016);
    expect(board.isAnimating, isFalse);
    _render(board);
  });

  testWidgets('逻辑刷新率决定动画推进步长', (tester) async {
    final view = _FakeView();
    final board = BoardComponent(
      view: view,
      skin: ValueNotifier(woodSkin),
      logicRate: LogicRate.hz30,
    )..size = Vector2(480, 540);

    view.addMove(
      from: indexOf(6, 0),
      to: indexOf(5, 0),
      piece: pieceOf(red, typePawn),
    );
    // 60fps 渲染下，30Hz 逻辑每两帧才推进一次；未满一步不开始动画。
    board.update(0.017);
    expect(board.isAnimating, isFalse);
    board.update(0.017);
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

  testWidgets('走子前的停顿会延后动画，光环只画在起点', (tester) async {
    final view = _FakeView()..moveLeadIn = const Duration(milliseconds: 320);
    final board = _build(view);
    board.update(0.016);

    view.addMove(
      from: indexOf(6, 0),
      to: indexOf(5, 0),
      piece: pieceOf(red, typePawn),
    );
    // 停顿期间棋子还没起走，整段动画的收尾也随之顺延。
    board.update(0.20);
    expect(board.isAnimating, isTrue);
    _render(board);
    board.update(0.50);
    expect(board.isAnimating, isTrue);
    _render(board);

    board.update(0.40);
    expect(board.isAnimating, isFalse);
    _render(board);
  });

  testWidgets('棋盘静止后停掉渲染循环，状态变化与将军立即唤醒', (tester) async {
    final view = _FakeView();
    final game = XiangqiGame(view: view, changes: view);
    game.onGameResize(Vector2(480, 540));
    await game.onLoad();

    game.update(0.5);
    expect(game.paused, isFalse);
    game.update(0.5);
    expect(game.paused, isTrue);

    view.tapCell(0);
    expect(game.paused, isFalse);

    game.update(1.0);
    expect(game.paused, isTrue);
    view.inCheck = true;
    view.tapCell(0);
    game.update(1.0);
    expect(game.paused, isFalse);
    game.onDispose();
    view.dispose();
  });
}
