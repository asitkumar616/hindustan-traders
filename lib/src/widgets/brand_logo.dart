import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final bool showLabel;

  const BrandLogo({super.key, this.size = 72, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, Color.alphaBlend(Colors.white.withValues(alpha: 0.1), primary)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: size * 0.13,
                right: size * 0.13,
                top: size * 0.14,
                bottom: size * 0.16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(size * 0.18),
                  ),
                ),
              ),
              Icon(Icons.storefront_rounded, size: size * 0.48, color: primary),
              Positioned(
                bottom: size * 0.14,
                left: size * 0.22,
                right: size * 0.22,
                child: Container(
                  height: size * 0.08,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(size),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 14),
          Text(
            'Hindustan Traders',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
          ),
        ],
      ],
    );
  }
}