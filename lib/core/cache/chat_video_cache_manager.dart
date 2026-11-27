import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk store for chat videos, kept apart from [appImageCacheManager] so a few
/// large clips never push hundreds of small images out of that cache.
final CacheManager chatVideoCacheManager = CacheManager(
  Config(
    'chatVideoCache',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 100,
  ),
);
