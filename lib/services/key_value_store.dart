import 'package:shared_preferences/shared_preferences.dart';

/// Tiny on-phone storage for settings and the last results seen offline.
abstract class KeyValueStore {
  Future<String?> get(String key);
  Future<void> set(String key, String value);
}

class PrefsStore implements KeyValueStore {
  final SharedPreferences _p;
  PrefsStore(this._p);
  @override
  Future<String?> get(String key) async => _p.getString(key);
  @override
  Future<void> set(String key, String value) => _p.setString(key, value);
}

class MemoryKv implements KeyValueStore {
  final _m = <String, String>{};
  @override
  Future<String?> get(String key) async => _m[key];
  @override
  Future<void> set(String key, String value) async => _m[key] = value;
}
