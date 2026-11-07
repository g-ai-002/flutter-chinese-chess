import 'package:chinese_chess/pages/home_page.dart';
import 'package:chinese_chess/providers/settings_provider.dart';
import 'package:chinese_chess/services/game_history_service.dart';
import 'package:chinese_chess/services/storage_service.dart';
import 'package:chinese_chess/theme/app_theme.dart';
import 'package:chinese_chess/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget wrap(SettingsProvider settings) => ChangeNotifierProvider.value(
  value: settings,
  child: MaterialApp(theme: buildLightTheme(), home: const HomePage()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    GameHistoryService.instance.resetForTest();
  });

  testWidgets('首页展示品牌与模式入口，不再重复对局设置', (tester) async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    expect(find.text('中国象棋'), findsWidgets);
    expect(find.text('人机对战'), findsOneWidget);
    expect(find.text('双人对弈'), findsOneWidget);
    expect(find.text('残局挑战'), findsOneWidget);
    expect(find.text('棋谱复盘'), findsOneWidget);
    expect(find.text('对局设置'), findsNothing);
    expect(find.text('AI 难度'), findsNothing);
    expect(find.textContaining('v${AppConstants.version}'), findsOneWidget);
  });

  testWidgets('折叠屏展开宽度下四个模式入口排成两列', (tester) async {
    tester.view.physicalSize = const Size(673, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    final ai = tester.getTopLeft(find.text('人机对战'));
    final duel = tester.getTopLeft(find.text('双人对弈'));
    final puzzle = tester.getTopLeft(find.text('残局挑战'));
    final review = tester.getTopLeft(find.text('棋谱复盘'));

    expect(duel.dy, closeTo(ai.dy, 0.5));
    expect(duel.dx, greaterThan(ai.dx));
    expect(puzzle.dy, greaterThan(ai.dy));
    expect(review.dy, closeTo(puzzle.dy, 0.5));
  });

  testWidgets('宽屏首页改为左右两栏，入口无需滚动即可见', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    // 主视觉在左、入口在右，四个入口都在首屏内。
    final hero = tester.getCenter(find.text('楚 河 · 漢 界'));
    final ai = tester.getRect(find.text('人机对战'));
    expect(ai.left, greaterThan(hero.dx));
    for (final label in ['人机对战', '双人对弈', '残局挑战', '棋谱复盘']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.top, greaterThanOrEqualTo(0), reason: label);
      expect(rect.bottom, lessThan(900), reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏下模式入口保持单列', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    final ai = tester.getTopLeft(find.text('人机对战'));
    final duel = tester.getTopLeft(find.text('双人对弈'));
    expect(duel.dy, greaterThan(ai.dy));
  });

  testWidgets('深色模式按钮切换主题偏好', (tester) async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    expect(settings.darkMode, isFalse);
    await tester.tap(find.byTooltip('切换深色'));
    await tester.pumpAndSettle();
    expect(settings.darkMode, isTrue);
  });

  testWidgets('棋谱复盘入口打开棋谱库并支持粘贴导入', (tester) async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    final entry = find.text('棋谱复盘');
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('棋谱'), findsOneWidget);
    expect(find.text('还没有棋谱'), findsOneWidget);

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

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('无法解析的棋谱给出提示', (tester) async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    final entry = find.text('棋谱复盘');
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('导入棋谱'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '这不是棋谱');
    await tester.tap(find.text('开始复盘'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('棋谱无法解析，请检查文本是否完整'), findsOneWidget);
  });
}
