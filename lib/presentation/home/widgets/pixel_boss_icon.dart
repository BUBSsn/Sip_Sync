import 'package:flutter/material.dart';

import '../../theme/liquid_tokens.dart';

/// Pixel-art retro alien sprite painter for the Defeat Dehydration Boss Raid card.
class PixelBossIcon extends StatelessWidget {
  const PixelBossIcon({
    super.key,
    this.size = 38.0,
    this.color = const Color(0xFF7C3AED),
    this.backgroundColor = const Color(0xFFEDE9FE),
  });

  final double size;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(LiquidTokens.radiusSm),
      ),
      padding: const EdgeInsets.all(7.0),
      child: CustomPaint(painter: _PixelAlienPainter(color: color)),
    );
  }
}

class _PixelAlienPainter extends CustomPainter {
  const _PixelAlienPainter({required this.color});

  final Color color;

  // 11x8 retro space invader matrix
  static const List<String> _sprite = [
    '..#.....#..',
    '...#...#...',
    '..#######..',
    '.##.###.##.',
    '###########',
    '#.#.###.#.#',
    '#.#.....#.#',
    '...##.##...',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cols = _sprite[0].length;
    final rows = _sprite.length;
    final pixelW = size.width / cols;
    final pixelH = size.height / rows;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int r = 0; r < rows; r++) {
      final line = _sprite[r];
      for (int c = 0; c < cols; c++) {
        if (line[c] == '#') {
          canvas.drawRect(
            Rect.fromLTWH(c * pixelW, r * pixelH, pixelW + 0.2, pixelH + 0.2),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelAlienPainter oldDelegate) =>
      oldDelegate.color != color;
}
