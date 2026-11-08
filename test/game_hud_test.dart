import 'package:chinese_chess/pages/widgets/board_hud.dart';
import 'package:chinese_chess/theme/app_theme.dart';
import 'package:chinese_chess/utils/board_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const ValueKey<String> _boardKey = ValueKey('hud-board');

Widget _hud({String info = '红方行棋'}) => MaterialApp(
  theme: buildLightTheme(),
  home: Scaffold(
    body: BoardHud(
      board: const ColoredBox(key: _boardKey, color: Colors.transparent),
      topStart: const Text('标题'),
      topEnd: const Text('棋钟'),
      info: Text(info),
      controls: const Text('操作'),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_hud());
    await tester.pump();
  }

  group('悬浮 HUD', () {
    testWidgets('宽屏把标题、棋钟与提示挂在棋盘左右留白，按钮在下方', (tester) async {
      await pumpAt(tester, const Size(1280, 900));

      final board = tester.getRect(find.byKey(_boardKey));
      expect(board.center.dx, 640);
      expect(board.height, closeTo(900 - kHudBottomRow, 0.5));

      // 标题与提示在棋盘左侧，棋钟在右侧，按钮在棋盘下方，都不压在棋盘上。
      for (final label in ['标题', '红方行棋', '棋钟', '操作']) {
        expect(
          tester.getRect(find.text(label)).overlaps(board),
          isFalse,
          reason: label,
        );
      }
      expect(tester.getRect(find.text('标题')).right, lessThan(board.left));
      expect(tester.getRect(find.text('棋钟')).left, greaterThan(board.right));
      expect(tester.getRect(find.text('操作')).top, greaterThan(board.bottom));
    });

    testWidgets('窄屏把标题与提示挂在棋盘上方，按钮挂在下方', (tester) async {
      await pumpAt(tester, const Size(420, 900));

      final board = tester.getRect(find.byKey(_boardKey));
      expect(board.width, 420);
      expect(board.height, closeTo(420 * 10 / 9, 0.01));
      expect(tester.getRect(find.text('标题')).bottom, lessThan(board.top));
      expect(tester.getRect(find.text('红方行棋')).bottom, lessThan(board.top));
      expect(tester.getRect(find.text('操作')).top, greaterThan(board.bottom));
    });

    testWidgets('方形窗口为上下横条预留高度，提示不压到棋盘', (tester) async {
      await pumpAt(tester, const Size(900, 900));

      final board = tester.getRect(find.byKey(_boardKey));
      expect(board.width, greaterThan(600));
      expect(board.width, lessThan(700));
      for (final label in ['标题', '棋钟', '红方行棋', '操作']) {
        expect(
          tester.getRect(find.text(label)).overlaps(board),
          isFalse,
          reason: label,
        );
      }
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('超宽屏侧栏贴着棋盘，不甩到屏幕边缘', (tester) async {
      await pumpAt(tester, const Size(1920, 1080));

      final board = tester.getRect(find.byKey(_boardKey));
      expect(board.width, 820);
      final title = tester.getRect(find.text('标题'));
      expect(title.left, greaterThan(200));
      expect(title.right, lessThan(board.left));
      expect(tester.getRect(find.text('操作')).top, greaterThan(board.bottom));
    });

    testWidgets('提示变长或变短都不会挪动棋盘', (tester) async {
      await pumpAt(tester, const Size(1280, 900));
      final before = tester.getRect(find.byKey(_boardKey));

      await tester.pumpWidget(_hud(info: '提示 炮二平五 · 开局 · 中炮对屏风马 · 试走 马8进7'));
      await tester.pump();
      expect(tester.getRect(find.byKey(_boardKey)), before);

      await tester.pumpWidget(_hud(info: ''));
      await tester.pump();
      expect(tester.getRect(find.byKey(_boardKey)), before);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('窄屏里长提示变长也不改变棋盘尺寸', (tester) async {
      await pumpAt(tester, const Size(420, 900));
      final before = tester.getRect(find.byKey(_boardKey));

      await tester.pumpWidget(_hud(info: '提示 炮二平五 · 开局 · 中炮对屏风马 · 试走 马8进7'));
      await tester.pump();
      expect(tester.getRect(find.byKey(_boardKey)), before);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('小屏横屏用两侧栏，按钮仍在棋盘下方', (tester) async {
      await pumpAt(tester, const Size(568, 320));

      final board = tester.getRect(find.byKey(_boardKey));
      expect(board.height, closeTo(320 - 54, 0.5));
      for (final label in ['标题', '棋钟', '红方行棋', '操作']) {
        expect(
          tester.getRect(find.text(label)).overlaps(board),
          isFalse,
          reason: label,
        );
      }
      expect(tester.getRect(find.text('操作')).top, greaterThan(board.bottom));
    });

    testWidgets('矮窗口改用紧凑横条，棋盘不再被压成细条', (tester) async {
      await pumpAt(tester, const Size(500, 400));

      final board = tester.getRect(find.byKey(_boardKey));
      expect(board.width, greaterThan(220));
      for (final label in ['标题', '棋钟', '红方行棋', '操作']) {
        expect(
          tester.getRect(find.text(label)).overlaps(board),
          isFalse,
          reason: label,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('系统字号放大后 HUD 仍不压到棋盘', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpAt(tester, const Size(420, 900));

      final board = tester.getRect(find.byKey(_boardKey));
      expect(board.width, 420);
      for (final label in ['标题', '棋钟', '红方行棋', '操作']) {
        expect(
          tester.getRect(find.text(label)).overlaps(board),
          isFalse,
          reason: label,
        );
      }
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('手机尺寸下提示卡片整块挂在棋盘上方，不压到棋盘', (tester) async {
      for (final size in const [
        Size(360, 640),
        Size(360, 780),
        Size(412, 915),
        Size(900, 900),
      ]) {
        for (final scale in [1.0, 1.4]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await pumpAt(tester, size);
          final board = tester.getRect(find.byKey(_boardKey));
          final info = tester.getRect(
            find
                .ancestor(
                  of: find.text('红方行棋'),
                  matching: find.byType(Container),
                )
                .first,
          );
          expect(info.overlaps(board), isFalse, reason: '$size x$scale');
          expect(
            info.bottom,
            lessThanOrEqualTo(board.top),
            reason: '$size x$scale',
          );
          expect(tester.takeException(), isNull, reason: '$size x$scale');
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    testWidgets('常见设备尺寸下棋盘都不会被 HUD 覆盖', (tester) async {
      const sizes = [
        Size(360, 640),
        Size(420, 900),
        Size(500, 400),
        Size(568, 320),
        Size(673, 900),
        Size(800, 600),
        Size(900, 420),
        Size(1024, 768),
        Size(1280, 800),
        Size(1920, 1080),
      ];
      for (final size in sizes) {
        await pumpAt(tester, size);
        final board = tester.getRect(find.byKey(_boardKey));
        expect(board.width, greaterThan(0), reason: '$size');
        for (final label in ['标题', '棋钟', '红方行棋', '操作']) {
          expect(
            tester.getRect(find.text(label)).overlaps(board),
            isFalse,
            reason: '$size $label',
          );
        }
        expect(tester.takeException(), isNull, reason: '$size');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('布局几何', () {
    test('棋盘按 9:10 取最大尺寸', () {
      expect(boardFitSize(const Size(1200, 600)), const Size(540, 600));
      expect(boardFitSize(const Size(4000, 4000)).width, kBoardMaxWidth);
    });

    test('宽屏用两侧栏，棋盘贴着两侧栏', () {
      final metrics = resolveHud(const Size(1280, 900));
      expect(metrics.sideRail, isTrue);
      expect(metrics.rail, greaterThan(kHudRailWidth));
      expect(metrics.board.height, closeTo(900 - kHudBottomRow, 0.5));
    });

    test('窄屏不用侧栏，提示信息排到棋盘上方', () {
      final metrics = resolveHud(const Size(420, 900));
      expect(metrics.sideRail, isFalse);
      expect(metrics.board.width, 420);
      expect(metrics.board.height, lessThan(900 - kHudBottomRow));
    });
  });
}
