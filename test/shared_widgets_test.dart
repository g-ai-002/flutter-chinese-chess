import 'package:chinese_chess/flame/xiangqi_game.dart';
import 'package:chinese_chess/game/board_state.dart';
import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/replay_controller.dart';
import 'package:chinese_chess/models/move_record.dart';
import 'package:chinese_chess/pages/widgets/board_stage.dart';
import 'package:chinese_chess/pages/widgets/move_panel.dart';
import 'package:chinese_chess/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MoveRecord _move(String notation, {int from = 0, int to = 0}) => MoveRecord(
  from: from,
  to: to,
  piece: pieceOf(red, typeCannon),
  captured: 0,
  notation: notation,
  givesCheck: false,
  noCaptureBefore: 0,
);

ReplayController _emptyReplay() => ReplayController(
  moves: const [],
  layout: XiangqiBoard.initial().startLayout,
);

Widget _wrap(Widget child) => MaterialApp(
  theme: buildLightTheme(),
  home: Scaffold(body: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('棋盘舞台', () {
    testWidgets('按 9:10 宽高比取可用空间', (tester) async {
      final replay = _emptyReplay();
      final game = XiangqiGame(view: replay);
      addTearDown(replay.dispose);

      await tester.pumpWidget(
        _wrap(
          Center(
            child: SizedBox(
              width: 800,
              height: 600,
              child: BoardStage(
                game: game,
                gameKey: const ValueKey('stage-board'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byKey(const ValueKey('stage-board'))),
        const Size(540, 600),
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('宽度受限时不超出可用宽度', (tester) async {
      final replay = _emptyReplay();
      final game = XiangqiGame(view: replay);
      addTearDown(replay.dispose);

      await tester.pumpWidget(
        _wrap(
          Center(
            child: SizedBox(
              width: 300,
              height: 900,
              child: BoardStage(
                game: game,
                gameKey: const ValueKey('stage-board'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final size = tester.getSize(find.byKey(const ValueKey('stage-board')));
      expect(size.width, 300);
      expect(size.height, closeTo(300 * 10 / 9, 0.01));

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('棋谱侧栏', () {
    testWidgets('展示手数、棋谱与底部说明', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 292,
            height: 420,
            child: MovePanel(
              history: [
                MoveRecord(
                  from: 0,
                  to: 0,
                  piece: 6,
                  captured: 0,
                  notation: '炮二平五',
                  givesCheck: false,
                  noCaptureBefore: 0,
                ),
                MoveRecord(
                  from: 0,
                  to: 0,
                  piece: 6,
                  captured: 0,
                  notation: '马8进7',
                  givesCheck: false,
                  noCaptureBefore: 1,
                ),
              ],
              footer: '共 2 手 · 点击棋谱可跳转',
            ),
          ),
        ),
      );

      expect(find.text('棋谱'), findsOneWidget);
      expect(find.text('2 手'), findsOneWidget);
      expect(find.text('炮二平五'), findsOneWidget);
      expect(find.text('马8进7'), findsOneWidget);
      expect(find.text('共 2 手 · 点击棋谱可跳转'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('点击棋谱条目回传下标', (tester) async {
      int? tapped;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 292,
            height: 420,
            child: MovePanel(
              history: [_move('炮二平五'), _move('马8进7')],
              footer: '复盘',
              highlightIndex: 0,
              onTapIndex: (index) => tapped = index,
            ),
          ),
        ),
      );

      await tester.tap(find.text('马8进7'));
      expect(tapped, 1);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
