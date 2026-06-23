import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../eos/eos.dart';

class InvitationQrCard extends StatelessWidget {
  const InvitationQrCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.payload,
  });

  final String title;
  final String subtitle;
  final String payload;

  @override
  Widget build(BuildContext context) {
    return EosSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.eosText.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          SizedBox(height: context.eos.spacing.xxs),
          Text(subtitle, style: context.eosText.bodySmall),
          SizedBox(height: context.eos.spacing.md),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: EosRadius.input,
                border: Border.all(color: context.eosColors.outlineVariant),
              ),
              child: SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: _PseudoQrPainter(payload: payload),
                ),
              ),
            ),
          ),
          SizedBox(height: context.eos.spacing.sm),
          Text(
            payload,
            style: context.eosText.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PseudoQrPainter extends CustomPainter {
  _PseudoQrPainter({required this.payload});

  final String payload;
  static const _grid = 21;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _grid;
    final hash = payload.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    final random = math.Random(hash);

    final dark = Paint()..color = EosColors.ink;
    final light = Paint()..color = Colors.white;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), light);

    void drawFinder(int row, int col) {
      for (var r = 0; r < 7; r++) {
        for (var c = 0; c < 7; c++) {
          final outer = r == 0 || r == 6 || c == 0 || c == 6;
          final inner = r >= 2 && r <= 4 && c >= 2 && c <= 4;
          if (outer || inner) {
            canvas.drawRect(
              Rect.fromLTWH((col + c) * cell, (row + r) * cell, cell, cell),
              dark,
            );
          }
        }
      }
    }

    drawFinder(0, 0);
    drawFinder(0, _grid - 7);
    drawFinder(_grid - 7, 0);

    for (var row = 0; row < _grid; row++) {
      for (var col = 0; col < _grid; col++) {
        if (_isReserved(row, col)) continue;
        if (random.nextDouble() > 0.52) {
          canvas.drawRect(Rect.fromLTWH(col * cell, row * cell, cell, cell), dark);
        }
      }
    }
  }

  bool _isReserved(int row, int col) {
    if (row < 8 && col < 8) return true;
    if (row < 8 && col >= _grid - 8) return true;
    if (row >= _grid - 8 && col < 8) return true;
    return false;
  }

  @override
  bool shouldRepaint(covariant _PseudoQrPainter oldDelegate) => oldDelegate.payload != payload;
}
