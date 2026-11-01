import 'package:chinese_chess/game/ai_player.dart';
import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/game_controller.dart';
import 'package:chinese_chess/game/match_clock.dart';
import 'package:chinese_chess/game/puzzles.dart';
import 'package:chinese_chess/models/game_models.dart';
import 'package:chinese_chess/pages/game_page.dart';
import 'package:chinese_chess/pages/widgets/clock_bar.dart';
import 'package:chinese_chess/providers/settings_provider.dart';
import 'package:chinese_chess/services/storage_service.dart';
import 'package:chinese_chess/theme/app_theme.dart';
import 'package:chinese_chess/utils/constants.dart';
import 'package:chinese_chess/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

AiMoveProvider idleAi() =>
    (cells, side, difficulty) async =>
        const AiReply(move: -1, score: 0, nodes: 0, depth: 0);

GameController timedController({
  GameMode mode = GameMode.twoPlayers,
  TimeControl timeControl = TimeControl.blitz,
}) => GameController(
  mode: mode,
  difficulty: Difficulty.entry,
  humanSide: red,
  timeControl: timeControl,
  aiMove: idleAi(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MatchClock', () {
    test('只扣当前行棋方的时间', () {
      final clock = MatchClock(TimeControl.blitz);
      expect(clock.remainingMs(red), 300000);
      // 未开始时不计时。
      expect(clock.charge(const Duration(seconds: 5)), isNull);
      expect(clock.remainingMs(red), 300000);

      clock.start(red);
      expect(clock.charge(const Duration(seconds: 100)), isNull);
      expect(clock.remainingMs(red), 200000);
      expect(clock.remainingMs(black), 300000);

      clock.start(black);
      expect(clock.charge(const Duration(seconds: 60)), isNull);
      expect(clock.remainingMs(black), 240000);
      expect(clock.remainingMs(red), 200000);
    });

    test('扣光即超时并停表', () {
      final clock = MatchClock(TimeControl.blitz)..start(black);
      expect(clock.charge(const Duration(minutes: 5)), black);
      expect(clock.remainingMs(black), 0);
      expect(clock.isRunning, isFalse);
      // 停表后不再产生第二个超时方。
      expect(clock.charge(const Duration(seconds: 1)), isNull);
    });

    test('快照可还原双方时间与行棋方', () {
      final clock = MatchClock(TimeControl.rapid)..start(red);
      clock.charge(const Duration(seconds: 90));
      final mark = clock.snapshot();
      clock.start(black);
      clock.charge(const Duration(seconds: 30));

      clock.restore(mark, side: red);
      expect(clock.remainingMs(red), 510000);
      expect(clock.remainingMs(black), 600000);
      expect(clock.activeSide, red);

      clock.reset();
      expect(clock.remainingMs(red), 600000);
      expect(clock.remainingMs(black), 600000);
      expect(clock.isRunning, isFalse);
    });
  });

  group('棋钟格式', () {
    test('剩余时间显示为分秒，满一小时带上小时', () {
      expect(formatClock(300000), '05:00');
      expect(formatClock(61000), '01:01');
      expect(formatClock(1000), '00:01');
      expect(formatClock(0), '00:00');
      expect(formatClock(3723000), '1:02:03');
    });
  });

  group('对局棋钟', () {
    test('超时判负并停止交互', () {
      final controller = timedController()..start();
      expect(controller.clock, isNotNull);

      controller.tickClock(const Duration(minutes: 4));
      expect(controller.result, isNull);
      expect(controller.clock!.remainingMs(red), closeTo(60000, 50));

      controller.tickClock(const Duration(minutes: 1));
      final result = controller.result;
      expect(result, isNotNull);
      expect(result!.winner, black);
      expect(result.reason, '超时');
      expect(controller.canInteractive, isFalse);

      // 终局后不再扣时。
      controller.tickClock(const Duration(minutes: 1));
      expect(controller.clock!.remainingMs(red), 0);
      controller.dispose();
    });

    test('落子后棋钟交给对方', () {
      final controller = timedController()..start();
      controller.tickClock(const Duration(seconds: 30));

      controller.tapCell(indexOf(9, 0));
      controller.tapCell(indexOf(8, 0));

      expect(controller.history.length, 1);
      expect(controller.clock!.activeSide, black);
      expect(controller.clock!.remainingMs(black), closeTo(300000, 50));
      expect(controller.clock!.remainingMs(red), closeTo(270000, 50));
      controller.dispose();
    });

    test('悔棋恢复落子前的棋钟', () {
      final controller = timedController(timeControl: TimeControl.rapid)
        ..start();
      controller.tickClock(const Duration(seconds: 40));

      controller.tapCell(indexOf(9, 0));
      controller.tapCell(indexOf(8, 0));
      controller.tickClock(const Duration(seconds: 70));
      expect(controller.clock!.remainingMs(black), closeTo(530000, 50));

      controller.undo();
      expect(controller.history, isEmpty);
      expect(controller.clock!.remainingMs(red), closeTo(560000, 50));
      expect(controller.clock!.remainingMs(black), closeTo(600000, 50));
      expect(controller.clock!.activeSide, red);
      controller.dispose();
    });

    test('重开清零棋钟', () {
      final controller = timedController()..start();
      controller.tickClock(const Duration(minutes: 2));
      expect(controller.clock!.remainingMs(red), closeTo(180000, 50));

      controller.restart();
      expect(controller.clock!.remainingMs(red), 300000);
      expect(controller.clock!.remainingMs(black), 300000);
      expect(controller.clock!.activeSide, red);
      controller.dispose();
    });

    test('不限时与残局不启用棋钟', () {
      final free = timedController(timeControl: TimeControl.none)..start();
      expect(free.clock, isNull);
      free.tickClock(const Duration(minutes: 10));
      expect(free.result, isNull);
      free.dispose();

      final puzzle = GameController(
        mode: GameMode.puzzle,
        difficulty: Difficulty.entry,
        humanSide: kPuzzleHumanSide,
        timeControl: TimeControl.blitz,
        puzzle: kPuzzles.first,
        aiMove: idleAi(),
      )..start();
      expect(puzzle.timeControl, TimeControl.none);
      expect(puzzle.clock, isNull);
      puzzle.dispose();
    });
  });

  group('棋钟偏好', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      StorageService.resetForTests();
    });

    test('默认不限时并可持久化', () async {
      final storage = await StorageService.instance;
      final settings = SettingsProvider(storage);
      expect(settings.timeControl, TimeControl.none);

      await settings.setTimeControl(TimeControl.rapid);
      expect(storage.timeControl, TimeControl.rapid);

      SharedPreferences.setMockInitialValues({'time_control': 'unknown'});
      StorageService.resetForTests();
      final restored = await StorageService.instance;
      expect(restored.timeControl, TimeControl.none);
    });

    testWidgets('对局页展示双方棋钟与时间方案', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        AppConstants.prefKeyTimeControl: TimeControl.blitz.name,
      });
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
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.byType(ClockBar), findsOneWidget);
      expect(find.text('05:00'), findsNWidgets(2));
      expect(find.textContaining('5 分钟'), findsOneWidget);

      final bar = tester.widget<ClockBar>(find.byType(ClockBar));
      bar.controller.tickClock(const Duration(minutes: 3));
      await tester.pump(const Duration(milliseconds: 260));
      expect(find.text('02:00'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
