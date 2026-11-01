import 'package:flutter/material.dart';

import '../../models/game_models.dart';

/// 终局弹窗：展示胜负原因，可返回首页、复盘或再来一局。
Future<void> showGameResultDialog(
  BuildContext context, {
  required GameResult result,
  required int moveCount,
  required VoidCallback onRestart,
  VoidCallback? onReview,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return PopScope(
        canPop: false,
        child: AlertDialog(
          icon: Icon(
            result.isDraw
                ? Icons.handshake_outlined
                : Icons.emoji_events_outlined,
            size: 36,
            color: colors.primary,
          ),
          title: Text(result.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(result.reason),
              const SizedBox(height: 6),
              Text(
                '共 $moveCount 手',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: const Text('返回首页'),
            ),
            if (onReview != null)
              OutlinedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onReview();
                },
                child: const Text('复盘'),
              ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onRestart();
              },
              child: const Text('再来一局'),
            ),
          ],
        ),
      );
    },
  );
}

/// 认输二次确认，返回 true 表示确认认输。
Future<bool> confirmResign(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('认输'),
      content: const Text('确认认输并结束本局吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('继续对局'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('认输'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// 残局结果弹窗：通关时可继续下一关。
Future<void> showPuzzleResultDialog(
  BuildContext context, {
  required bool cleared,
  required String reason,
  required int moves,
  required int mateIn,
  required VoidCallback onRetry,
  VoidCallback? onNext,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return PopScope(
        canPop: false,
        child: AlertDialog(
          icon: Icon(
            cleared ? Icons.emoji_events_outlined : Icons.hourglass_bottom,
            size: 36,
            color: colors.primary,
          ),
          title: Text(cleared ? '挑战成功' : '挑战失败'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(cleared ? '于第 $moves 步将死黑方' : reason),
              const SizedBox(height: 6),
              Text(
                '本关限 $mateIn 步',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: const Text('返回列表'),
            ),
            if (cleared && onNext != null)
              OutlinedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onNext();
                },
                child: const Text('下一关'),
              ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onRetry();
              },
              child: Text(cleared ? '再来一次' : '再试一次'),
            ),
          ],
        ),
      );
    },
  );
}

/// 行棋规则说明。
void showRulesDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('行棋规则'),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _RuleLine('马走日、相飞田，炮隔一子吃子，车走直线。'),
            _RuleLine('仕、帅只能在九宫内活动，将帅不可照面。'),
            _RuleLine('兵、卒过河前只能向前，过河后可左右移动，永不后退。'),
            _RuleLine('被将军时必须应将；将死或困毙均判负。'),
            _RuleLine('连续六十回合无吃子判和；同一局面出现三次判和。'),
            _RuleLine('一方连续将军形成重复局面，判长将一方负。'),
            _RuleLine('点击己方棋子选中，再点目标位置落子。'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

class _RuleLine extends StatelessWidget {
  const _RuleLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
