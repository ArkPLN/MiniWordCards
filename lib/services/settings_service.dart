import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置服务 - 管理应用设置状态
class SettingsService extends ChangeNotifier {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyUseOnlineDictionary = 'use_online_dictionary';
  static const String _keyDeletedDictionaryUrls = 'deleted_dictionary_urls';
  static const String _keyEnableLazyLoadOptimization =
      'enable_lazy_load_optimization';

  ThemeMode _themeMode = ThemeMode.system;
  bool _useOnlineDictionary = true;
  bool _enableLazyLoadOptimization = true;
  Set<String> _deletedDictionaryUrls = {};

  ThemeMode get themeMode => _themeMode;
  bool get useOnlineDictionary => _useOnlineDictionary;
  bool get enableLazyLoadOptimization => _enableLazyLoadOptimization;
  Set<String> get deletedDictionaryUrls =>
      Set.unmodifiable(_deletedDictionaryUrls);

  SettingsService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final themeModeIndex = prefs.getInt(_keyThemeMode);
    if (themeModeIndex != null && themeModeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeModeIndex];
    }

    _useOnlineDictionary = prefs.getBool(_keyUseOnlineDictionary) ?? true;
    _enableLazyLoadOptimization =
        prefs.getBool(_keyEnableLazyLoadOptimization) ?? true;

    // 加载已删除词典 URL 列表
    final deletedUrlsJson = prefs.getString(_keyDeletedDictionaryUrls);
    if (deletedUrlsJson != null) {
      final List<dynamic> urls = json.decode(deletedUrlsJson);
      _deletedDictionaryUrls = Set<String>.from(urls);
    }

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
  }

  Future<void> setUseOnlineDictionary(bool value) async {
    if (_useOnlineDictionary == value) return;

    _useOnlineDictionary = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseOnlineDictionary, value);
  }

  Future<void> setEnableLazyLoadOptimization(bool value) async {
    if (_enableLazyLoadOptimization == value) return;

    _enableLazyLoadOptimization = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableLazyLoadOptimization, value);
  }

  /// 记录已删除的词典 URL
  Future<void> addDeletedDictionaryUrl(String url) async {
    if (_deletedDictionaryUrls.contains(url)) return;

    _deletedDictionaryUrls.add(url);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyDeletedDictionaryUrls,
      json.encode(_deletedDictionaryUrls.toList()),
    );
  }

  /// 检查词典 URL 是否已被删除
  bool isDictionaryUrlDeleted(String url) {
    return _deletedDictionaryUrls.contains(url);
  }

  /// 清空已删除词典 URL 记录
  Future<void> clearDeletedDictionaryUrls() async {
    _deletedDictionaryUrls.clear();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeletedDictionaryUrls);
  }
}
