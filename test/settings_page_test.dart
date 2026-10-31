import 'package:chinese_chess/pages/settings_page.dart';
import 'package:chinese_chess/providers/settings_provider.dart';
import 'package:chinese_chess/services/storage_service.dart';
import 'package:chinese_chess/theme/app_theme.dart';
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

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(settings.showHints, isFalse);
    expect(storage.showHints, isFalse);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('v0.1.0'), findsOneWidget);
  });
}
