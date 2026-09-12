import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final bool showLabel;

  const BrandLogo({super.key, this.size = 72, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/branding/logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
        if (showLabel) ...[
          const SizedBox(height: 14),
          Text(
            'OdiaTraders',
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
