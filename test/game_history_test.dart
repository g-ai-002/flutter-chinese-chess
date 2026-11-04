import 'dart:convert';

import 'package:chinese_chess/game/board_state.dart';
import 'package:chinese_chess/game/engine/rules.dart';
import 'package:chinese_chess/game/game_archive.dart';
import 'package:chinese_chess/game/notation.dart';
import 'package:chinese_chess/models/saved_game.dart';
import 'package:chinese_chess/services/game_history_service.dart';
import 'package:chinese_chess/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<String> _opening = ['炮二平五', '马8进7', '马二进三', '马2进3'];

SavedGame _game({
  String id = 'game_1',
  String title = '人机对战 · 普通',
  DateTime? endedAt,
  String? result = '红方胜（绝杀）',
}) {
  final board = XiangqiBoard.initial();
  for (final notation in _opening) {
    final move = MoveNotation.findMove(board.cells, board.sideToMove, notation);
    board.applyMove(moveFrom(move!), moveTo(move));
  }
  return SavedGame(
    id: id,
    title: title,
    endedAt: endedAt ?? DateTime(2026, 11, 4, 20, 30),
    layout: board.startLayout,
    startSide: board.startSide,
    moves: board.history,
    result: result,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GameHistoryService.instance.resetForTest();
  });

  test('棋谱 JSON 往返保留布局、着法与结果', () {
    final game = _game();
    final restored = SavedGame.fromJson(game.toJson());

    expect(restored, isNotNull);
    expect(restored!.id, game.id);
    expect(restored.title, game.title);
    expect(restored.result, game.result);
    expect(restored.endedAt, game.endedAt);
    expect(restored.layout, game.layout);
    expect(restored.startSide, game.startSide);
    expect(restored.moveCount, 4);
    expect(restored.moves.map((move) => move.notation), [
      '炮二平五',
      '马8进7',
      '马二进三',
      '马2进3',
    ]);
    expect(restored.toArchiveText(), contains('1. 炮二平五 马8进7'));
  });

  test('布局或着法非法的棋谱丢弃', () {
    final game = _game();
    expect(
      SavedGame.fromJson({'id': 'bad', 'layout': ['bad'], 'moves': const []}),
      isNull,
    );
    expect(
      SavedGame.fromJson({
        'id': 'bad',
        'layout': game.layout,
        'moves': const ['0-999'],
      }),
      isNull,
    );
    expect(
      SavedGame.fromJson({'id': '', 'layout': game.layout, 'moves': const []}),
      isNull,
    );
  });

  test('导入的棋谱转为棋谱库条目', () {
    final source = _game();
    final archive = GameArchive.decode(source.toArchiveText());

    expect(archive, isNotNull);
    final imported = SavedGame.fromArchive(archive!);
    expect(imported.id, startsWith('import_'));
    expect(imported.title, source.title);
    expect(imported.endedAt, source.endedAt);
    expect(imported.result, source.result);
    expect(imported.moveCount, 4);
  });

  test('棋谱库只保留最近 20 局且新的在前', () async {
    final service = GameHistoryService.instance;
    for (var index = 0; index < 25; index++) {
      await service.record(
        _game(
          id: 'g$index',
          endedAt: DateTime(2026, 11, 4, 20, index),
        ),
      );
    }

    expect(service.records, hasLength(GameHistoryService.maxRecords));
    expect(service.records.first.id, 'g24');
    expect(service.records.last.id, 'g5');
  });

  test('同一局再次写入时覆盖旧记录', () async {
    final service = GameHistoryService.instance;
    await service.record(_game(id: 'same', title: '旧标题'));
    await service.record(_game(id: 'same', title: '新标题'));

    expect(service.records, hasLength(1));
    expect(service.records.single.title, '新标题');
  });

  test('棋谱写入后可重新加载', () async {
    final service = GameHistoryService.instance;
    await service.record(_game(id: 'saved'));

    service.resetForTest();
    expect(service.records, isEmpty);

    await service.load();
    expect(service.records, hasLength(1));
    expect(service.records.single.id, 'saved');
    expect(service.records.single.moveCount, 4);
  });

  test('读取棋谱时跳过损坏条目', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefKeyGameHistory: jsonEncode([
        {'id': 'broken', 'layout': ['x'], 'moves': const []},
        _game(id: 'ok').toJson(),
      ]),
    });
    GameHistoryService.instance.resetForTest();

    await GameHistoryService.instance.load();
    final records = GameHistoryService.instance.records;
    expect(records, hasLength(1));
    expect(records.single.id, 'ok');
  });

  test('清空棋谱同时移除偏好存储', () async {
    final service = GameHistoryService.instance;
    await service.record(_game());
    await service.clear();

    expect(service.records, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppConstants.prefKeyGameHistory), isNull);
  });
}
