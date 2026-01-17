class TtlCache<T> {
  TtlCache(this.ttl);

  final Duration ttl;
  final Map<String, _TtlEntry<T>> _store = {};

  T? get(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _store.remove(key);
      return null;
    }
    return entry.value;
  }

  void set(String key, T value) {
    _store[key] = _TtlEntry(value, DateTime.now().add(ttl));
  }

  void clear() => _store.clear();
}

class _TtlEntry<T> {
  _TtlEntry(this.value, this.expiresAt);

  final T value;
  final DateTime expiresAt;
}
