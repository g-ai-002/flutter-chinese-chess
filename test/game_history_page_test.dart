import 'package:chinese_chess/game/board_state.dart';
import 'package:chinese_chess/game/engine/rules.dart';
import 'package:chinese_chess/game/notation.dart';
import 'package:chinese_chess/models/saved_game.dart';
import 'package:chinese_chess/pages/game_history_page.dart';
import 'package:chinese_chess/providers/settings_provider.dart';
import 'package:chinese_chess/services/game_history_service.dart';
import 'package:chinese_chess/services/storage_service.dart';
import 'package:chinese_chess/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedGame _game({String id = 'game_1', String title = '人机对战 · 普通'}) {
  final board = XiangqiBoard.initial();
  for (final notation in ['炮二平五', '马8进7', '马二进三', '马2进3']) {
    final move = MoveNotation.findMove(board.cells, board.sideToMove, notation);
    board.applyMove(moveFrom(move!), moveTo(move));
  }
  return SavedGame(
    id: id,
    title: title,
    endedAt: DateTime(2026, 11, 4, 20, 30),
    layout: board.startLayout,
    startSide: board.startSide,
    moves: board.history,
    result: '红方胜（绝杀）',
  );
}

Future<SettingsProvider> _newSettings() async {
  SharedPreferences.setMockInitialValues({});
  StorageService.resetForTests();
  return SettingsProvider(await StorageService.instance);
}

Widget _wrap(SettingsProvider settings) => ChangeNotifierProvider.value(
  value: settings,
  child: MaterialApp(
    theme: buildLightTheme(),
    home: const GameHistoryPage(),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    GameHistoryService.instance.resetForTest();
  });

  testWidgets('空棋谱库展示导入入口', (tester) async {
    await tester.pumpWidget(_wrap(await _newSettings()));
    await tester.pump();

    expect(find.text('棋谱'), findsOneWidget);
    expect(find.text('还没有棋谱'), findsOneWidget);
    expect(find.textContaining('最近 20 局'), findsOneWidget);
    expect(find.byTooltip('导入棋谱'), findsOneWidget);
  });

  testWidgets('棋谱库列出最近对局并可进入复盘', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = await _newSettings();
    await GameHistoryService.instance.record(_game());

    await tester.pumpWidget(_wrap(settings));
    await tester.pump();

    expect(find.text('人机对战 · 普通'), findsOneWidget);
    expect(find.textContaining('4 手'), findsOneWidget);
    expect(find.text('红方胜（绝杀）'), findsOneWidget);

    await tester.tap(find.text('人机对战 · 普通'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('复盘'), findsOneWidget);
    expect(find.text('第 0 / 4 手'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('删除单局棋谱后回到空状态', (tester) async {
    final settings = await _newSettings();
    await GameHistoryService.instance.record(_game());

    await tester.pumpWidget(_wrap(settings));
    await tester.pump();

    await tester.tap(find.byTooltip('删除棋谱'));
    await tester.pumpAndSettle();
    expect(find.text('删除这局棋谱？'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(GameHistoryService.instance.records, isEmpty);
    expect(find.text('还没有棋谱'), findsOneWidget);
  });

  testWidgets('导入棋谱后写入棋谱库并进入复盘', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(await _newSettings()));
    await tester.pump();

    await tester.tap(find.byTooltip('导入棋谱'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      '1. 炮二平五 马8进7\n2. 马二进三 马2进3',
    );
    await tester.tap(find.text('开始复盘'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('复盘'), findsOneWidget);
    expect(find.text('第 0 / 4 手'), findsOneWidget);
    expect(GameHistoryService.instance.records, hasLength(1));
    expect(GameHistoryService.instance.records.single.moveCount, 4);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('无法解析的棋谱给出提示', (tester) async {
    await tester.pumpWidget(_wrap(await _newSettings()));
    await tester.pump();

    await tester.tap(find.byTooltip('导入棋谱'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '这不是棋谱');
    await tester.tap(find.text('开始复盘'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('棋谱无法解析，请检查文本是否完整'), findsOneWidget);
    expect(GameHistoryService.instance.records, isEmpty);
  });
}
