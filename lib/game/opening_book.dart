import 'board_state.dart';

/// 一条开局线路：从红方起手开始的中文记法序列，附开局名称与要点。
class OpeningLine {
  const OpeningLine({required this.moves, required this.name, this.note});

  final List<String> moves;
  final String name;
  final String? note;
}

/// 开局识别结果：当前开局名称、要点与推荐下一手（中文记法）。
class OpeningInfo {
  const OpeningInfo({required this.name, this.next, this.note});

  final String name;
  final String? next;
  final String? note;
}

/// 内置开局库：按记法前缀识别开局，并给出推荐着法。
///
/// 线路只记录常见的前几个回合，数据由测试逐着校验，保证与规则一致。
class OpeningBook {
  OpeningBook._();

  /// 超过该步数不再提示，避免中局仍显示开局名称。
  static const int maxPlies = 24;

  /// 识别当前开局；对局脱离棋谱时只返回已匹配的开局名称。
  static OpeningInfo? lookup(XiangqiBoard board) {
    final history = board.history;
    if (history.length > maxPlies) return null;
    final played = [for (final record in history) record.notation];
    if (played.isEmpty) {
      return const OpeningInfo(
        name: '中炮',
        next: '炮二平五',
        note: '红方最常见的起手，也可选择仙人指路或飞相局。',
      );
    }

    OpeningLine? named;
    OpeningLine? extension;
    for (final line in kOpeningLines) {
      if (line.moves.length <= played.length && _isPrefix(line.moves, played)) {
        if (named == null || line.moves.length > named.moves.length) {
          named = line;
        }
      } else if (line.moves.length > played.length &&
          _isPrefix(played, line.moves)) {
        if (extension == null || line.moves.length > extension.moves.length) {
          extension = line;
        }
      }
    }
    final matched = named ?? extension;
    if (matched == null) return null;

    return OpeningInfo(
      name: matched.name,
      note: named?.note ?? extension?.note,
      next: extension == null ? null : extension.moves[played.length],
    );
  }

  static bool _isPrefix(List<String> prefix, List<String> value) {
    if (prefix.length > value.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (prefix[index] != value[index]) return false;
    }
    return true;
  }
}

/// 常见开局线路，按红方起手分组。
const List<OpeningLine> kOpeningLines = [
  OpeningLine(moves: ['炮二平五'], name: '中炮', note: '炮镇中路，直指将门，是最常见的起手。'),
  OpeningLine(
    moves: ['炮二平五', '马8进7'],
    name: '中炮对屏风马',
    note: '黑方双马护中卒，稳守中路伺机反击。',
  ),
  OpeningLine(
    moves: ['炮二平五', '马8进7', '马二进三'],
    name: '中炮对屏风马',
    note: '红方跳正马，准备出直车压制。',
  ),
  OpeningLine(
    moves: ['炮二平五', '马8进7', '马二进三', '马2进3'],
    name: '中炮对屏风马',
    note: '双方双马正起，阵型工整。',
  ),
  OpeningLine(
    moves: ['炮二平五', '马8进7', '马二进三', '马2进3', '车一平二'],
    name: '中炮对屏风马 · 红出直车',
    note: '红车抢占二路，压制黑方右马。',
  ),
  OpeningLine(
    moves: ['炮二平五', '马8进7', '马二进三', '马2进3', '车一平二', '车9平8'],
    name: '中炮对屏风马 · 双车对峙',
    note: '黑车对称出动，进入中局缠斗。',
  ),
  OpeningLine(
    moves: ['炮二平五', '炮8平6'],
    name: '中炮对反宫马',
    note: '黑方先平士角炮，再跳屏风马，攻守兼备。',
  ),
  OpeningLine(
    moves: ['炮二平五', '炮8平6', '马二进三', '马8进7'],
    name: '中炮对反宫马 · 士角炮屏风马',
    note: '黑方阵型成形，红方需防中路受制。',
  ),
  OpeningLine(moves: ['炮二平五', '炮8平5'], name: '中炮对顺炮', note: '黑方同向架炮，形成对攻格局。'),
  OpeningLine(
    moves: ['炮二平五', '炮8平5', '马二进三'],
    name: '中炮对顺炮',
    note: '红方先稳中路，再图出车。',
  ),
  OpeningLine(
    moves: ['炮二平五', '炮8平5', '马二进三', '马8进7'],
    name: '中炮对顺炮 · 双正马',
    note: '双方各跳正马，蓄势待发。',
  ),
  OpeningLine(moves: ['炮二平五', '炮2平5'], name: '中炮对列炮', note: '黑方异向架炮，各攻一翼。'),
  OpeningLine(
    moves: ['炮二平五', '马2进3'],
    name: '中炮对单提马',
    note: '黑方单马守中，左翼子力尚待出动。',
  ),
  OpeningLine(moves: ['兵七进一'], name: '仙人指路', note: '先挺七兵试探应手，保留中炮与飞相的选择。'),
  OpeningLine(moves: ['兵七进一', '卒3进1'], name: '仙人指路对进卒', note: '黑方以卒制卒，保持对称。'),
  OpeningLine(moves: ['兵七进一', '炮2平3'], name: '仙人指路对卒底炮', note: '黑方平炮射兵，准备抢先。'),
  OpeningLine(
    moves: ['兵七进一', '炮2平3', '马八进七'],
    name: '仙人指路对卒底炮',
    note: '红马护兵，稳中带攻。',
  ),
  OpeningLine(moves: ['相三进五'], name: '飞相局', note: '先固防守，后发制人。'),
  OpeningLine(moves: ['相三进五', '马8进7'], name: '飞相局对起马', note: '黑方跳马出动，静观其变。'),
  OpeningLine(moves: ['马八进七'], name: '起马局', note: '先出马，保留中炮与飞相的选择。'),
  OpeningLine(moves: ['马八进七', '卒3进1'], name: '起马局对进卒', note: '黑方挺卒制马，争夺中路。'),
  OpeningLine(moves: ['炮二平六'], name: '过宫炮', note: '炮过宫集结一翼，子力协调。'),
  OpeningLine(moves: ['炮八平六'], name: '士角炮', note: '炮入士角，攻守两宜。'),
];
