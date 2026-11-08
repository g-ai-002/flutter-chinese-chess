import 'dart:typed_data';

import 'package:chinese_chess/game/ai_player.dart';
import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/models/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('三档 AI 的搜索深度与时限不再按平台降档', () {
    for (final difficulty in Difficulty.values) {
      final limits = AiPlayer.limitsFor(difficulty);
      expect(limits.depth, difficulty.depth, reason: difficulty.name);
      expect(
        limits.timeLimitMillis,
        difficulty.timeLimitMillis,
        reason: difficulty.name,
      );
    }
  });

  test('离开对局页时取消搜索，立即结束并回收 isolate', () async {
    final search = AiSearch();
    final pending = search.chooseMove(
      Uint8List.fromList(initialCells()),
      red,
      Difficulty.expert,
    );

    search.cancel();
    await expectLater(pending, throwsA(isA<AiSearchCancelled>()));

    // 取消后再次请求直接失败，不会再起新的后台任务。
    await expectLater(
      search.chooseMove(
        Uint8List.fromList(initialCells()),
        red,
        Difficulty.expert,
      ),
      throwsA(isA<AiSearchCancelled>()),
    );
  });
}
