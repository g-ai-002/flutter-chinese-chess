import 'package:chinese_chess/flame/xiangqi_game.dart';
import 'package:chinese_chess/game/ai_player.dart';
import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/engine/rules.dart';
import 'package:chinese_chess/game/game_controller.dart';
import 'package:chinese_chess/models/game_models.dart';
import 'package:chinese_chess/pages/game_page.dart';
import 'package:chinese_chess/pages/widgets/game_dialogs.dart';
import 'package:chinese_chess/pages/widgets/game_status_bar.dart';
import 'package:chinese_chess/providers/settings_provider.dart';
import 'package:chinese_chess/services/game_history_service.dart';
import 'package:chinese_chess/services/storage_service.dart';
import 'package:chinese_chess/theme/app_theme.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    GameHistoryService.instance.resetForTest();
  });

  testWidgets('双人对局页展示行棋方与操作按钮', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const GamePage(
            mode: GameMode.twoPlayers,
            difficulty: Difficulty.entry,
            humanSide: 0,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('红方行棋'), findsOneWidget);
    expect(find.text('悔棋'), findsOneWidget);
    expect(find.text('重开'), findsOneWidget);
    expect(find.text('棋谱'), findsOneWidget);
    expect(find.text('尚未落子'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('人机对局页展示认输按钮与执子信息', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const GamePage(
            mode: GameMode.vsAi,
            difficulty: Difficulty.entry,
            humanSide: 0,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('你执红'), findsOneWidget);
    expect(find.text('认输'), findsOneWidget);
    expect(find.text('提示'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('点击棋盘可以完成一次落子并记入棋谱', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const GamePage(
            mode: GameMode.twoPlayers,
            difficulty: Difficulty.entry,
            humanSide: 0,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final board = find.byKey(const ValueKey('xiangqi-board'));
    expect(board, findsOneWidget);
    final rect = tester.getRect(board);
    final cell = rect.width / 9;
    Offset center(int row, int col) =>
        rect.topLeft + Offset((col + 0.5) * cell, (row + 0.5) * cell);

    await tester.tapAt(center(6, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center(5, 0));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('兵九进一'), findsOneWidget);
    expect(find.text('黑方行棋'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('对局页展示当前开局与推荐着法', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const GamePage(
            mode: GameMode.twoPlayers,
            difficulty: Difficulty.entry,
            humanSide: 0,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('开局 · 中炮'), findsOneWidget);
    expect(find.text('试走 炮二平五'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('开局提示变化不影响棋盘位置', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const GamePage(
            mode: GameMode.twoPlayers,
            difficulty: Difficulty.entry,
            humanSide: 0,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final board = find.byKey(const ValueKey('xiangqi-board'));
    final before = tester.getRect(board);
    final cell = before.width / 9;
    Offset center(int row, int col) =>
        before.topLeft + Offset((col + 0.5) * cell, (row + 0.5) * cell);

    await tester.tapAt(center(7, 7));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center(7, 4));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('炮二平五'), findsOneWidget);
    expect(tester.getRect(board), before);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('关闭设置后不再显示开局提示', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'show_opening_hints': false});
    StorageService.resetForTests();
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const GamePage(
            mode: GameMode.twoPlayers,
            difficulty: Difficulty.entry,
            humanSide: 0,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('开局 · 中炮'), findsNothing);
    expect(find.text('试走 炮二平五'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('对局棋盘跟随设置中的皮肤', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const GamePage(
            mode: GameMode.twoPlayers,
            difficulty: Difficulty.entry,
            humanSide: 0,
          ),
        ),
      ),
    );
    await tester.pump();

    XiangqiGame game() => tester
        .widget<GameWidget<XiangqiGame>>(
          find.byKey(const ValueKey('xiangqi-board')),
        )
        .game!;

    expect(game().skin.id, 'wood');

    await settings.setBoardSkin(jadeSkin);
    await tester.pump();
    expect(game().skin.id, 'jade');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('状态条在对局空闲时展示 AI 引擎信息', (tester) async {
    final controller = GameController(
      mode: GameMode.vsAi,
      difficulty: Difficulty.entry,
      humanSide: red,
      aiMove: (cells, side, difficulty) async => AiReply(
        move: encodeMove(indexOf(3, 0), indexOf(4, 0)),
        score: 35,
        nodes: 2048,
        depth: 3,
      ),
    );
    controller.start();
    controller.tapCell(indexOf(9, 0));
    controller.tapCell(indexOf(8, 0));
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: GameStatusBar(controller: controller, humanSide: red),
        ),
      ),
    );

    expect(find.textContaining('AI 第 3 层'), findsOneWidget);
    expect(find.byTooltip('节点 2048 · 评分 35'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('窄屏下状态条不溢出', (tester) async {
    final controller = GameController(
      mode: GameMode.vsAi,
      difficulty: Difficulty.entry,
      humanSide: black,
      aiMove: (cells, side, difficulty) async => AiReply(
        move: encodeMove(indexOf(3, 0), indexOf(4, 0)),
        score: 35,
        nodes: 2048000,
        depth: 5,
      ),
    );
    controller.start();
    controller.tapCell(indexOf(0, 0));
    controller.tapCell(indexOf(1, 0));
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: GameStatusBar(controller: controller, humanSide: black),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('红方行棋'), findsNothing);
    expect(find.textContaining('AI 第 5 层'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('终局后自动写入棋谱库', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const GamePage(
            mode: GameMode.vsAi,
            difficulty: Difficulty.entry,
            humanSide: red,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final board = find.byKey(const ValueKey('xiangqi-board'));
    final rect = tester.getRect(board);
    final cell = rect.width / 9;
    Offset center(int row, int col) =>
        rect.topLeft + Offset((col + 0.5) * cell, (row + 0.5) * cell);

    await tester.tapAt(center(6, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center(5, 0));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('认输'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, '认输'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final records = GameHistoryService.instance.records;
    expect(records, hasLength(1));
    expect(records.single.result, contains('认输'));
    expect(records.single.moveCount, greaterThanOrEqualTo(1));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('终局弹窗提供复盘入口', (tester) async {
    var reviewRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showGameResultDialog(
                  context,
                  result: const GameResult(winner: 0, reason: '绝杀'),
                  moveCount: 12,
                  onRestart: () {},
                  onReview: () => reviewRequested = true,
                ),
                child: const Text('查看结果'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('查看结果'));
    await tester.pumpAndSettle();
    expect(find.text('复盘'), findsOneWidget);

    await tester.tap(find.text('复盘'));
    await tester.pumpAndSettle();
    expect(reviewRequested, isTrue);
  });
}
