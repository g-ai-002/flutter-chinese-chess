import 'package:chinese_chess/game/ai_player.dart';
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
}
