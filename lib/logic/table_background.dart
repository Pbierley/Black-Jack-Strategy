import 'dart:math' as math;

import 'package:flutter/material.dart';

const _gold = Color(0x66E8C872);

/// Resolution-independent felt, drawn at the device's native pixel density
/// so it stays sharp on any screen size.
class TableBackground extends StatelessWidget {
  const TableBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(child: CustomPaint(painter: _FeltPainter()));
  }
}

class _FeltPainter extends CustomPainter {
  const _FeltPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.25),
          radius: 1.15,
          colors: [Color(0xFF1E7A42), Color(0xFF0F5530), Color(0xFF06311A)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _FeltPainter oldDelegate) => false;
}

/// The printed "BLACKJACK PAYS 3 TO 2" / insurance arcs, laid out in the
/// widget tree so the player's cards always sit below them.
class TableMarkings extends StatelessWidget {
  const TableMarkings({super.key, required this.width});

  final double width;

  static double heightFor(double width) => _MarkingsGeometry(width).height;

  @override
  Widget build(BuildContext context) {
    final geometry = _MarkingsGeometry(width);
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, geometry.height),
        painter: _MarkingsPainter(geometry),
      ),
    );
  }
}

class _MarkingsGeometry {
  _MarkingsGeometry(this.width)
    : fontSize = (width * 0.03).clamp(11.0, 20.0).toDouble(),
      sag = (width * 0.06).clamp(16.0, 56.0).toDouble();

  static const _edgePadding = 4.0;

  final double width;
  final double fontSize;

  /// How far the middle of the arc dips below its ends.
  final double sag;

  double get bandWidth => fontSize * 2;
  double get headlineFontSize => fontSize * 1.25;
  double get headlineGap => fontSize * 0.4;

  double get height =>
      _edgePadding * 2 +
      bandWidth +
      math.max(sag, headlineGap + headlineFontSize * 1.2 + sag * 0.4);

  /// Radius of the circle whose chord spans [width] with the given [sag].
  double get radius => (width * width / 4 + sag * sag) / (2 * sag);

  Offset get center => Offset(width / 2, height - _edgePadding - radius);

  double get halfSweep => math.asin((width / 2 / radius).clamp(0.0, 1.0));
}

class _MarkingsPainter extends CustomPainter {
  const _MarkingsPainter(this.geometry);

  final _MarkingsGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    final linePaint = Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final r in [g.radius, g.radius - g.bandWidth]) {
      canvas.drawArc(
        Rect.fromCircle(center: g.center, radius: r),
        math.pi / 2 - g.halfSweep,
        g.halfSweep * 2,
        false,
        linePaint,
      );
    }

    final style = TextStyle(
      color: _gold,
      fontSize: g.fontSize,
      fontWeight: FontWeight.w600,
    );
    _drawArcText(
      canvas,
      'INSURANCE PAYS 2 TO 1',
      g.center,
      g.radius - g.bandWidth / 2 + g.fontSize / 2,
      style,
    );
    _drawArcText(
      canvas,
      'BLACKJACK PAYS 3 TO 2',
      g.center,
      g.radius - g.bandWidth - g.headlineGap,
      style.copyWith(fontSize: g.headlineFontSize),
    );
  }

  /// Draws [text] centred along the bottom of the circle at [center] with
  /// [radius], with each glyph's baseline sitting on the arc.
  void _drawArcText(
    Canvas canvas,
    String text,
    Offset center,
    double radius,
    TextStyle style,
  ) {
    final spacing = style.fontSize! * 0.25;
    final glyphs = [
      for (final char in text.characters)
        TextPainter(
          text: TextSpan(text: char, style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final totalWidth =
        glyphs.fold<double>(0, (sum, g) => sum + g.width) +
        spacing * (glyphs.length - 1);

    var angle = math.pi / 2 + totalWidth / radius / 2;
    for (final glyph in glyphs) {
      final glyphAngle = angle - glyph.width / radius / 2;
      canvas
        ..save()
        ..translate(
          center.dx + radius * math.cos(glyphAngle),
          center.dy + radius * math.sin(glyphAngle),
        )
        ..rotate(glyphAngle - math.pi / 2);
      glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height));
      canvas.restore();
      angle -= (glyph.width + spacing) / radius;
    }
  }

  @override
  bool shouldRepaint(covariant _MarkingsPainter oldDelegate) =>
      oldDelegate.geometry.width != geometry.width;
}
