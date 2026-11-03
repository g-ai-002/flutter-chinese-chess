import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/engine/board_utils.dart';
import '../game/game_archive.dart';
import '../models/game_models.dart';
import '../providers/settings_provider.dart';
import '../services/log_service.dart';
import '../theme/app_theme.dart';
import '../theme/board_painting.dart';
import '../utils/constants.dart';
import 'game_page.dart';
import 'puzzle_page.dart';
import 'review_page.dart';
import 'settings_page.dart';
import 'widgets/board_preview.dart';
import 'widgets/entry_tile.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final modeCards = _modeCards(context, settings, colors);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF201B14), Color(0xFF121009)]
                : const [Color(0xFFFCF7EC), Color(0xFFF1E5CF)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 折叠屏展开约 600dp 起即可并排两张入口卡片。
              final twoColumns = constraints.maxWidth >= 600;
              final horizontal = constraints.maxWidth >= 900 ? 40.0 : 20.0;
              final contentWidth = math.min(
                constraints.maxWidth - horizontal * 2,
                780.0,
              );
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, constraints.maxHeight - 38),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 780),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TopBar(darkMode: settings.darkMode),
                          const SizedBox(height: 22),
                          _Hero(skin: settings.boardSkin),
                          const SizedBox(height: 30),
                          if (twoColumns)
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final card in modeCards)
                                  SizedBox(
                                    width: (contentWidth - 12) / 2,
                                    child: card,
                                  ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                for (var i = 0; i < modeCards.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 12),
                                  modeCards[i],
                                ],
                              ],
                            ),
                          const SizedBox(height: 24),
                          Text(
                            'v${AppConstants.version} · 本地运行，无需联网',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _startGame(
    BuildContext context,
    SettingsProvider settings,
    GameMode mode,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GamePage(
          mode: mode,
          difficulty: settings.difficulty,
          humanSide: mode == GameMode.vsAi ? settings.humanSide : red,
        ),
      ),
    );
  }

  void _openPuzzles(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PuzzlePage()));
  }

  /// 粘贴棋谱文本并复盘，解析失败时留在首页提示。
  Future<void> _importArchive(BuildContext context) async {
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
    LogService.info('导入棋谱: ${archive.title}, 共 ${archive.moveCount} 手');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewPage(
          title: archive.title,
          result: archive.result,
          moves: archive.moves,
          layout: archive.layout,
          startSide: archive.startSide,
        ),
      ),
    );
  }

  /// 首页四个模式入口，宽屏两列、窄屏堆叠都复用同一份定义。
  List<Widget> _modeCards(
    BuildContext context,
    SettingsProvider settings,
    ColorScheme colors,
  ) => [
    EntryTile(
      leading: EntryBadge(
        icon: Icons.smart_toy_outlined,
        accent: colors.primary,
      ),
      title: GameMode.vsAi.label,
      subtitle: '三档 AI 难度 · 可执黑后行',
      onTap: () => _startGame(context, settings, GameMode.vsAi),
    ),
    EntryTile(
      leading: EntryBadge(
        icon: Icons.people_alt_outlined,
        accent: colors.tertiary,
      ),
      title: GameMode.twoPlayers.label,
      subtitle: '同屏轮流落子 · 面对面手谈',
      onTap: () => _startGame(context, settings, GameMode.twoPlayers),
    ),
    EntryTile(
      leading: EntryBadge(icon: Icons.flag_outlined, accent: colors.secondary),
      title: GameMode.puzzle.label,
      subtitle: '八道杀法练习 · 限步取胜',
      onTap: () => _openPuzzles(context),
    ),
    EntryTile(
      leading: const EntryBadge(
        icon: Icons.history_edu_outlined,
        accent: appWood,
      ),
      title: '棋谱复盘',
      subtitle: '导入棋谱 · 逐手回放',
      onTap: () => _importArchive(context),
    ),
  ];
}

/// 导入棋谱弹窗：文本框自行持有控制器，关闭动画结束时一并释放。
class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final TextEditingController _input = TextEditingController();

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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.darkMode});

  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: colors.primary, width: 1.4),
          ),
          child: Text(
            '象',
            style: pieceTextStyle(fontSize: 20, color: colors.primary),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              'CHINESE CHESS',
              style: TextStyle(
                fontSize: 8.5,
                letterSpacing: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          tooltip: darkMode ? '切换浅色' : '切换深色',
          onPressed: () => settings.setDarkMode(!darkMode),
          icon: Icon(
            darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 21,
          ),
        ),
        IconButton(
          tooltip: '设置',
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
          icon: const Icon(Icons.settings_outlined, size: 21),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.skin});

  final BoardSkin skin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        BoardPreview(skin: skin),
        const SizedBox(height: 20),
        Text(
          '中国象棋',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 32,
            letterSpacing: 8,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _OrnamentLine(color: colors.outline),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '楚 河 · 漢 界',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  letterSpacing: 3,
                ),
              ),
            ),
            _OrnamentLine(color: colors.outline),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '落子无悔，方寸之间见乾坤',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _OrnamentLine extends StatelessWidget {
  const _OrnamentLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 36, height: 1, color: color.withValues(alpha: 0.9));
  }
}
