import 'package:chinese_chess/utils/board_display_mode.dart';
import 'package:chinese_chess/utils/board_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('竖屏手机横过来棋盘更小，保持竖屏', () {
    expect(gridFitsBetterLandscape(const Size(420, 900)), isFalse);
    expect(gridFitsBetterLandscape(const Size(360, 640)), isFalse);
    expect(gridFitsBetterLandscape(const Size(344, 882)), isFalse);
    expect(shouldImmersiveLandscape(const Size(420, 900)), isFalse);
    expect(shouldImmersiveLandscape(const Size(344, 882)), isFalse);
  });

  test('接近方形的小屏横过来棋盘更大，才值得横屏', () {
    expect(gridFitsBetterLandscape(const Size(460, 500)), isTrue);
    expect(shouldImmersiveLandscape(const Size(460, 500)), isTrue);
    // 旋转后宽高互换，判定不变，避免锁定与恢复之间来回旋转。
    expect(shouldImmersiveLandscape(const Size(500, 460)), isTrue);
  });

  test('已经是横屏、平板与桌面都不强制改变方向', () {
    expect(shouldImmersiveLandscape(const Size(900, 420)), isFalse);
    expect(shouldImmersiveLandscape(const Size(800, 1280)), isFalse);
    expect(shouldImmersiveLandscape(const Size(1280, 900)), isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(shouldImmersiveLandscape(const Size(460, 500)), isFalse);
  });

  testWidgets('竖屏手机进入棋盘页不旋转，也不隐藏系统栏', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations' ||
            call.method == 'SystemChrome.setEnabledSystemUIMode') {
          calls.add(call.method);
        }
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
    expect(calls, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('横屏确实更大时请求横屏全屏，退出后恢复', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations' ||
            call.method == 'SystemChrome.setEnabledSystemUIMode') {
          calls.add(call.method);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    tester.view.physicalSize = const Size(460, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: BoardDisplayMode(child: Text('棋盘'))),
    );
    await tester.pump();
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
