import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ApiCacheEntry {
  const ApiCacheEntry({
    required this.savedAt,
    required this.statusCode,
    required this.data,
  });

  final DateTime savedAt;
  final int statusCode;
  final dynamic data;

  bool isFresh(Duration ttl) => DateTime.now().difference(savedAt) < ttl;

  Map<String, dynamic> toJson() => {
        'savedAt': savedAt.toIso8601String(),
        'statusCode': statusCode,
        'data': data,
      };

  factory ApiCacheEntry.fromJson(Map<String, dynamic> json) {
    return ApiCacheEntry(
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      statusCode: json['statusCode'] is int ? json['statusCode'] as int : 200,
      data: json['data'],
    );
  }
}

/// In-memory + SharedPreferences cache for GET API responses.
class ApiCache {
  ApiCache._();
  static final ApiCache instance = ApiCache._();

  static const _prefix = 'api_cache_v1_';
  static const _indexKey = 'api_cache_v1_index';
  static const _maxPersistedChars = 700000;

  final Map<String, ApiCacheEntry> _memory = {};
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<ApiCacheEntry?> get(String key) async {
    final mem = _memory[key];
    if (mem != null) return mem;
    await init();
    final raw = _prefs?.getString('$_prefix$key');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final entry = ApiCacheEntry.fromJson(decoded);
      _memory[key] = entry;
      return entry;
    } catch (_) {
      return null;
    }
  }

  Future<void> set(String key, ApiCacheEntry entry) async {
    _memory[key] = entry;
    await init();
    final encoded = jsonEncode(entry.toJson());
    if (encoded.length > _maxPersistedChars) return;
    await _prefs?.setString('$_prefix$key', encoded);
    final index = _prefs?.getStringList(_indexKey) ?? <String>[];
    if (!index.contains(key)) {
      index.add(key);
      await _prefs?.setStringList(_indexKey, index);
    }
  }

  Future<void> clear() async {
    _memory.clear();
    await init();
    final index = _prefs?.getStringList(_indexKey) ?? <String>[];
    for (final key in index) {
      await _prefs?.remove('$_prefix$key');
    }
    await _prefs?.remove(_indexKey);
  }
}
