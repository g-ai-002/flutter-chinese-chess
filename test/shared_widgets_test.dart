import 'package:chinese_chess/flame/xiangqi_game.dart';
import 'package:chinese_chess/game/board_state.dart';
import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/replay_controller.dart';
import 'package:chinese_chess/models/move_record.dart';
import 'package:chinese_chess/pages/widgets/board_stage.dart';
import 'package:chinese_chess/pages/widgets/entry_tile.dart';
import 'package:chinese_chess/pages/widgets/move_panel.dart';
import 'package:chinese_chess/pages/widgets/play_layout.dart';
import 'package:chinese_chess/pages/widgets/status_chip.dart';
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

  group('棋盘尺寸', () {
    test('按 9:10 宽高比取可用空间', () {
      expect(boardFitSize(const Size(1200, 600)), const Size(540, 600));
    });

    test('宽度受限时按宽度换算高度', () {
      final size = boardFitSize(const Size(300, 900));
      expect(size.width, 300);
      expect(size.height, closeTo(300 * 10 / 9, 0.001));
    });

    test('超大窗口下宽度封顶', () {
      final size = boardFitSize(const Size(4000, 4000));
      expect(size.width, kBoardMaxWidth);
      expect(size.height, closeTo(kBoardMaxWidth * 10 / 9, 0.001));
    });

    test('可用空间为空时返回零尺寸', () {
      expect(boardFitSize(Size.zero), Size.zero);
      expect(boardFitSize(const Size(320, 0)), Size.zero);
    });
  });

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

  group('入口卡片', () {
    testWidgets('展示标题、副标题与标签并可点击', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            child: EntryTile(
              leading: const EntryBadge(
                icon: Icons.flag_outlined,
                accent: appRed,
              ),
              title: '残局挑战',
              subtitle: '八道杀法练习 · 限步取胜',
              trailing: const Text('红先 · 1 步杀'),
              onTap: () => tapped++,
            ),
          ),
        ),
      );

      expect(find.text('残局挑战'), findsOneWidget);
      expect(find.text('八道杀法练习 · 限步取胜'), findsOneWidget);
      expect(find.text('红先 · 1 步杀'), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);

      await tester.tap(find.text('残局挑战'));
      expect(tapped, 1);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('徽章可显示序号', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Center(
            child: EntryBadge(label: '3', accent: appRed),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
      expect(tester.getSize(find.byType(EntryBadge)), const Size(46, 46));

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('对局布局', () {
    Future<void> pumpLayout(WidgetTester tester, double width) {
      return tester.pumpWidget(
        _wrap(
          SizedBox(
            width: width,
            height: 500,
            child: const PlayLayout(
              board: ColoredBox(color: Colors.transparent),
              sidePanel: Text('棋谱栏'),
              status: Text('状态区'),
              actions: Text('宽屏操作'),
              compactBottom: Text('窄屏底部'),
            ),
          ),
        ),
      );
    }

    testWidgets('宽屏为棋盘加右侧棋谱栏', (tester) async {
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpLayout(tester, 1000);

      expect(find.text('状态区'), findsOneWidget);
      expect(find.text('宽屏操作'), findsOneWidget);
      expect(find.text('棋谱栏'), findsOneWidget);
      expect(find.text('窄屏底部'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('窄屏为上下堆叠并使用底部区域', (tester) async {
      tester.view.physicalSize = const Size(500, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpLayout(tester, 500);

      expect(find.text('状态区'), findsOneWidget);
      expect(find.text('窄屏底部'), findsOneWidget);
      expect(find.text('宽屏操作'), findsNothing);
      expect(find.text('棋谱栏'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('状态胶囊', () {
    Color chipColor(WidgetTester tester) {
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(StatusChip),
          matching: find.byType(Container),
        ),
      );
      return (box.decoration! as BoxDecoration).color!;
    }

    testWidgets('淡底胶囊用强调色低透明度铺底', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Center(
            child: StatusChip(accent: appRed, child: Text('红方行棋')),
          ),
        ),
      );

      expect(find.text('红方行棋'), findsOneWidget);
      expect(chipColor(tester).a, closeTo(0.10, 0.01));

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('实心胶囊直接用强调色，非活跃时底色更淡', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Center(
            child: StatusChip(
              accent: appRed,
              filled: true,
              child: Text('将军'),
            ),
          ),
        ),
      );
      expect(find.text('将军'), findsOneWidget);
      expect(chipColor(tester), appRed);

      await tester.pumpWidget(
        _wrap(
          const Center(
            child: StatusChip(
              accent: appRed,
              active: false,
              child: Text('黑方行棋'),
            ),
          ),
        ),
      );
      expect(chipColor(tester).a, closeTo(0.04, 0.01));

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
