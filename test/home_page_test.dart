import 'package:chinese_chess/pages/home_page.dart';
import 'package:chinese_chess/providers/settings_provider.dart';
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
  });

  testWidgets('首页展示品牌、模式入口与对局设置', (tester) async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    expect(find.text('中国象棋'), findsWidgets);
    expect(find.text('人机对战'), findsOneWidget);
    expect(find.text('双人对弈'), findsOneWidget);
    expect(find.text('残局挑战'), findsOneWidget);
    expect(find.text('棋谱复盘'), findsOneWidget);
    expect(find.text('AI 难度'), findsOneWidget);
    expect(find.text('执红先行'), findsOneWidget);
    expect(find.textContaining('v${AppConstants.version}'), findsOneWidget);
  });

  testWidgets('切换先后手会持久化到设置', (tester) async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    final target = find.text('执黑后行');
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();

    expect(settings.humanSide, 1);
    expect(storage.humanSide, 1);
  });

  testWidgets('切换难度会持久化到设置', (tester) async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    final target = find.text('高手');
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();

    expect(settings.difficulty.label, '高手');
    expect(storage.difficulty.name, 'expert');
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

  testWidgets('粘贴棋谱后可直接进入复盘', (tester) async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    final entry = find.text('棋谱复盘');
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('导入棋谱'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      '1. 炮二平五 马8进7\n2. 马二进三 马2进3',
    );
    await tester.tap(find.text('开始复盘'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

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

    await tester.enterText(find.byType(TextField), '这不是棋谱');
    await tester.tap(find.text('开始复盘'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('棋谱无法解析，请检查文本是否完整'), findsOneWidget);
  });
}
