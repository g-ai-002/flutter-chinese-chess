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
  return _showResultDialog(
    context,
    icon: result.isDraw
        ? Icons.handshake_outlined
        : Icons.emoji_events_outlined,
    title: result.title,
    message: result.reason,
    note: '共 $moveCount 手',
    actions: [
      _ResultAction(
        label: '返回首页',
        onPressed: () => Navigator.of(context).pop(),
      ),
      if (onReview != null) _ResultAction(label: '复盘', onPressed: onReview),
      _ResultAction(
        label: '再来一局',
        style: _ActionStyle.filled,
        onPressed: onRestart,
      ),
    ],
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
  return _showResultDialog(
    context,
    icon: cleared ? Icons.emoji_events_outlined : Icons.hourglass_bottom,
    title: cleared ? '挑战成功' : '挑战失败',
    message: cleared ? '于第 $moves 步将死黑方' : reason,
    note: '本关限 $mateIn 步',
    actions: [
      _ResultAction(
        label: '返回列表',
        onPressed: () => Navigator.of(context).pop(),
      ),
      if (cleared && onNext != null)
        _ResultAction(
          label: '下一关',
          style: _ActionStyle.outlined,
          onPressed: onNext,
        ),
      _ResultAction(
        label: cleared ? '再来一次' : '再试一次',
        style: _ActionStyle.filled,
        onPressed: onRetry,
      ),
    ],
  );
}

enum _ActionStyle { text, outlined, filled }

/// 结果弹窗的一个动作：点击后先关闭弹窗，再执行回调。
class _ResultAction {
  const _ResultAction({
    required this.label,
    required this.onPressed,
    this.style = _ActionStyle.text,
  });

  final String label;
  final VoidCallback onPressed;
  final _ActionStyle style;
}

/// 终局与残局共用的结果弹窗骨架。
Future<void> _showResultDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String note,
  required List<_ResultAction> actions,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      void run(_ResultAction action) {
        Navigator.of(dialogContext).pop();
        action.onPressed();
      }

      return PopScope(
        canPop: false,
        child: AlertDialog(
          icon: Icon(icon, size: 36, color: theme.colorScheme.primary),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 6),
              Text(note, style: theme.textTheme.bodySmall),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            for (final action in actions)
              switch (action.style) {
                _ActionStyle.filled => FilledButton(
                  onPressed: () => run(action),
                  child: Text(action.label),
                ),
                _ActionStyle.outlined => OutlinedButton(
                  onPressed: () => run(action),
                  child: Text(action.label),
                ),
                _ActionStyle.text => TextButton(
                  onPressed: () => run(action),
                  child: Text(action.label),
                ),
              },
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
            _RuleLine('限时对局中本方棋钟走完即超时判负。'),
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
