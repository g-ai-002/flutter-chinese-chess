/// 棋盘与棋子的基础定义。
///
/// 坐标约定：`row` 0..9 从上（黑方底线）到下（红方底线），`col` 0..8 从左到右；
/// 格子线性下标为 `row * 9 + col`。红方在下方（row 7..9 为九宫），黑方在上方。
library;

import 'dart:typed_data';

const int boardCols = 9;
const int boardRows = 10;
const int cellCount = boardCols * boardRows;

const int red = 0;
const int black = 1;

const int typeKing = 1;
const int typeAdvisor = 2;
const int typeElephant = 3;
const int typeHorse = 4;
const int typeRook = 5;
const int typeCannon = 6;
const int typePawn = 7;

/// 棋子编码：低 3 位为类型，第 4 位为阵营（0 红 / 1 黑）。
int pieceOf(int side, int type) => type | (side << 3);
int sideOf(int piece) => piece >> 3;
int typeOf(int piece) => piece & 7;

int rowOf(int index) => index ~/ boardCols;
int colOf(int index) => index % boardCols;
int indexOf(int row, int col) => row * boardCols + col;

bool inBoard(int row, int col) =>
    row >= 0 && row < boardRows && col >= 0 && col < boardCols;

int opponentOf(int side) => side ^ 1;

/// 兵/卒的前进方向（行号变化）。
int pawnForward(int side) => side == red ? -1 : 1;

bool hasCrossedRiver(int side, int row) => side == red ? row <= 4 : row >= 5;

bool inPalace(int side, int row, int col) {
  if (col < 3 || col > 5) return false;
  return side == red ? row >= 7 : row <= 2;
}

/// 红黑双方棋子名称（用于界面与棋谱）。
const List<String> _redNames = ['', '帅', '仕', '相', '马', '车', '炮', '兵'];
const List<String> _blackNames = ['', '将', '士', '象', '马', '车', '炮', '卒'];

String pieceName(int piece) {
  if (piece == 0) return '';
  final names = sideOf(piece) == red ? _redNames : _blackNames;
  return names[typeOf(piece)];
}

String sideName(int side) => side == red ? '红方' : '黑方';

/// 对局开始时的棋盘布局。
const List<String> _initialLayout = [
  'rheakaehr',
  '.........',
  '.c.....c.',
  'p.p.p.p.p',
  '.........',
  '.........',
  'P.P.P.P.P',
  '.C.....C.',
  '.........',
  'RHEAKAEHR',
];

const Map<String, int> _charToPiece = {
  'K': typeKing,
  'A': typeAdvisor,
  'E': typeElephant,
  'H': typeHorse,
  'R': typeRook,
  'C': typeCannon,
  'P': typePawn,
};

Uint8List initialCells() {
  final cells = Uint8List(cellCount);
  for (var row = 0; row < boardRows; row++) {
    final line = _initialLayout[row];
    for (var col = 0; col < boardCols; col++) {
      final ch = line[col];
      if (ch == '.') continue;
      final isRed = ch == ch.toUpperCase();
      final type = _charToPiece[ch.toUpperCase()]!;
      cells[row * boardCols + col] = pieceOf(isRed ? red : black, type);
    }
  }
  return cells;
}

/// 调试与测试用：把棋盘转成布局字符串。
List<String> cellsToLayout(Uint8List cells) {
  final symbols = {
    typeKing: 'k',
    typeAdvisor: 'a',
    typeElephant: 'e',
    typeHorse: 'h',
    typeRook: 'r',
    typeCannon: 'c',
    typePawn: 'p',
  };
  return List.generate(boardRows, (row) {
    final buffer = StringBuffer();
    for (var col = 0; col < boardCols; col++) {
      final piece = cells[row * boardCols + col];
      if (piece == 0) {
        buffer.write('.');
        continue;
      }
      final symbol = symbols[typeOf(piece)]!;
      buffer.write(sideOf(piece) == red ? symbol.toUpperCase() : symbol);
    }
    return buffer.toString();
  });
}
