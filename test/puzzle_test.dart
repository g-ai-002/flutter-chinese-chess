import 'package:chinese_chess/game/ai_player.dart';
import 'package:chinese_chess/game/board_state.dart';
import 'package:chinese_chess/game/engine/board_utils.dart';
import 'package:chinese_chess/game/engine/rules.dart';
import 'package:chinese_chess/game/game_controller.dart';
import 'package:chinese_chess/game/puzzles.dart';
import 'package:chinese_chess/models/game_models.dart';
import 'package:chinese_chess/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameController puzzleController(
  Puzzle puzzle, {
  AiMoveProvider? aiMove,
}) {
  final controller = GameController(
    mode: GameMode.puzzle,
    difficulty: Difficulty.entry,
    humanSide: kPuzzleHumanSide,
    puzzle: puzzle,
    aiMove:
        aiMove ??
        (cells, side, difficulty) async => const AiReply(
          move: -1,
          score: 0,
          nodes: 0,
          depth: 0,
        ),
  );
  controller.start();
  return controller;
}

void play(GameController controller, int fromRow, int fromCol, int toRow,
    int toCol) {
  controller.tapCell(indexOf(fromRow, fromCol));
  controller.tapCell(indexOf(toRow, toCol));
}

/// 走一步即可将死黑方的着法，用于校验一步杀关卡。
bool hasMateInOne(XiangqiBoard board) {
  for (final move in XiangqiRules.legalMoves(board.cells, red)) {
    final from = moveFrom(move);
    final to = moveTo(move);
    final piece = board.cells[from];
    final captured = board.cells[to];
    board.cells[to] = piece;
    board.cells[from] = 0;
    final mated = XiangqiRules.legalMoves(board.cells, black).isEmpty &&
        XiangqiRules.isKingInCheck(board.cells, black);
    board.cells[from] = piece;
    board.cells[to] = captured;
    if (mated) return true;
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  group('残局关卡', () {
    test('关卡编号唯一且步数递增', () {
      final ids = kPuzzles.map((puzzle) => puzzle.id).toSet();
      expect(ids.length, kPuzzles.length);
      expect(kPuzzles, hasLength(8));
      for (var index = 1; index < kPuzzles.length; index++) {
        expect(
          kPuzzles[index].mateIn >= kPuzzles[index - 1].mateIn,
          isTrue,
          reason: '${kPuzzles[index].title} 的步数不应小于上一关',
        );
      }
    });

    test('每个局面合法：双方有将、红先、黑方未被将军', () {
      for (final puzzle in kPuzzles) {
        final board = XiangqiBoard.fromLayout(puzzle.layout);
        expect(puzzle.layout, hasLength(boardRows));
        for (final row in puzzle.layout) {
          expect(row.length, boardCols, reason: '${puzzle.title} 行宽应为 9');
        }
        expect(
          XiangqiRules.findKing(board.cells, red),
          isNotNull,
          reason: '${puzzle.title} 缺少红帅',
        );
        expect(
          XiangqiRules.findKing(board.cells, black),
          isNotNull,
          reason: '${puzzle.title} 缺少黑将',
        );
        expect(XiangqiRules.kingsFacing(board.cells), isFalse);
        expect(XiangqiRules.isKingInCheck(board.cells, black), isFalse);
        expect(XiangqiRules.isKingInCheck(board.cells, red), isFalse);
        expect(XiangqiRules.legalMoves(board.cells, red), isNotEmpty);
      }
    });

    test('一步杀关卡确实存在一步将死', () {
      for (final puzzle in kPuzzles.where((item) => item.mateIn == 1)) {
        final board = XiangqiBoard.fromLayout(puzzle.layout);
        expect(hasMateInOne(board), isTrue, reason: '${puzzle.title} 无一步杀');
      }
    });

    test('残局开局用红方先行并保留关卡布局', () {
      final puzzle = kPuzzles.first;
      final controller = puzzleController(puzzle);
      expect(controller.board.sideToMove, red);
      expect(
        XiangqiRules.isKingInCheck(controller.board.cells, black),
        isFalse,
      );
      expect(controller.remainingMoves, puzzle.mateIn);
      controller.dispose();
    });
  });

  group('残局对局', () {
    test('一步杀落子后判通关并记录步数', () {
      final puzzle = kPuzzles.first;
      final controller = puzzleController(puzzle);
      play(controller, 1, 0, 0, 0);

      expect(controller.result, isNotNull);
      expect(controller.result!.winner, red);
      expect(controller.result!.reason, '绝杀');
      expect(controller.puzzleCleared, isTrue);
      expect(controller.humanMoves, 1);
      controller.dispose();
    });

    test('用尽步数未将死判挑战失败', () {
      final puzzle = kPuzzles.first;
      final controller = puzzleController(puzzle);
      play(controller, 1, 0, 1, 2);

      expect(controller.result, isNotNull);
      expect(controller.puzzleCleared, isFalse);
      expect(controller.result!.reason, '超出限定步数');
      expect(controller.canInteractive, isFalse);
      controller.dispose();
    });

    test('残局中 AI 会应招并在超限时结束', () async {
      final puzzle = kPuzzles[3];
      final controller = puzzleController(
        puzzle,
        aiMove: (cells, side, difficulty) async {
          final moves = XiangqiRules.legalMoves(cells, side);
          return AiReply(
            move: moves.first,
            score: 0,
            nodes: 1,
            depth: 1,
          );
        },
      );

      play(controller, 1, 0, 0, 0);
      expect(controller.result, isNull);
      expect(controller.thinking, isTrue);

      await pumpEventQueue();
      expect(controller.history.length, 2);
      expect(controller.remainingMoves, puzzle.mateIn - 1);
      controller.dispose();
    });

    test('重开残局回到关卡初始局面', () {
      final puzzle = kPuzzles.first;
      final controller = puzzleController(puzzle);
      play(controller, 1, 0, 0, 0);
      expect(controller.result, isNotNull);

      controller.restart();
      expect(controller.history, isEmpty);
      expect(controller.result, isNull);
      expect(controller.board.sideToMove, red);
      expect(controller.remainingMoves, puzzle.mateIn);
      expect(controller.canInteractive, isTrue);
      controller.dispose();
    });
  });

  group('残局进度存储', () {
    test('通关记录会持久化并保留更少的步数', () async {
      final storage = await StorageService.instance;
      expect(storage.isPuzzleSolved('p1'), isFalse);
      expect(storage.puzzleBestMoves('p1'), isNull);

      await storage.recordPuzzleCleared('p1', 3);
      expect(storage.isPuzzleSolved('p1'), isTrue);
      expect(storage.puzzleBestMoves('p1'), 3);

      await storage.recordPuzzleCleared('p1', 5);
      expect(storage.puzzleBestMoves('p1'), 3);

      await storage.recordPuzzleCleared('p1', 2);
      expect(storage.puzzleBestMoves('p1'), 2);
    });
  });
}
