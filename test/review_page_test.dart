import 'package:chinese_chess/flame/xiangqi_game.dart';
import 'package:chinese_chess/game/board_state.dart';
import 'package:chinese_chess/game/engine/rules.dart';
import 'package:chinese_chess/game/logic_rate.dart';
import 'package:chinese_chess/game/notation.dart';
import 'package:chinese_chess/models/move_record.dart';
import 'package:chinese_chess/pages/review_page.dart';
import 'package:chinese_chess/providers/settings_provider.dart';
import 'package:chinese_chess/services/storage_service.dart';
import 'package:chinese_chess/theme/app_theme.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<String> _opening = ['炮二平五', '马8进7', '马二进三', '马2进3'];

List<MoveRecord> _play(List<String> notations) {
  final board = XiangqiBoard.initial();
  for (final notation in notations) {
    final move = MoveNotation.findMove(board.cells, board.sideToMove, notation);
    board.applyMove(moveFrom(move!), moveTo(move));
  }
  return List.of(board.history);
}

Future<SettingsProvider> _newSettings() async {
  SharedPreferences.setMockInitialValues({});
  StorageService.resetForTests();
  return SettingsProvider(await StorageService.instance);
}

Widget _wrap(SettingsProvider settings, {String? result}) =>
    ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        theme: buildLightTheme(),
        home: ReviewPage(
          title: '人机对战 · 普通',
          result: result,
          moves: _play(_opening),
          layout: XiangqiBoard.initial().startLayout,
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('复盘页展示棋谱与逐步回放控制', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(await _newSettings()));
    await tester.pump();

    expect(find.text('复盘'), findsOneWidget);
    expect(find.text('人机对战 · 普通'), findsOneWidget);
    expect(find.text('第 0 / 4 手'), findsOneWidget);
    expect(find.text('4 手'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-board')), findsOneWidget);
    expect(find.text('炮二平五'), findsOneWidget);

    await tester.tap(find.byTooltip('下一步'));
    await tester.pump();
    expect(find.text('第 1 / 4 手'), findsOneWidget);

    await tester.tap(find.byTooltip('跳到终局'));
    await tester.pump();
    expect(find.text('第 4 / 4 手'), findsOneWidget);

    await tester.tap(find.byTooltip('回到开局'));
    await tester.pump();
    expect(find.text('第 0 / 4 手'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('点击棋谱条目可跳到对应手数', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(await _newSettings()));
    await tester.pump();

    await tester.tap(find.text('马8进7'));
    await tester.pump();
    expect(find.text('第 2 / 4 手'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('自动回放会逐步推进并在终局停下', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(await _newSettings()));
    await tester.pump();

    await tester.tap(find.byTooltip('自动回放'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 980));
    expect(find.text('第 1 / 4 手'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('第 4 / 4 手'), findsOneWidget);
    expect(find.byTooltip('自动回放'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('窄屏下复盘页不溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(await _newSettings(), result: '红方胜（绝杀）'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('第 0 / 4 手'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('复盘棋盘跟随设置中的皮肤与逻辑刷新率', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = await _newSettings();
    await settings.setBoardSkin(jadeSkin);
    await settings.setLogicRate(LogicRate.hz30);
    await tester.pumpWidget(_wrap(settings));
    await tester.pump();

    XiangqiGame game() => tester
        .widget<GameWidget<XiangqiGame>>(
          find.byKey(const ValueKey('review-board')),
        )
        .game!;

    expect(game().skin.id, 'jade');
    expect(game().logicRate, LogicRate.hz30);

    await settings.setBoardSkin(inkSkin);
    await tester.pump();
    expect(game().skin.id, 'ink');

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
