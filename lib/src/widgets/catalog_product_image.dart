import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/category_visuals.dart';
import '../utils/product_images.dart';

/// Resolves a product's photo for display, in priority order:
/// 1. A remote [imageUrl] (e.g. Supabase Storage) -- the path every
///    non-grocery catalog category should use, so the app never has to
///    bundle thousands of local product photos.
/// 2. The legacy bundled-asset lookup by product name/category -- keeps
///    every already-seeded grocery item's photo working unchanged.
/// 3. A category-colored icon placeholder.
class CatalogProductImage extends StatelessWidget {
  const CatalogProductImage({
    super.key,
    required this.productName,
    this.category,
    this.imageUrl,
    this.size = 72,
    this.width,
    this.height,
    this.iconSize,
    this.borderRadius,
  });

  final String productName;
  final String? category;
  final String? imageUrl;

  /// Used for both width and height when [width]/[height] aren't given --
  /// the common square-thumbnail case.
  final double size;
  final double? width;
  final double? height;
  final double? iconSize;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final visual = categoryVisual(category);
    final radius = borderRadius ?? BorderRadius.circular(12);
    final w = width ?? size;
    final h = height ?? size;
    final placeholder = Container(
      width: w,
      height: h,
      color: visual.color.withValues(alpha: 0.1),
      child: Icon(visual.icon, color: visual.color, size: iconSize ?? w * 0.42),
    );

    final url = imageUrl?.trim();
    final Widget image = (url != null && url.isNotEmpty)
        ? CachedNetworkImage(
            imageUrl: url,
            width: w,
            height: h,
            fit: BoxFit.cover,
            placeholder: (context, _) => placeholder,
            errorWidget: (context, _, __) => _localOrPlaceholder(placeholder, w, h),
          )
        : _localOrPlaceholder(placeholder, w, h);

    return ClipRRect(borderRadius: radius, child: image);
  }

  Widget _localOrPlaceholder(Widget placeholder, double w, double h) {
    final asset = productImageAsset(productName: productName, category: category);
    if (asset == null) return placeholder;
    return Image.asset(
      asset,
      width: w,
      height: h,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}
