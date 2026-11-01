import 'package:chinese_chess/game/puzzles.dart';
import 'package:chinese_chess/pages/puzzle_page.dart';
import 'package:chinese_chess/providers/settings_provider.dart';
import 'package:chinese_chess/services/storage_service.dart';
import 'package:chinese_chess/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget wrap(SettingsProvider settings) => ChangeNotifierProvider.value(
  value: settings,
  child: MaterialApp(theme: buildLightTheme(), home: const PuzzlePage()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  testWidgets('残局列表展示关卡与通关进度', (tester) async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    expect(find.text('残局挑战'), findsOneWidget);
    expect(find.text('闯关进度'), findsOneWidget);
    expect(find.text('0 / ${kPuzzles.length}'), findsOneWidget);
    expect(find.text('单车擒将'), findsOneWidget);
    expect(find.text('红先 · 1 步杀'), findsWidgets);
    expect(find.text('未通关'), findsNothing);
  });

  testWidgets('通关后列表显示最佳步数', (tester) async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await settings.recordPuzzleCleared('p1', 1);
    await tester.pumpWidget(wrap(settings));
    await tester.pumpAndSettle();

    expect(find.text('1 / ${kPuzzles.length}'), findsOneWidget);
    expect(find.textContaining('最佳 1 步'), findsOneWidget);
  });

  testWidgets('窄屏下列表不溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('单车擒将'), findsOneWidget);
  });

  testWidgets('点击关卡进入残局对局页', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    await tester.tap(find.text('单车擒将'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('单车擒将'), findsWidgets);
    expect(find.text('残局挑战 · 红先 1 步杀'), findsOneWidget);
    expect(find.text('限 1 步 · 剩 1 步'), findsOneWidget);
    expect(find.text('提示'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
