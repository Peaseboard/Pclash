import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/mihomo_manager.dart';
import '../core/mihomo_api.dart';
import '../core/subscription_manager.dart';
import '../models/proxy.dart';
import '../models/traffic_stats.dart';
import '../models/subscription.dart';
import '../utils/constants.dart';

// --- Config Providers ---

final apiPortProvider = StateProvider<int>((ref) => AppConstants.defaultApiPort);
final mixedPortProvider = StateProvider<int>((ref) => AppConstants.defaultMixedPort);
final apiSecretProvider = StateProvider<String>((ref) => AppConstants.defaultApiSecret);

// --- Mihomo Manager Provider ---

final mihomoManagerProvider = Provider<MihomoManager>((ref) {
  return MihomoManager(
    apiPort: ref.watch(apiPortProvider),
    mixedPort: ref.watch(mixedPortProvider),
    secret: ref.watch(apiSecretProvider),
  );
});

// --- Connection State ---

final isConnectedProvider = StateProvider<bool>((ref) => false);

// --- Traffic Provider ---

final trafficProvider = StateProvider<TrafficStats>((ref) {
  return const TrafficStats(up: 0, down: 0);
});

final trafficStreamProvider = StreamProvider.autoDispose<TrafficStats>((ref) async* {
  final connected = ref.watch(isConnectedProvider);
  if (!connected) {
    yield const TrafficStats(up: 0, down: 0);
    return;
  }

  final apiPort = ref.watch(apiPortProvider);
  final secret = ref.watch(apiSecretProvider);
  final api = MihomoApi(
    host: '127.0.0.1',
    port: apiPort,
    secret: secret,
  );

  await for (final traffic in api.trafficStream()) {
    yield traffic;
  }
});

// --- Proxies Provider ---

final proxiesProvider = StateProvider<Map<String, Proxy>>((ref) => {});
final proxyGroupsProvider = StateProvider<List<Proxy>>((ref) => []);
final selectedProxyProvider = StateProvider<Map<String, String>>((ref) => {});

// --- Mode Provider ---

final proxyModeProvider = StateProvider<String>((ref) => 'rule');

// --- Subscriptions Provider ---

final subscriptionsProvider = StateNotifierProvider<SubscriptionNotifier, AsyncValue<List<Subscription>>>((ref) {
  return SubscriptionNotifier();
});

class SubscriptionNotifier extends StateNotifier<AsyncValue<List<Subscription>>> {
  final SubscriptionManager _manager = SubscriptionManager();

  SubscriptionNotifier() : super(const AsyncValue.data([])) {
    _load();
  }

  Future<void> _load() async {
    try {
      final subs = await _manager.loadSubscriptions();
      state = AsyncValue.data(subs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(String url, {String? name}) async {
    try {
      final subs = await _manager.addSubscription(url, name: name);
      state = AsyncValue.data(subs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> remove(String url) async {
    try {
      final subs = await _manager.removeSubscription(url);
      state = AsyncValue.data(subs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String?> fetch(Subscription sub) async {
    return await _manager.fetchSubscription(sub);
  }
}

// --- Persistent Settings ---

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class AppSettings {
  final bool autoStart;
  final String themeMode;
  final bool systemProxy;

  const AppSettings({
    this.autoStart = false,
    this.themeMode = 'system',
    this.systemProxy = true,
  });

  AppSettings copyWith({
    bool? autoStart,
    String? themeMode,
    bool? systemProxy,
  }) {
    return AppSettings(
      autoStart: autoStart ?? this.autoStart,
      themeMode: themeMode ?? this.themeMode,
      systemProxy: systemProxy ?? this.systemProxy,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      autoStart: prefs.getBool(AppConstants.keyAutoStart) ?? false,
      themeMode: prefs.getString(AppConstants.keyThemeMode) ?? 'system',
      systemProxy: prefs.getBool('system_proxy') ?? true,
    );
  }

  Future<void> setAutoStart(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyAutoStart, value);
    state = state.copyWith(autoStart: value);
  }

  Future<void> setThemeMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyThemeMode, value);
    state = state.copyWith(themeMode: value);
  }

  Future<void> setSystemProxy(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('system_proxy', value);
    state = state.copyWith(systemProxy: value);
  }
}
