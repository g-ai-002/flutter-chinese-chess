import 'package:chinese_chess/utils/board_display_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('手机与折叠屏折叠态进入横屏全屏', () {
    expect(shouldImmersiveLandscape(const Size(420, 900)), isTrue);
    expect(shouldImmersiveLandscape(const Size(900, 420)), isTrue);
    expect(shouldImmersiveLandscape(const Size(344, 882)), isTrue);
  });

  test('平板、桌面与宽屏保持原有方向', () {
    expect(shouldImmersiveLandscape(const Size(800, 1280)), isFalse);
    expect(shouldImmersiveLandscape(const Size(1280, 900)), isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(shouldImmersiveLandscape(const Size(420, 900)), isFalse);
  });

  testWidgets('棋盘页在窄屏下请求横屏，退出后恢复', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method.startsWith('SystemChrome.')) calls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: BoardDisplayMode(child: Text('棋盘'))),
    );
    await tester.pump();
    expect(find.text('棋盘'), findsOneWidget);
    expect(
      calls,
      containsAll([
        'SystemChrome.setPreferredOrientations',
        'SystemChrome.setEnabledSystemUIMode',
      ]),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // 进入与退出各调用一次方向与系统栏接口。
    expect(
      calls.where((call) => call == 'SystemChrome.setPreferredOrientations'),
      hasLength(2),
    );
    expect(
      calls.where((call) => call == 'SystemChrome.setEnabledSystemUIMode'),
      hasLength(2),
    );
  });
}
