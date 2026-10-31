/// 一步已落子的记录。
class MoveRecord {
  const MoveRecord({
    required this.from,
    required this.to,
    required this.piece,
    required this.captured,
    required this.notation,
    required this.givesCheck,
    required this.noCaptureBefore,
  });

  final int from;
  final int to;
  final int piece;
  final int captured;
  final String notation;
  final bool givesCheck;
  final int noCaptureBefore;

  bool get isCapture => captured != 0;
}
