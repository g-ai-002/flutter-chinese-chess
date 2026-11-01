/// 难度档位：搜索深度与原着随机度。
enum Difficulty {
  entry('入门', 1, 160),
  normal('普通', 3, 40),
  expert('高手', 4, 0);

  const Difficulty(this.label, this.depth, this.randomness);

  final String label;
  final int depth;
  final int randomness;
}

/// 对弈模式。
enum GameMode {
  vsAi('人机对战'),
  twoPlayers('双人对弈'),
  puzzle('残局挑战');

  const GameMode(this.label);

  final String label;
}

/// 对局结果。
class GameResult {
  const GameResult({required this.winner, required this.reason});

  /// 胜方（[red]/[black]），和棋时为 null。
  final int? winner;
  final String reason;

  bool get isDraw => winner == null;

  String get title {
    if (winner == null) return '和棋';
    return winner == 0 ? '红方胜' : '黑方胜';
  }
}
