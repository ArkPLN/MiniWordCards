import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 已删除词典来源记录，避免默认词典被自动恢复。
class DeletedDictionaryStore {
  static const String _keyDeletedDictionaryUrls = 'deleted_dictionary_urls';

  Future<Set<String>> loadDeletedUrls() async {
    final prefs = await SharedPreferences.getInstance();
    final deletedUrlsJson = prefs.getString(_keyDeletedDictionaryUrls);
    if (deletedUrlsJson == null) {
      return {};
    }

    final urls = json.decode(deletedUrlsJson) as List<dynamic>;
    return Set<String>.from(urls);
  }

  Future<void> addDeletedUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final deletedUrls = await loadDeletedUrls();
    deletedUrls.add(url);
    await prefs.setString(
      _keyDeletedDictionaryUrls,
      json.encode(deletedUrls.toList()),
    );
  }

  Future<void> clearDeletedUrls() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeletedDictionaryUrls);
  }
}
