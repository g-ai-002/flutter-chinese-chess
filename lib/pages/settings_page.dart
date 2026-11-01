import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/file_system_service.dart';
import '../services/log_service.dart';
import '../utils/constants.dart';
import '../utils/platform_info.dart';
import 'widgets/preference_pickers.dart';
import 'widgets/section_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                SectionCard(
                  title: '对局',
                  icon: Icons.tune_rounded,
                  children: [
                    DifficultyPicker(settings: settings),
                    const SizedBox(height: 16),
                    SidePicker(settings: settings, label: '默认执子'),
                  ],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: '外观与提示',
                  icon: Icons.palette_outlined,
                  children: [
                    _SwitchRow(
                      title: '深色模式',
                      subtitle: '暖墨底色，夜间对弈更舒适',
                      value: settings.darkMode,
                      onChanged: settings.setDarkMode,
                    ),
                    const SizedBox(height: 10),
                    _SwitchRow(
                      title: '显示可走位置',
                      subtitle: '选中棋子后标出所有合法落点',
                      value: settings.showHints,
                      onChanged: settings.setShowHints,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: '运行日志',
                  icon: Icons.receipt_long_outlined,
                  children: [
                    FutureBuilder<String>(
                      future: FileSystemService.instance.getLogRootPath(),
                      builder: (context, snapshot) {
                        final path = snapshot.data ?? '';
                        final text = path.isEmpty
                            ? (isDesktopPlatform
                                  ? '正在读取日志目录…'
                                  : '当前平台日志仅保留在内存中')
                            : path;
                        return SelectableText(
                          text,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontFamily: 'Consolas',
                            fontFamilyFallback: const ['Menlo', 'monospace'],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showLogs(context),
                          icon: const Icon(Icons.article_outlined, size: 17),
                          label: const Text('查看日志'),
                        ),
                        if (isDesktopPlatform)
                          OutlinedButton.icon(
                            onPressed: () async {
                              final path = await FileSystemService.instance
                                  .getLogRootPath();
                              final ok = await FileSystemService.instance
                                  .openDirectory(path);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok ? '已打开日志目录' : '无法打开日志目录'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.folder_open, size: 17),
                            label: const Text('打开目录'),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: '关于',
                  icon: Icons.info_outline,
                  children: [
                    const _AboutRow(
                      label: '版本',
                      value: 'v${AppConstants.version}',
                    ),
                    const SizedBox(height: 8),
                    const _AboutRow(label: '引擎', value: 'Flutter + Flame'),
                    const SizedBox(height: 8),
                    const _AboutRow(
                      label: '平台',
                      value: 'Android / Windows / Web',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '棋谱采用中文传统记法，人机对战由本地 Alpha-Beta 搜索驱动，无需联网。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogs(BuildContext context) {
    final lines = LogService.getRecentLogs(300);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 680,
          height: 480,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                child: Row(
                  children: [
                    Text(
                      '最近日志',
                      style: Theme.of(dialogContext).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),
              Divider(
                color: Theme.of(dialogContext).colorScheme.outline
                    .withValues(alpha: 0.5),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Theme.of(dialogContext)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: SelectableText(
                      lines.isEmpty ? '暂无日志' : lines.join('\n'),
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.55,
                        color: Theme.of(dialogContext).colorScheme.onSurface,
                        fontFamily: 'Consolas',
                        fontFamilyFallback: const ['Menlo', 'monospace'],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: colors.primary,
        ),
      ],
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
