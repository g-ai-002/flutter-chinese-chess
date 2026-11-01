import 'dart:math' as math;

import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/pages/settings_page.dart';
import 'package:chinese_chess/providers/settings_provider.dart';
import 'package:chinese_chess/services/storage_service.dart';
import 'package:chinese_chess/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _contrast(Color fg, Color bg) {
  final a = fg.computeLuminance();
  final b = bg.computeLuminance();
  final hi = math.max(a, b);
  final lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  test('皮肤 id 唯一，未知 id 回退檀木', () {
    expect(
      kBoardSkins.map((skin) => skin.id).toSet(),
      hasLength(kBoardSkins.length),
    );
    expect(boardSkinOf(null), same(kDefaultBoardSkin));
    expect(boardSkinOf('jade'), same(jadeSkin));
    expect(boardSkinOf('ink'), same(inkSkin));
    expect(boardSkinOf('已下架的皮肤'), same(kDefaultBoardSkin));
  });

  test('每套皮肤的棋面、线条与高亮都清晰可辨', () {
    for (final skin in kBoardSkins) {
      expect(skin.redFace.dark, isNot(skin.blackFace.dark), reason: skin.name);
      for (final side in [red, black]) {
        final face = skin.faceOf(side);
        expect(
          _contrast(face.ink, face.dark),
          greaterThanOrEqualTo(4.0),
          reason: '${skin.name} 皮肤第 $side 方棋子文字应清晰',
        );
        expect(
          _contrast(face.light, face.dark),
          greaterThanOrEqualTo(1.15),
          reason: '${skin.name} 皮肤第 $side 方棋面渐变应有层次',
        );
      }
      expect(
        _contrast(skin.line, skin.boardLight),
        greaterThanOrEqualTo(3.0),
        reason: '${skin.name} 棋盘线条应可见',
      );
      expect(
        _contrast(skin.redInk, skin.boardLight),
        greaterThanOrEqualTo(2.0),
        reason: '${skin.name} 选中与将军高亮应可见',
      );
    }
  });

  test('皮肤选择会写入偏好并在重建后保留', () async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    expect(settings.boardSkin.id, 'wood');

    await settings.setBoardSkin(jadeSkin);
    expect(storage.boardSkinId, 'jade');
    expect(SettingsProvider(storage).boardSkin.id, 'jade');
  });

  testWidgets('设置页可切换棋盘皮肤与音效开关', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
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
          home: const SettingsPage(),
        ),
      ),
    );

    expect(find.text('棋盘皮肤'), findsOneWidget);
    expect(find.text('青玉'), findsOneWidget);

    await tester.tap(find.text('青玉'));
    await tester.pumpAndSettle();
    expect(settings.boardSkin.id, 'jade');
    expect(storage.boardSkinId, 'jade');

    final soundSwitch = find.text('落子音效');
    await tester.ensureVisible(soundSwitch);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).at(3));
    await tester.pumpAndSettle();
    expect(settings.soundEnabled, isFalse);
    expect(storage.soundEnabled, isFalse);

    final hapticsSwitch = find.text('震动反馈');
    await tester.ensureVisible(hapticsSwitch);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).at(4));
    await tester.pumpAndSettle();
    expect(settings.hapticsEnabled, isFalse);
    expect(storage.hapticsEnabled, isFalse);
  });
}
