class CacheEntry<T> {
  final T data;
  final DateTime cachedAt;
  final Duration ttl;

  CacheEntry(this.data, {Duration? ttl})
      : cachedAt = DateTime.now(),
        ttl = ttl ?? const Duration(minutes: 5);

  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;
}

/// In-memory short-lived cache (5-minute TTL by default) for high-frequency queries
/// (Dashboard stats, Low stock counts, Analytics KPIs) to eliminate DB overhead.
class QueryCacheService {
  QueryCacheService._();
  static final QueryCacheService instance = QueryCacheService._();

  final Map<String, CacheEntry<dynamic>> _cache = {};

  /// Gets cached value if valid and not expired; returns null if missing or expired.
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.data as T?;
  }

  /// Sets or updates a cached query result with TTL.
  void set<T>(String key, T value, {Duration? ttl}) {
    _cache[key] = CacheEntry<T>(value, ttl: ttl);
  }

  /// Invalidates a specific cache key.
  void invalidate(String key) {
    _cache.remove(key);
  }

  /// Invalidates all cache keys starting with a given prefix (e.g. "dashboard_").
  void invalidatePrefix(String prefix) {
    _cache.removeWhere((k, _) => k.startsWith(prefix));
  }

  /// Wipes all cached queries.
  void clear() {
    _cache.clear();
  }
}
