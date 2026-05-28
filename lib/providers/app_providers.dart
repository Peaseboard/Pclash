import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/mihomo_manager.dart';
import '../core/mihomo_api.dart';
import '../core/subscription_manager.dart';
import '../models/proxy.dart';
import '../models/traffic_stats.dart';
import '../models/subscription.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

// --- Config Providers ---

final apiPortProvider = StateProvider<int>((ref) => AppConstants.defaultApiPort);
final mixedPortProvider = StateProvider<int>((ref) => AppConstants.defaultMixedPort);
final apiSecretProvider = StateProvider<String>((ref) => AppConstants.defaultApiSecret);

// --- Connection State ---

final isConnectedProvider = StateNotifierProvider<ConnectionNotifier, bool>((ref) {
  return ConnectionNotifier(ref);
});

class ConnectionNotifier extends StateNotifier<bool> {
  final Ref _ref;
  MihomoManager? _manager;
  StreamSubscription<TrafficStats>? _trafficSubscription;

  ConnectionNotifier(this._ref) : super(false);

  /// Start connection - fully串联 all modules
  Future<void> connect() async {
    if (state) return; // Already connected

    try {
      AppLogger.info('Starting connection...');

      // 1. Create manager with current settings
      final apiPort = _ref.read(apiPortProvider);
      final mixedPort = _ref.read(mixedPortProvider);
      final secret = _ref.read(apiSecretProvider);

      _manager = MihomoManager(
        apiPort: apiPort,
        mixedPort: mixedPort,
        secret: secret,
      );

      // 2. Load subscriptions
      final subs = await _loadSubscriptions();
      String? subscriptionContent;
      
      if (subs.isNotEmpty) {
        AppLogger.info('Loading subscription: ${subs.first.name}');
        try {
          final subManager = SubscriptionManager();
          subscriptionContent = await subManager.fetchSubscription(subs.first);
          if (subscriptionContent == null) {
            AppLogger.warning('Subscription returned empty content');
          }
        } catch (e) {
          AppLogger.error('Failed to fetch subscription', 'CONNECT', e as Exception?);
          // Continue with default config if subscription fails
        }
      }

      // 3. Start mihomo process
      AppLogger.info('Starting Mihomo core...');
      final started = await _manager!.start(subscriptionContent: subscriptionContent);
      
      if (!started) {
        throw Exception('Mihomo failed to start');
      }

      AppLogger.info('Mihomo started successfully');

      // 4. Set up traffic stream
      _setupTrafficStream();

      // 5. Load proxies
      await _loadProxies();

      // 6. Update state
      state = true;
      AppLogger.info('Connection established');

    } catch (e, st) {
      AppLogger.error('Connection failed', 'CONNECT', e as Exception?);
      state = false;
      rethrow;
    }
  }

  /// Disconnect - clean up all resources
  Future<void> disconnect() async {
    if (!state) return;

    try {
      AppLogger.info('Disconnecting...');

      // 1. Cancel traffic stream
      await _trafficSubscription?.cancel();
      _trafficSubscription = null;

      // 2. Stop mihomo process
      await _manager?.stop();
      _manager = null;

      // 3. Reset providers
      _ref.read(proxiesProvider.notifier).state = {};
      _ref.read(proxyGroupsProvider.notifier).state = [];
      _ref.read(trafficProvider.notifier).state = const TrafficStats(up: 0, down: 0);

      // 4. Update state
      state = false;
      AppLogger.info('Disconnected');

    } catch (e) {
      AppLogger.error('Disconnect failed', 'DISCONNECT', e as Exception?);
      state = false;
    }
  }

  /// Set up real-time traffic monitoring
  void _setupTrafficStream() {
    if (_manager?.api == null) return;

    _trafficSubscription = _manager!.api!.trafficStream().listen(
      (traffic) {
        _ref.read(trafficProvider.notifier).state = traffic;
      },
      onError: (e) {
        AppLogger.error('Traffic stream error', 'TRAFFIC', e as Exception?);
      },
      cancelOnError: false,
    );
  }

  /// Load proxies from API
  Future<void> _loadProxies() async {
    if (_manager?.api == null) return;

    try {
      final proxies = await _manager!.api!.getProxies();
      final groups = <Proxy>[];
      final allProxies = <String, Proxy>{};

      for (final entry in proxies.entries) {
        final proxy = entry.value;
        allProxies[entry.key] = proxy;
        
        if (proxy.isGroup) {
          groups.add(proxy);
        }
      }

      _ref.read(proxiesProvider.notifier).state = allProxies;
      _ref.read(proxyGroupsProvider.notifier).state = groups;
      
      AppLogger.info('Loaded ${allProxies.length} proxies, ${groups.length} groups');

    } catch (e) {
      AppLogger.error('Failed to load proxies', 'PROXIES', e as Exception?);
    }
  }

  /// Load subscriptions from storage
  Future<List<Subscription>> _loadSubscriptions() async {
    try {
      final subsAsync = _ref.read(subscriptionsProvider);
      return subsAsync.when(
        data: (subs) => subs,
        loading: () => [],
        error: (_, __) => [],
      );
    } catch (_) {
      return [];
    }
  }

  @override
  void dispose() {
    _trafficSubscription?.cancel();
    _manager?.dispose();
    super.dispose();
  }
}

// --- Traffic Provider ---

final trafficProvider = StateNotifierProvider<TrafficNotifier, TrafficStats>((ref) {
  return TrafficNotifier();
});

class TrafficNotifier extends StateNotifier<TrafficStats> {
  TrafficNotifier() : super(const TrafficStats(up: 0, down: 0));
}

// --- Proxies Provider ---

final proxiesProvider = StateNotifierProvider<ProxiesNotifier, Map<String, Proxy>>((ref) {
  return ProxiesNotifier();
});

class ProxiesNotifier extends StateNotifier<Map<String, Proxy>> {
  ProxiesNotifier() : super({});
}

final proxyGroupsProvider = StateNotifierProvider<ProxyGroupsNotifier, List<Proxy>>((ref) {
  return ProxyGroupsNotifier();
});

class ProxyGroupsNotifier extends StateNotifier<List<Proxy>> {
  ProxyGroupsNotifier() : super([]);
}

final selectedProxyProvider = StateProvider<Map<String, String>>((ref) => {});

// --- Mode Provider ---

final proxyModeProvider = StateNotifierProvider<ModeNotifier, String>((ref) {
  return ModeNotifier();
});

class ModeNotifier extends StateNotifier<String> {
  ModeNotifier() : super('rule');

  Future<void> changeMode(String mode) async {
    state = mode;
    // TODO: Call API to update mode if connected
  }
}

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
    state = const AsyncValue.loading();
    try {
      final subs = await _manager.addSubscription(url, name: name);
      state = AsyncValue.data(subs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> remove(String url) async {
    state = const AsyncValue.loading();
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
    // TODO: Load from SharedPreferences
  }

  Future<void> setAutoStart(bool value) async {
    // TODO: Save to SharedPreferences
    state = state.copyWith(autoStart: value);
  }

  Future<void> setThemeMode(String value) async {
    // TODO: Save to SharedPreferences
    state = state.copyWith(themeMode: value);
  }

  Future<void> setSystemProxy(bool value) async {
    // TODO: Save to SharedPreferences
    state = state.copyWith(systemProxy: value);
  }
}
