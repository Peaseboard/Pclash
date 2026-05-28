import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription.dart';
import '../core/config_manager.dart';

/// Subscription management: fetch, parse, store, auto-update
class SubscriptionManager {
  static const String _prefsKey = 'subscriptions';
  final Dio _dio;

  SubscriptionManager() : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'pclash/1.0.0',
    },
  ));

  /// Load all subscriptions from local storage
  Future<List<Subscription>> loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_prefsKey);
    if (jsonList == null || jsonList.isEmpty) return [];

    return jsonList
        .map((json) => Subscription.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();
  }

  /// Save all subscriptions to local storage
  Future<void> saveSubscriptions(List<Subscription> subscriptions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = subscriptions
        .map((s) => jsonEncode(s.toJson()))
        .toList();
    await prefs.setStringList(_prefsKey, jsonList);
  }

  /// Add a new subscription
  Future<List<Subscription>> addSubscription(String url, {String? name}) async {
    final subscriptions = await loadSubscriptions();
    final newSub = Subscription.fromUrl(url, name);
    subscriptions.add(newSub);
    await saveSubscriptions(subscriptions);
    return subscriptions;
  }

  /// Remove a subscription by URL
  Future<List<Subscription>> removeSubscription(String url) async {
    final subscriptions = await loadSubscriptions();
    subscriptions.removeWhere((s) => s.url == url);
    await saveSubscriptions(subscriptions);
    return subscriptions;
  }

  /// Update (refresh) a subscription from remote
  Future<String?> fetchSubscription(Subscription sub) async {
    try {
      final response = await _dio.get(
        sub.url,
        options: Options(
          headers: {'User-Agent': 'Clash.Meta'},
          responseType: ResponseType.plain,
        ),
      );

      // Parse subscription info headers
      final headers = response.headers;
      final userInfo = headers.map['subscription-userinfo']?.first;
      if (userInfo != null) {
        _parseUserInfo(sub, userInfo);
      }

      return response.data as String;
    } catch (e) {
      throw Exception('Failed to fetch subscription: $e');
    }
  }

  /// Parse subscription-userinfo header
  void _parseUserInfo(Subscription sub, String userInfo) {
    final params = <String, String>{};
    for (final part in userInfo.split(';')) {
      final kv = part.split('=');
      if (kv.length == 2) {
        params[kv[0].trim()] = kv[1].trim();
      }
    }

    // Update subscription with usage info
    if (params.containsKey('upload')) {
      // Create updated subscription
    }
  }

  /// Fetch and get config content from subscription
  Future<Map<String, dynamic>> fetchAndParse(Subscription sub) async {
    final content = await fetchSubscription(sub);
    if (content == null || content.isEmpty) {
      throw Exception('Empty subscription content');
    }

    // The content should be in Clash/Mihomo YAML format
    // It will be processed by ConfigManager
    return {'content': content, 'url': sub.url};
  }

  /// Auto-update all subscriptions
  Future<Map<String, String>> updateAll(List<Subscription> subscriptions) async {
    final results = <String, String>{};

    for (final sub in subscriptions) {
      try {
        final content = await fetchSubscription(sub);
        if (content != null) {
          results[sub.url] = 'success';
        } else {
          results[sub.url] = 'empty';
        }
      } catch (e) {
        results[sub.url] = 'error: $e';
      }
    }

    return results;
  }
}
