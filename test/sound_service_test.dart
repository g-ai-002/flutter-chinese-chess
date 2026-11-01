import 'package:chinese_chess/models/game_models.dart';
import 'package:chinese_chess/pages/game_page.dart';
import 'package:chinese_chess/providers/settings_provider.dart';
import 'package:chinese_chess/services/sound_service.dart';
import 'package:chinese_chess/services/storage_service.dart';
import 'package:chinese_chess/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    calls = [];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    SoundService.configure(sound: true, haptics: true);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  List<String> methods() => calls.map((call) => call.method).toList();

  test('普通落子使用轻提示音与选择震动', () async {
    SoundService.play(MoveFeedback.move);
    await Future<void>.delayed(Duration.zero);

    expect(methods(), ['SystemSound.play', 'HapticFeedback.vibrate']);
    expect(calls.first.arguments, 'SystemSoundType.click');
    expect(calls.last.arguments, 'HapticFeedbackType.selectionClick');
  });

  test('吃子与将军使用提醒音与更强的震动', () async {
    SoundService.play(MoveFeedback.capture);
    SoundService.play(MoveFeedback.check);
    await Future<void>.delayed(Duration.zero);

    expect(methods().where((m) => m == 'SystemSound.play'), hasLength(2));
    expect(calls.first.arguments, 'SystemSoundType.alert');
    expect(
      calls.map((call) => call.arguments),
      containsAll([
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
      ]),
    );
  });

  test('关闭音效与震动后不再触发系统调用', () async {
    SoundService.configure(sound: false, haptics: false);
    SoundService.play(MoveFeedback.end);
    await Future<void>.delayed(Duration.zero);

    expect(calls, isEmpty);
  });

  testWidgets('对局落子会触发落子反馈', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    await tester.pump(const Duration(milliseconds: 50));
    calls.clear();

    final board = find.byKey(const ValueKey('xiangqi-board'));
    final rect = tester.getRect(board);
    final cell = rect.width / 9;
    Offset center(int row, int col) =>
        rect.topLeft + Offset((col + 0.5) * cell, (row + 0.5) * cell);

    await tester.tapAt(center(6, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center(5, 0));
    await tester.pump(const Duration(milliseconds: 100));

    expect(methods(), contains('SystemSound.play'));
    expect(methods(), contains('HapticFeedback.vibrate'));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
