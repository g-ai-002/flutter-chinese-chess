import 'package:flutter/material.dart';

import '../../providers/settings_provider.dart';
import '../../theme/board_painting.dart';
import '../../theme/board_skin.dart';
import '../../utils/constants.dart';

/// 棋盘皮肤选择器：每个选项带一块迷你棋盘预览。
class SkinPicker extends StatelessWidget {
  const SkinPicker({super.key, required this.settings});

  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final current = settings.boardSkin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('棋盘皮肤', style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(
              current.description,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final skin in kBoardSkins)
              _SkinTile(
                skin: skin,
                selected: skin.id == current.id,
                onTap: () => settings.setBoardSkin(skin),
              ),
          ],
        ),
      ],
    );
  }
}

class _SkinTile extends StatelessWidget {
  const _SkinTile({
    required this.skin,
    required this.selected,
    required this.onTap,
  });

  final BoardSkin skin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${skin.name}皮肤',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 84,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? colors.primaryContainer.withValues(alpha: 0.35)
                : Colors.transparent,
            border: Border.all(
              color: selected ? colors.primary : colors.outline,
              width: selected ? 1.6 : 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: CustomPaint(
                  size: const Size(68, 52),
                  painter: _SkinSwatchPainter(skin),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                skin.name,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.primary : colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkinSwatchPainter extends CustomPainter {
  const _SkinSwatchPainter(this.skin);

  final BoardSkin skin;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = skin.gradient.createShader(rect));

    const inset = 8.0;
    final stepX = (size.width - inset * 2) / 4;
    final stepY = (size.height - inset * 2) / 4;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = skin.line.withValues(alpha: 0.7);
    for (var i = 0; i <= 4; i++) {
      final x = inset + stepX * i;
      canvas.drawLine(
        Offset(x, inset),
        Offset(x, size.height - inset),
        linePaint,
      );
      final y = inset + stepY * i;
      canvas.drawLine(
        Offset(inset, y),
        Offset(size.width - inset, y),
        linePaint,
      );
    }

    paintPieceDisc(
      canvas,
      center: Offset(size.width / 2, size.height / 2),
      radius: 9,
      face: skin.redFace,
      borderWidth: 1,
      label: TextPainter(
        text: TextSpan(
          text: '帅',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: skin.redFace.ink,
            fontFamily: 'KaiTi',
            fontFamilyFallback: kKaiFontFallback,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  @override
  bool shouldRepaint(covariant _SkinSwatchPainter oldDelegate) =>
      oldDelegate.skin != skin;
}
