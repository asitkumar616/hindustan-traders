import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads owner-picked product photos to the public `catalog-products`
/// storage bucket (see supabase/add_catalog_phase2.sql for the bucket +
/// RLS). Only used for custom products -- catalog products already carry
/// an image_url copied from the shared master catalog.
class ImageUploadService {
  static SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Uploads [file] under this business's own folder (required by the
  /// storage RLS policy, which checks the first path segment against an
  /// active business_members row) and returns its public URL.
  static Future<String?> uploadProductImage({
    required String businessId,
    required File file,
  }) async {
    final client = _clientOrNull;
    if (client == null) return null;

    final extension = file.path.contains('.') ? file.path.split('.').last.toLowerCase() : 'jpg';
    final path = '$businessId/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await client.storage.from('catalog-products').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    return client.storage.from('catalog-products').getPublicUrl(path);
  }
}
