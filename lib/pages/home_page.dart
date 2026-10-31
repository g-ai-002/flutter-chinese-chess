import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game_models.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import 'game_page.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

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
              final wide = constraints.maxWidth >= 720;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  wide ? 40 : 20,
                  14,
                  wide ? 40 : 20,
                  24,
                ),
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
                          const _Hero(),
                          const SizedBox(height: 30),
                          if (wide)
                            Row(
                              children: [
                                Expanded(
                                  child: _ModeCard(
                                    icon: Icons.smart_toy_outlined,
                                    title: GameMode.vsAi.label,
                                    subtitle: '三档 AI 难度 · 可执黑后行',
                                    accent: colors.primary,
                                    onTap: () => _startGame(
                                      context,
                                      settings,
                                      GameMode.vsAi,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _ModeCard(
                                    icon: Icons.people_alt_outlined,
                                    title: GameMode.twoPlayers.label,
                                    subtitle: '同屏轮流落子 · 面对面手谈',
                                    accent: colors.tertiary,
                                    onTap: () => _startGame(
                                      context,
                                      settings,
                                      GameMode.twoPlayers,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _ModeCard(
                              icon: Icons.smart_toy_outlined,
                              title: GameMode.vsAi.label,
                              subtitle: '三档 AI 难度 · 可执黑后行',
                              accent: colors.primary,
                              onTap: () =>
                                  _startGame(context, settings, GameMode.vsAi),
                            ),
                            const SizedBox(height: 12),
                            _ModeCard(
                              icon: Icons.people_alt_outlined,
                              title: GameMode.twoPlayers.label,
                              subtitle: '同屏轮流落子 · 面对面手谈',
                              accent: colors.tertiary,
                              onTap: () => _startGame(
                                context,
                                settings,
                                GameMode.twoPlayers,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          _OptionsPanel(settings: settings),
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
          humanSide: mode == GameMode.vsAi ? settings.humanSide : 0,
        ),
      ),
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.primary,
              fontFamily: 'KaiTi',
              fontFamilyFallback: const [
                'STKaiti',
                'SimSun',
                'Noto Serif CJK SC',
              ],
            ),
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
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        const _BoardPreview(),
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

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outline.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionsPanel extends StatelessWidget {
  const _OptionsPanel({required this.settings});

  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 16),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: colors.primary),
              const SizedBox(width: 7),
              Text('对局设置', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                '自动记忆',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'AI 难度',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final difficulty in Difficulty.values)
                _Pill(
                  label: difficulty.label,
                  selected: settings.difficulty == difficulty,
                  accent: colors.primary,
                  onTap: () => settings.setDifficulty(difficulty),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '先后手',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                label: '执红先行',
                selected: settings.humanSide == 0,
                accent: appRed,
                onTap: () => settings.setHumanSide(0),
              ),
              _Pill(
                label: '执黑后行',
                selected: settings.humanSide == 1,
                accent: const Color(0xFF4A5550),
                onTap: () => settings.setHumanSide(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.55) : colors.outline,
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? accent : colors.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 首页装饰：一张缩小的木纹棋盘，黑白双方各立一子。
class _BoardPreview extends StatelessWidget {
  const _BoardPreview();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CustomPaint(
        size: const Size(158, 174),
        painter: _BoardPreviewPainter(
          lineColor: appWood,
          redColor: appRed,
          blackColor: const Color(0xFF333A36),
          surfaceColor: colors.surface,
        ),
      ),
    );
  }
}

class _BoardPreviewPainter extends CustomPainter {
  const _BoardPreviewPainter({
    required this.lineColor,
    required this.redColor,
    required this.blackColor,
    required this.surfaceColor,
  });

  final Color lineColor;
  final Color redColor;
  final Color blackColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6E6C6), Color(0xFFE2C592)],
        ).createShader(rect),
    );

    const pad = 16.0;
    final cell = (size.width - pad * 2) / 8;
    final top = (size.height - cell * 9) / 2;
    const left = pad;

    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.55)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    for (var row = 0; row < 10; row++) {
      final y = top + row * cell;
      canvas.drawLine(Offset(left, y), Offset(left + cell * 8, y), linePaint);
    }
    for (var col = 0; col < 9; col++) {
      final x = left + col * cell;
      if (col == 0 || col == 8) {
        canvas.drawLine(Offset(x, top), Offset(x, top + cell * 9), linePaint);
      } else {
        canvas.drawLine(Offset(x, top), Offset(x, top + cell * 4), linePaint);
        canvas.drawLine(
          Offset(x, top + cell * 5),
          Offset(x, top + cell * 9),
          linePaint,
        );
      }
    }

    for (final row in [0, 7]) {
      final y0 = top + row * cell;
      final y1 = y0 + cell * 2;
      canvas.drawLine(
        Offset(left + cell * 3, y0),
        Offset(left + cell * 5, y1),
        linePaint,
      );
      canvas.drawLine(
        Offset(left + cell * 5, y0),
        Offset(left + cell * 3, y1),
        linePaint,
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(left, top, cell * 8, cell * 9),
      linePaint..strokeWidth = 1.6,
    );

    _drawPiece(
      canvas,
      Offset(left + cell * 4, top + cell * 9),
      '帅',
      redColor,
      cell,
    );
    _drawPiece(canvas, Offset(left + cell * 4, top), '将', blackColor, cell);
  }

  void _drawPiece(
    Canvas canvas,
    Offset center,
    String text,
    Color color,
    double cell,
  ) {
    final radius = cell * 0.52;
    canvas.drawCircle(
      center.translate(0, 1.5),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [surfaceColor, const Color(0xFFEBD6AD)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color.withValues(alpha: 0.85),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: cell * 0.72,
          fontWeight: FontWeight.w700,
          color: color,
          fontFamily: 'KaiTi',
          fontFamilyFallback: const ['STKaiti', 'SimSun', 'Noto Serif CJK SC'],
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BoardPreviewPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.redColor != redColor ||
      oldDelegate.blackColor != blackColor ||
      oldDelegate.surfaceColor != surfaceColor;
}
