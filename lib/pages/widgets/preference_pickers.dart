import 'package:flutter/material.dart';

import '../../game/engine/board_utils.dart';
import '../../models/game_models.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import 'choice_pill.dart';

/// 难度选择：首页「对局设置」与设置页共用。
class DifficultyPicker extends StatelessWidget {
  const DifficultyPicker({
    super.key,
    required this.settings,
    this.label = 'AI 难度',
  });

  final SettingsProvider settings;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _PickerGroup(
      label: label,
      children: [
        for (final difficulty in Difficulty.values)
          ChoicePill(
            label: difficulty.label,
            selected: settings.difficulty == difficulty,
            accent: colors.primary,
            onTap: () => settings.setDifficulty(difficulty),
          ),
      ],
    );
  }
}

/// 先后手选择：首页与设置页共用。
class SidePicker extends StatelessWidget {
  const SidePicker({super.key, required this.settings, this.label = '先后手'});

  final SettingsProvider settings;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _PickerGroup(
      label: label,
      children: [
        ChoicePill(
          label: '执红先行',
          selected: settings.humanSide == red,
          accent: appRed,
          onTap: () => settings.setHumanSide(red),
        ),
        ChoicePill(
          label: '执黑后行',
          selected: settings.humanSide == black,
          accent: appBlack,
          onTap: () => settings.setHumanSide(black),
        ),
      ],
    );
  }
}

/// 棋钟方案选择：首页与设置页共用。
class TimeControlPicker extends StatelessWidget {
  const TimeControlPicker({
    super.key,
    required this.settings,
    this.label = '棋钟',
  });

  final SettingsProvider settings;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _PickerGroup(
      label: label,
      children: [
        for (final control in TimeControl.values)
          ChoicePill(
            label: control.label,
            selected: settings.timeControl == control,
            accent: colors.primary,
            onTap: () => settings.setTimeControl(control),
          ),
      ],
    );
  }
}

/// 偏好选择器的统一骨架：小标题 + 一行可换行的胶囊选项。
class _PickerGroup extends StatelessWidget {
  const _PickerGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}
