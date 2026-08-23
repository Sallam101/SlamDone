import 'package:flutter/material.dart';

class SlamDoneBrand extends StatelessWidget {
  const SlamDoneBrand({
    super.key,
    this.compact = false,
    this.showSlogan = true,
  });

  final bool compact;
  final bool showSlogan;

  static const slogan = 'Plan • Focus • Finish';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final markSize = compact ? 28.0 : 34.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: markSize,
          height: markSize,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, scheme.tertiary],
            ),
            borderRadius: BorderRadius.circular(markSize * .28),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: .22),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.bolt_rounded,
                size: markSize * .62,
                color: scheme.onPrimary,
              ),
              Positioned(
                right: markSize * .04,
                bottom: markSize * .03,
                child: Container(
                  width: markSize * .40,
                  height: markSize * .40,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.done_rounded,
                    size: markSize * .30,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SlamDone',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (compact
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.titleLarge)
                    ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.4),
              ),
              if (showSlogan)
                Text(
                  slogan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .35,
                      ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
