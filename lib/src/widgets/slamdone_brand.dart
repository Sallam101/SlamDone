import 'dart:math' as math;

import 'package:flutter/material.dart';

/// SlamDone product identity based on the approved S + checkmark reference.
class SlamDoneBrand extends StatelessWidget {
  const SlamDoneBrand({
    super.key,
    this.compact = false,
    this.showSlogan = true,
    this.inverse = false,
    this.backgroundColor,
  });

  final bool compact;
  final bool showSlogan;
  final bool inverse;
  final Color? backgroundColor;

  static const slogan = 'STOP PLANNING. START FINISHING.';
  static const brandGreen = Color(0xFF78D12F);
  static const brandBlack = Color(0xFF090D12);

  @override
  Widget build(BuildContext context) {
    final effectiveBackground = backgroundColor ?? Theme.of(context).colorScheme.surface;
    final brightness = ThemeData.estimateBrightnessForColor(effectiveBackground);
    final lightInk = inverse || brightness == Brightness.dark;
    final slamColor = lightInk ? Colors.white : brandBlack;
    final markSize = compact ? 29.0 : 38.0;
    final nameStyle = (compact
            ? Theme.of(context).textTheme.titleMedium
            : Theme.of(context).textTheme.titleLarge)
        ?.copyWith(
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: -1.0,
          height: 1,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SlamDoneMark(size: markSize, inverse: lightInk),
        SizedBox(width: compact ? 7 : 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Slam',
                      style: nameStyle?.copyWith(color: slamColor),
                    ),
                    TextSpan(
                      text: 'Done',
                      style: nameStyle?.copyWith(color: brandGreen),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (showSlogan) ...[
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'STOP PLANNING. ',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: slamColor.withValues(alpha: .78),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                        ),
                        TextSpan(
                          text: 'START FINISHING.',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: brandGreen,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SlamDoneMark extends StatelessWidget {
  const SlamDoneMark({
    super.key,
    this.size = 36,
    this.inverse = false,
    this.boxed = false,
  });

  final double size;
  final bool inverse;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SlamDoneMarkPainter(
          inverse: inverse,
          boxed: boxed,
        ),
      ),
    );
  }
}

class _SlamDoneMarkPainter extends CustomPainter {
  const _SlamDoneMarkPainter({required this.inverse, required this.boxed});

  final bool inverse;
  final bool boxed;

  @override
  void paint(Canvas canvas, Size size) {
    final green = SlamDoneBrand.brandGreen;
    final dark = SlamDoneBrand.brandBlack;
    final white = Colors.white;
    final primary = inverse ? white : dark;

    if (boxed) {
      final box = Paint()..color = dark;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.width * .23),
        ),
        box,
      );
    }

    final ink = boxed ? white : primary;
    final line = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.6, size.width * .055);

    // Speed lines from the approved mark.
    for (final data in const <(double, double, double, bool)>[
      (.05, .28, .20, false),
      (.02, .41, .25, false),
      (.08, .58, .20, true),
      (.12, .70, .15, true),
    ]) {
      line.color = data.$4 ? green : ink;
      canvas.drawLine(
        Offset(size.width * data.$1, size.height * data.$2),
        Offset(size.width * data.$3, size.height * data.$2),
        line,
      );
    }

    // Heavy italic S. TextPainter gives the mark the same speed-logo character
    // as the reference while remaining crisp at every Flutter scale.
    final sPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: 'S',
        style: TextStyle(
          color: ink,
          fontSize: size.width * .69,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          height: .9,
          letterSpacing: -size.width * .055,
        ),
      ),
    )..layout();
    canvas.save();
    canvas.translate(size.width * .25, size.height * .08);
    canvas.skew(-.10, 0);
    sPainter.paint(canvas, Offset.zero);
    canvas.restore();

    // Long green check sweeping below the S.
    final check = Paint()
      ..color = green
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..strokeWidth = size.width * .105;
    final path = Path()
      ..moveTo(size.width * .30, size.height * .67)
      ..lineTo(size.width * .47, size.height * .82)
      ..lineTo(size.width * .83, size.height * .47);
    canvas.drawPath(path, check);
  }

  @override
  bool shouldRepaint(covariant _SlamDoneMarkPainter oldDelegate) =>
      oldDelegate.inverse != inverse || oldDelegate.boxed != boxed;
}
