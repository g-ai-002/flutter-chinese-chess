import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/puzzles.dart';
import '../models/game_models.dart';
import '../providers/settings_provider.dart';
import 'game_page.dart';

/// 残局关卡列表：展示通关进度、最佳步数，点击进入挑战。
class PuzzlePage extends StatelessWidget {
  const PuzzlePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final solved = kPuzzles
        .where((puzzle) => settings.isPuzzleSolved(puzzle.id))
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('残局挑战')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: LayoutBuilder(
                  builder: (context, list) => ListView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 28 : 16,
                      4,
                      wide ? 28 : 16,
                      24,
                    ),
                    children: [
                      _ProgressCard(solved: solved, total: kPuzzles.length),
                      const SizedBox(height: 14),
                      for (var index = 0; index < kPuzzles.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PuzzleCard(
                            index: index,
                            puzzle: kPuzzles[index],
                            solved: settings.isPuzzleSolved(
                              kPuzzles[index].id,
                            ),
                            bestMoves: settings.puzzleBestMoves(
                              kPuzzles[index].id,
                            ),
                            onTap: () => _open(
                              context,
                              kPuzzles[index],
                              settings.difficulty,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        '红方先行，按提示的最少步数将死黑方即为通关。',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _open(BuildContext context, Puzzle puzzle, Difficulty difficulty) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GamePage(
          mode: GameMode.puzzle,
          difficulty: difficulty,
          humanSide: kPuzzleHumanSide,
          puzzle: puzzle,
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.solved, required this.total});

  final int solved;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ratio = total == 0 ? 0.0 : solved / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text('闯关进度', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                '$solved / $total',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: colors.outline.withValues(alpha: 0.5),
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            ratio >= 1 ? '全部通关，杀法已成。' : '一步杀入门，三步杀见功力。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PuzzleCard extends StatelessWidget {
  const _PuzzleCard({
    required this.index,
    required this.puzzle,
    required this.solved,
    required this.bestMoves,
    required this.onTap,
  });

  final int index;
  final Puzzle puzzle;
  final bool solved;
  final int? bestMoves;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = solved ? colors.tertiary : colors.primary;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outline.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: solved
                    ? Icon(Icons.check_rounded, size: 20, color: accent)
                    : Text(
                        '${index + 1}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: accent,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            puzzle.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Tag(text: puzzle.goal, color: accent),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      solved
                          ? '已通关 · 最佳 ${bestMoves ?? puzzle.mateIn} 步'
                          : puzzle.hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: 10.5,
        ),
      ),
    );
  }
}
