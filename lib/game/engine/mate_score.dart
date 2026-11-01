/// 杀棋分数：`mate - ply` 表示「ply 步之后被将死」，层数越小代表杀得越快。
///
/// 搜索、置换表与界面统一以此为准，不再各自硬编码阈值。
class MateScore {
  MateScore._();

  /// 根节点即被将死的分数。
  static const int mate = 1000000;

  /// 绝对值超过该分数即视为杀棋分数。
  static const int threshold = 999000;

  /// [ply] 步后被将死的一方得分。
  static int at(int ply) => mate - ply;

  static bool isMate(int score) => score > threshold || score < -threshold;

  /// 存入置换表：胜方加上层数、负方减去层数，让同一局面在不同深度复用。
  static int toStored(int score, int ply) {
    if (score > threshold) return score + ply;
    if (score < -threshold) return score - ply;
    return score;
  }

  /// 从置换表取回，恢复成当前层数下的杀棋分数，见 [toStored]。
  static int fromStored(int score, int ply) {
    if (score > threshold) return score - ply;
    if (score < -threshold) return score + ply;
    return score;
  }
}
