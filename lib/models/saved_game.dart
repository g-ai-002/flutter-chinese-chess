import '../game/board_state.dart';
import '../game/engine/board_utils.dart';
import '../game/game_archive.dart';
import 'move_record.dart';

/// 保存在本地的对局回放：开局布局 + 着法序列，写入偏好存储后可再次复盘。
class SavedGame {
  SavedGame({
    required this.id,
    required this.title,
    required this.endedAt,
    required this.layout,
    required this.startSide,
    required List<MoveRecord> moves,
    this.result,
  }) : moves = List.unmodifiable(moves);

  final String id;
  final String title;
  final DateTime endedAt;
  final List<String> layout;
  final int startSide;
  final List<MoveRecord> moves;
  final String? result;

  int get moveCount => moves.length;

  String get resultLabel => result == null || result!.isEmpty ? '进行中' : result!;

  /// 与复盘页导出共用同一份文本格式。
  String toArchiveText() => GameArchive.encode(
    moves: moves,
    layout: layout,
    startSide: startSide,
    title: title,
    result: result,
    date: endedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'endedAt': endedAt.toIso8601String(),
    'layout': layout,
    'startSide': startSide,
    'result': result,
    'moves': [for (final move in moves) '${move.from}-${move.to}'],
  };

  /// 布局或着法非法、缺少必要字段时返回 null。
  static SavedGame? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final rawLayout = json['layout'];
    final rawMoves = json['moves'];
    if (id is! String || id.isEmpty) return null;
    if (rawLayout is! List || rawMoves is! List) return null;

    final layout = [for (final row in rawLayout) '$row'];
    final startSide = json['startSide'] == black ? black : red;
    try {
      final board = XiangqiBoard.fromLayout(layout, sideToMove: startSide);
      for (final token in rawMoves) {
        final parts = '$token'.split('-');
        if (parts.length != 2) return null;
        final from = int.tryParse(parts[0]);
        final to = int.tryParse(parts[1]);
        if (from == null || to == null) return null;
        if (board.tryApply(from, to) == null) return null;
      }
      final endedAt =
          DateTime.tryParse('${json['endedAt']}') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return SavedGame(
        id: id,
        title: json['title'] is String && (json['title'] as String).isNotEmpty
            ? json['title'] as String
            : '对局回放',
        endedAt: endedAt,
        layout: layout,
        startSide: startSide,
        moves: board.history,
        result: json['result'] is String && (json['result'] as String).isNotEmpty
            ? json['result'] as String
            : null,
      );
    } on ArgumentError {
      return null;
    }
  }

  /// 把导入的棋谱转成棋谱库条目，日期缺失时用当前时间。
  factory SavedGame.fromArchive(ArchivedGame archive) {
    final now = DateTime.now();
    return SavedGame(
      id: 'import_${now.microsecondsSinceEpoch}',
      title: archive.title,
      endedAt: DateTime.tryParse(archive.date ?? '') ?? now,
      layout: archive.layout,
      startSide: archive.startSide,
      moves: archive.moves,
      result: archive.result,
    );
  }
}
