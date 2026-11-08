/// 人机对战战绩：只统计人机对局，双人与残局不计入。
class GameStatistics {
  const GameStatistics({
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.streak = 0,
    this.bestStreak = 0,
  });

  final int wins;
  final int losses;
  final int draws;

  /// 当前连胜局数，和棋或落败后清零。
  final int streak;

  /// 历史最佳连胜。
  final int bestStreak;

  int get total => wins + losses + draws;

  int get winRate => total == 0 ? 0 : (wins * 100 / total).round();

  /// 记一局人机对战结果：胜为 true、和为 null、负为 false。
  GameStatistics record(bool? won) {
    final nextStreak = won == true ? streak + 1 : 0;
    return GameStatistics(
      wins: wins + (won == true ? 1 : 0),
      losses: losses + (won == false ? 1 : 0),
      draws: draws + (won == null ? 1 : 0),
      streak: nextStreak,
      bestStreak: nextStreak > bestStreak ? nextStreak : bestStreak,
    );
  }

  /// 首页一行的紧凑摘要。
  String get summary => total == 0
      ? '人机战绩 · 首局待战'
      : '人机战绩 · $wins 胜 $losses 负 $draws 和 · 胜率 $winRate%'
            '${streak > 1 ? ' · 连胜 $streak' : ''}';
}
