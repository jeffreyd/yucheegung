import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/jellyfin_auth.dart';
import '../models/jellyfin_server.dart';

class SettingsService {
  static const String _keyFirstRun = 'first_run';
  static const String _keyServer = 'jellyfin_server';
  static const String _keyAuth = 'jellyfin_auth';
  static const String _keySelectedLibraries = 'selected_libraries';
  static const String _keyDownloadLocation = 'download_location';
  static const String _keyDownloadedItems = 'downloaded_items';

  Future<bool> isFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFirstRun) ?? true;
  }

  Future<void> setFirstRunComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstRun, false);
  }

  Future<void> saveServer(JellyfinServer server) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(server.toJson());
    await prefs.setString(_keyServer, json);
  }

  Future<JellyfinServer?> getServer() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyServer);
    if (json == null) return null;

    final map = jsonDecode(json) as Map<String, dynamic>;
    return JellyfinServer.fromJson(map);
  }

  Future<void> saveAuth(JellyfinAuth auth) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(auth.toJson());
    await prefs.setString(_keyAuth, json);
  }

  Future<JellyfinAuth?> getAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyAuth);
    if (json == null) return null;

    final map = jsonDecode(json) as Map<String, dynamic>;
    return JellyfinAuth.fromStorageJson(map);
  }

  Future<void> saveSelectedLibraries(List<String> libraryIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keySelectedLibraries, libraryIds);
  }

  Future<List<String>> getSelectedLibraries() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keySelectedLibraries) ?? [];
  }

  Future<bool> hasSelectedLibraries() async {
    final libraries = await getSelectedLibraries();
    return libraries.isNotEmpty;
  }

  Future<void> saveDownloadLocation(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDownloadLocation, path);
  }

  Future<String?> getDownloadLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDownloadLocation);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServer);
    await prefs.remove(_keyAuth);
    await prefs.remove(_keySelectedLibraries);
    await prefs.remove(_keyDownloadLocation);
    await prefs.setBool(_keyFirstRun, true);
  }

  Future<void> clearServer() async {
    await clearAll();
  }
}
