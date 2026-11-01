import '../models/move_record.dart';
import '../utils/formatters.dart';
import 'board_state.dart';
import 'engine/board_utils.dart';
import 'engine/rules.dart';
import 'notation.dart';

/// 解析后的棋谱：着法由开局布局逐着重演得到，可直接用于复盘。
class ArchivedGame {
  const ArchivedGame({
    required this.moves,
    required this.layout,
    required this.startSide,
    required this.title,
    this.result,
    this.date,
  });

  final List<MoveRecord> moves;
  final List<String> layout;
  final int startSide;
  final String title;
  final String? result;
  final String? date;

  int get moveCount => moves.length;
}

/// 棋谱文本编解码：中文记法便于阅读，`#moves` 行保证回放精确。
class GameArchive {
  GameArchive._();

  static const int formatVersion = 1;
  static const String tag = '[中国象棋棋谱]';

  /// 导出为可读棋谱，兼容缺省字段（解析时允许只保留着法）。
  static String encode({
    required List<MoveRecord> moves,
    required List<String> layout,
    int startSide = red,
    required String title,
    String? result,
    DateTime? date,
  }) {
    final buffer = StringBuffer()
      ..writeln(tag)
      ..writeln('版本: $formatVersion')
      ..writeln('标题: $title')
      ..writeln('结果: ${result ?? '进行中'}')
      ..writeln('日期: ${_formatDate(date ?? DateTime.now())}')
      ..writeln('布局: ${layout.join('/')}')
      ..writeln('先手: ${startSide == red ? '红' : '黑'}')
      ..writeln(
        '#moves: ${[for (final move in moves) '${move.from}-${move.to}'].join(' ')}',
      )
      ..writeln('着法:');
    for (var index = 0; index < moves.length; index += 2) {
      final reply = index + 1 < moves.length
          ? ' ${moves[index + 1].notation}'
          : '';
      buffer.writeln('${index ~/ 2 + 1}. ${moves[index].notation}$reply');
    }
    return buffer.toString();
  }

  /// 解析棋谱文本；格式不符或着法非法时返回 null。
  ///
  /// 缺少 `#moves` 时按中文记法逐着匹配，因此纯记谱文本也能导入。
  static ArchivedGame? decode(String text) {
    final fields = <String, String>{};
    final numbered = <String>[];
    final loose = <String>[];
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty || line == tag) continue;
      if (line.startsWith('#')) {
        final body = line.substring(1);
        final colon = body.indexOf(':');
        if (colon > 0) {
          fields['#${body.substring(0, colon)}'] = body
              .substring(colon + 1)
              .trim();
        }
        continue;
      }
      final withIndex = RegExp(r'^\d+\.\s*(.+)$').firstMatch(line);
      if (withIndex != null) {
        numbered.addAll(_tokens(withIndex.group(1)!));
        continue;
      }
      final colon = line.indexOf(':');
      if (colon > 0) {
        fields[line.substring(0, colon).trim()] = line
            .substring(colon + 1)
            .trim();
        continue;
      }
      loose.addAll(_tokens(line));
    }

    final layoutText = fields['布局'];
    final layout = layoutText == null || layoutText.isEmpty
        ? cellsToLayout(initialCells())
        : layoutText.split('/');
    final startSide = fields['先手'] == '黑' ? black : red;

    try {
      final board = XiangqiBoard.fromLayout(layout, sideToMove: startSide);
      final records = <MoveRecord>[];
      final encoded = fields['#moves'];
      if (encoded != null && encoded.isNotEmpty) {
        for (final token in _tokens(encoded)) {
          final parts = token.split('-');
          if (parts.length != 2) return null;
          final from = int.tryParse(parts[0]);
          final to = int.tryParse(parts[1]);
          if (from == null || to == null) return null;
          if (!_apply(board, from, to)) return null;
          records.add(board.history.last);
        }
      } else {
        for (final notation in numbered.isEmpty ? loose : numbered) {
          final move = MoveNotation.findMove(
            board.cells,
            board.sideToMove,
            notation,
          );
          if (move == null) return null;
          if (!_apply(board, moveFrom(move), moveTo(move))) return null;
          records.add(board.history.last);
        }
      }
      if (records.isEmpty) return null;
      return ArchivedGame(
        moves: List.unmodifiable(records),
        layout: layout,
        startSide: startSide,
        title: fields['标题'] ?? '导入棋谱',
        result: _optional(fields['结果']),
        date: fields['日期'],
      );
    } on ArgumentError {
      return null;
    }
  }

  /// 导出的「进行中」对局在复盘时不显示结果。
  static String? _optional(String? value) =>
      value == null || value.isEmpty || value == '进行中' ? null : value;

  static bool _apply(XiangqiBoard board, int from, int to) {
    if (from < 0 || from >= cellCount || to < 0 || to >= cellCount) {
      return false;
    }
    if (!XiangqiRules.isPlayable(board.cells, board.sideToMove, from, to)) {
      return false;
    }
    board.applyMove(from, to);
    return true;
  }

  static List<String> _tokens(String text) => [
    for (final token in text.split(RegExp(r'\s+')))
      if (token.isNotEmpty) token,
  ];

  static String _formatDate(DateTime time) =>
      '${time.year}-${pad2(time.month)}-${pad2(time.day)} '
      '${pad2(time.hour)}:${pad2(time.minute)}';
}
