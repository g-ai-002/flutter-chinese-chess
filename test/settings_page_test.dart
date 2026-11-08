import 'package:chinese_chess/game/logic_rate.dart';
import 'package:chinese_chess/pages/settings_page.dart';
import 'package:chinese_chess/providers/settings_provider.dart';
import 'package:chinese_chess/services/storage_service.dart';
import 'package:chinese_chess/theme/app_theme.dart';
import 'package:chinese_chess/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  testWidgets('设置页可切换提示与深色模式', (tester) async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const SettingsPage(),
        ),
      ),
    );

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('AI 难度'), findsOneWidget);
    expect(find.text('显示可走位置'), findsOneWidget);

    // 开关按 Key 定位，避免列表懒加载导致索引漂移。
    await tester.ensureVisible(find.byKey(const ValueKey('switch-hints')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('switch-hints')));
    await tester.pumpAndSettle();
    expect(settings.showHints, isFalse);
    expect(storage.showHints, isFalse);

    await tester.ensureVisible(find.byKey(const ValueKey('switch-music')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('switch-music')));
    await tester.pumpAndSettle();
    expect(settings.musicEnabled, isFalse);
    expect(storage.musicEnabled, isFalse);

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('v${AppConstants.version}'), findsOneWidget);
  });

  testWidgets('设置页可切换默认难度与执子方', (tester) async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const SettingsPage(),
        ),
      ),
    );

    expect(find.text('默认执子'), findsOneWidget);

    await tester.tap(find.text('高手'));
    await tester.pumpAndSettle();
    expect(settings.difficulty.name, 'expert');
    expect(storage.difficulty.name, 'expert');

    await tester.tap(find.text('执黑后行'));
    await tester.pumpAndSettle();
    expect(settings.humanSide, 1);
    expect(storage.humanSide, 1);

    expect(find.text('逻辑刷新率'), findsOneWidget);
    await tester.ensureVisible(find.text('30 Hz 省电'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 Hz 省电'));
    await tester.pumpAndSettle();
    expect(settings.logicRate, LogicRate.hz30);
    expect(storage.logicRate, LogicRate.hz30);
  });
}
