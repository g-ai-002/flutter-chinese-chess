import 'package:flutter/material.dart';

import '../game/game_archive.dart';
import '../models/saved_game.dart';
import '../services/file_system_service.dart';
import '../services/game_history_service.dart';
import '../services/log_service.dart';
import '../utils/formatters.dart';
import 'review_page.dart';

/// 棋谱库：最近 20 局回放，可导入、导出、删除或进入复盘。
class GameHistoryPage extends StatelessWidget {
  const GameHistoryPage({super.key});

  void _openReview(BuildContext context, SavedGame game) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewPage(
          title: game.title,
          result: game.result,
          moves: game.moves,
          layout: game.layout,
          startSide: game.startSide,
          date: game.endedAt,
        ),
      ),
    );
  }

  /// 粘贴或从已导出的文件导入棋谱，成功后写入棋谱库并直接复盘。
  Future<void> _import(BuildContext context) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (text == null || text.trim().isEmpty) return;

    final archive = GameArchive.decode(text);
    if (!context.mounted) return;
    if (archive == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('棋谱无法解析，请检查文本是否完整')));
      return;
    }
    final game = SavedGame.fromArchive(archive);
    await GameHistoryService.instance.record(game);
    if (!context.mounted) return;
    LogService.info('导入棋谱: ${game.title}, 共 ${game.moveCount} 手');
    _openReview(context, game);
  }

  Future<void> _delete(BuildContext context, SavedGame game) async {
    final confirmed = await _confirm(
      context,
      title: '删除这局棋谱？',
      message: '「${game.title}」的回放将从棋谱库移除。',
      confirmLabel: '删除',
    );
    if (!confirmed) return;
    await GameHistoryService.instance.remove(game.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('棋谱已删除')));
  }

  Future<void> _clear(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: '清空棋谱？',
      message: '最近的对局回放将全部删除，此操作无法撤销。',
      confirmLabel: '清空',
    );
    if (!confirmed) return;
    await GameHistoryService.instance.clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('棋谱已清空')));
  }

  @override
  Widget build(BuildContext context) {
    final service = GameHistoryService.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('棋谱'),
        actions: [
          IconButton(
            tooltip: '导入棋谱',
            onPressed: () => _import(context),
            icon: const Icon(Icons.file_open_outlined, size: 21),
          ),
          ListenableBuilder(
            listenable: service,
            builder: (context, _) => IconButton(
              tooltip: '清空棋谱',
              onPressed: service.isEmpty ? null : () => _clear(context),
              icon: const Icon(Icons.delete_outline, size: 21),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: service,
          builder: (context, _) {
            final records = service.records;
            if (records.isEmpty) {
              return _EmptyState(onImport: () => _import(context));
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final game = records[index];
                    return _SavedGameTile(
                      game: game,
                      onTap: () => _openReview(context, game),
                      onDelete: () => _delete(context, game),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 46,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '还没有棋谱',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '完成一局对战后，这里会保留最近 20 局回放',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.file_open_outlined, size: 17),
            label: const Text('导入棋谱'),
          ),
        ],
      ),
    );
  }
}

class _SavedGameTile extends StatelessWidget {
  const _SavedGameTile({
    required this.game,
    required this.onTap,
    required this.onDelete,
  });

  final SavedGame game;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final finished = game.result != null && game.result!.isNotEmpty;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.menu_book_outlined,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatDateTime(game.endedAt)} · ${game.moveCount} 手',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      game.resultLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: finished
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '删除棋谱',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 19),
              ),
              Icon(Icons.chevron_right, size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// 导入弹窗：粘贴文本，或直接选取应用导出目录里的棋谱文件。
class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final TextEditingController _input = TextEditingController();
  List<String> _files = const [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final files = await FileSystemService.instance.listRecordFiles();
    if (!mounted || files.isEmpty) return;
    setState(() => _files = files);
  }

  Future<void> _pickFile(String name) async {
    final text = await FileSystemService.instance.readRecordFile(name);
    if (!mounted || text == null) return;
    setState(() {
      _input.text = text;
      _input.selection = TextSelection.collapsed(offset: text.length);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('导入棋谱'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '粘贴导出的棋谱文本，也支持「1. 炮二平五 马8进7」这类纯记法。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '从已导出的文件导入',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _files.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => ActionChip(
                    label: Text(
                      _files[index],
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: () => _pickFile(_files[index]),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _input,
              minLines: 5,
              maxLines: 8,
              style: theme.textTheme.bodySmall,
              decoration: const InputDecoration(
                hintText: '在此粘贴棋谱…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_input.text),
          child: const Text('开始复盘'),
        ),
      ],
    );
  }
}
