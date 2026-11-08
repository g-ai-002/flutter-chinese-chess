import 'package:chinese_chess/game/game_statistics.dart';
import 'package:chinese_chess/models/game_models.dart';
import 'package:chinese_chess/pages/game_page.dart';
import 'package:chinese_chess/pages/home_page.dart';
import 'package:chinese_chess/providers/settings_provider.dart';
import 'package:chinese_chess/services/storage_service.dart';
import 'package:chinese_chess/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home, SettingsProvider settings) =>
    ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(theme: buildLightTheme(), home: home),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  group('战绩统计', () {
    test('默认全零，胜率按总场次计算', () {
      const stats = GameStatistics();
      expect(stats.total, 0);
      expect(stats.winRate, 0);
      expect(stats.summary, '人机战绩 · 首局待战');
    });

    test('胜局累计连胜，和棋与败局清零但保留最佳连胜', () {
      var stats = const GameStatistics();
      stats = stats.record(true).record(true).record(true);
      expect(stats.wins, 3);
      expect(stats.streak, 3);
      expect(stats.bestStreak, 3);

      stats = stats.record(null);
      expect(stats.draws, 1);
      expect(stats.streak, 0);
      expect(stats.bestStreak, 3);
      expect(stats.total, 4);
      expect(stats.winRate, 75);

      stats = stats.record(false).record(true);
      expect(stats.losses, 1);
      expect(stats.streak, 1);
      expect(stats.bestStreak, 3);
    });

    test('写入本地存储后可以读回', () async {
      final storage = await StorageService.instance;
      expect(storage.gameStatistics.total, 0);

      await storage.recordHumanResult(true);
      await storage.recordHumanResult(null);
      await storage.recordHumanResult(false);

      final stats = (await StorageService.instance).gameStatistics;
      expect(stats.wins, 1);
      expect(stats.draws, 1);
      expect(stats.losses, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('stats_wins'), 1);
      expect(prefs.getInt('stats_best_streak'), 1);
    });
  });

  testWidgets('首页展示人机战绩', (tester) async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await settings.recordHumanResult(true);
    await settings.recordHumanResult(false);
    await settings.recordHumanResult(null);

    await tester.pumpWidget(_app(const HomePage(), settings));
    await tester.pump();

    expect(find.textContaining('人机战绩 · 1 胜 1 负 1 和'), findsOneWidget);
    expect(find.textContaining('胜率 33%'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('人机对局认输后写入一场败局', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(
      _app(
        const GamePage(
          mode: GameMode.vsAi,
          difficulty: Difficulty.entry,
          humanSide: 0,
        ),
        settings,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('认输'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '认输'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(settings.statistics.losses, 1);
    expect(settings.statistics.total, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
