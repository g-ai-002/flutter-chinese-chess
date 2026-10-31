import 'package:flutter/material.dart';

import '../../models/move_record.dart';

/// 棋谱列表：按回合成对展示红黑双方的记法，新棋子自动滚到底部。
class MoveList extends StatefulWidget {
  const MoveList({
    super.key,
    required this.history,
    this.padding = EdgeInsets.zero,
  });

  final List<MoveRecord> history;
  final EdgeInsets padding;

  @override
  State<MoveList> createState() => _MoveListState();
}

class _MoveListState extends State<MoveList> {
  final ScrollController _scroll = ScrollController();
  late int _lastLength;

  @override
  void initState() {
    super.initState();
    _lastLength = widget.history.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void didUpdateWidget(covariant MoveList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // history 是同一个可变列表，不能依赖 oldWidget 的长度比较。
    if (widget.history.length != _lastLength) {
      _lastLength = widget.history.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (widget.history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.grid_on,
              size: 30,
              color: colors.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 10),
            Text(
              '尚未落子',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final rows = (widget.history.length + 1) ~/ 2;
    return ListView.builder(
      controller: _scroll,
      padding: widget.padding,
      itemCount: rows,
      itemBuilder: (context, row) {
        final redIndex = row * 2;
        final blackIndex = redIndex + 1;
        final red = widget.history[redIndex];
        final black = blackIndex < widget.history.length
            ? widget.history[blackIndex]
            : null;
        final lastIndex = widget.history.length - 1;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colors.outline.withValues(alpha: 0.45),
                width: 0.6,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '${row + 1}.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: _NotationText(
                  record: red,
                  highlight: redIndex == lastIndex,
                ),
              ),
              Expanded(
                child: black == null
                    ? const SizedBox.shrink()
                    : _NotationText(
                        record: black,
                        highlight: blackIndex == lastIndex,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotationText extends StatelessWidget {
  const _NotationText({required this.record, required this.highlight});

  final MoveRecord record;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Text(
      record.notation,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: highlight ? colors.primary : colors.onSurface,
        fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }
}
