import 'package:chinese_chess/pages/widgets/board_hud.dart';
import 'package:chinese_chess/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const ValueKey<String> _boardKey = ValueKey('hud-board');

Widget _hud({String status = '红方行棋'}) => MaterialApp(
  theme: buildLightTheme(),
  home: Scaffold(
    body: BoardHud(
      board: const ColoredBox(key: _boardKey, color: Colors.transparent),
      topStart: const Text('标题'),
      topEnd: const Text('棋钟'),
      bottomStart: Text(status),
      bottomEnd: const Text('操作'),
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
    testWidgets('宽屏把信息挂在棋盘左右留白，棋盘占满高度', (tester) async {
      await pumpAt(tester, const Size(1280, 900));

      final board = tester.getRect(find.byKey(_boardKey));
      expect(board.size, const Size(810, 900));
      expect(board.center.dx, 640);
      expect(board.center.dy, 450);

      // 标题与状态在左侧留白，棋钟与操作在右侧留白，都不压在棋盘上。
      expect(tester.getRect(find.text('标题')).right, lessThan(board.left));
      expect(tester.getRect(find.text('红方行棋')).right, lessThan(board.left));
      expect(tester.getRect(find.text('棋钟')).left, greaterThan(board.right));
      expect(tester.getRect(find.text('操作')).left, greaterThan(board.right));
    });

    testWidgets('窄屏把信息挂在棋盘上下留白', (tester) async {
      await pumpAt(tester, const Size(420, 900));

      final board = tester.getRect(find.byKey(_boardKey));
      expect(board.width, 420);
      expect(board.height, closeTo(420 * 10 / 9, 0.01));
      expect(tester.getRect(find.text('标题')).bottom, lessThan(board.top));
      expect(tester.getRect(find.text('红方行棋')).top, greaterThan(board.bottom));
      expect(tester.getRect(find.text('操作')).top, greaterThan(board.bottom));
    });

    testWidgets('方形窗口为横条预留高度，提示不压到棋盘', (tester) async {
      await pumpAt(tester, const Size(900, 900));

      final board = tester.getRect(find.byKey(_boardKey));
      expect(board.width, closeTo(684, 0.01));
      expect(board.height, closeTo(760, 0.01));
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
      expect(tester.getRect(find.text('操作')).left, greaterThan(board.right));
    });

    testWidgets('提示变长或变短都不会挪动棋盘', (tester) async {
      await pumpAt(tester, const Size(1280, 900));
      final before = tester.getRect(find.byKey(_boardKey));

      await tester.pumpWidget(_hud(status: '提示 炮二平五 · 开局 · 中炮对屏风马 · 试走 马8进7'));
      await tester.pump();
      expect(tester.getRect(find.byKey(_boardKey)), before);

      await tester.pumpWidget(_hud(status: ''));
      await tester.pump();
      expect(tester.getRect(find.byKey(_boardKey)), before);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('窄屏里长提示变长也不改变棋盘尺寸', (tester) async {
      await pumpAt(tester, const Size(420, 900));
      final before = tester.getRect(find.byKey(_boardKey));

      await tester.pumpWidget(_hud(status: '提示 炮二平五 · 开局 · 中炮对屏风马 · 试走 马8进7'));
      await tester.pump();
      expect(tester.getRect(find.byKey(_boardKey)), before);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('小屏横屏用两侧栏，棋盘占满高度', (tester) async {
      await pumpAt(tester, const Size(568, 320));

      final board = tester.getRect(find.byKey(_boardKey));
      expect(board.height, 320);
      expect(board.width, closeTo(288, 0.01));
      for (final label in ['标题', '棋钟', '红方行棋', '操作']) {
        expect(
          tester.getRect(find.text(label)).overlaps(board),
          isFalse,
          reason: label,
        );
      }
    });

    testWidgets('矮窗口改用紧凑横条，棋盘不再被压成细条', (tester) async {
      await pumpAt(tester, const Size(500, 400));

      final board = tester.getRect(find.byKey(_boardKey));
      expect(board.height, closeTo(288, 0.01));
      expect(board.width, greaterThan(240));
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
}
