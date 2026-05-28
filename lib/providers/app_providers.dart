import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/mihomo_manager.dart';
import '../core/mihomo_api.dart';
import '../core/subscription_manager.dart';
import '../core/platform/vpn_channel.dart';
import '../core/platform/system_proxy_channel.dart';
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

  /// Detect if current platform uses TUN mode
  bool get _isTunMode => Platform.isAndroid;

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

      // 4. Platform-specific setup
      if (_isTunMode) {
        // Android: Start VPN service
        await _startVpn(mixedPort, apiPort, secret);
      } else if (SystemProxyChannel.isSupported) {
        // Desktop: Set system proxy
        AppLogger.info('Setting system proxy on ${SystemProxyChannel.platformName}...');
        await SystemProxyChannel.setSystemProxy(
          enabled: true,
          port: mixedPort,
        );
      }

      // 5. Set up traffic stream
      _setupTrafficStream();

      // 6. Load proxies
      await _loadProxies();

      // 7. Update state
      state = true;
      AppLogger.info('Connection established');

    } catch (e, st) {
      AppLogger.error('Connection failed', 'CONNECT', e as Exception?);
      // Clean up on failure
      await _manager?.stop();
      _manager = null;
      state = false;
      rethrow;
    }
  }

  /// Start Android VPN service
  Future<void> _startVpn(int mixedPort, int apiPort, String secret) async {
    try {
      final workDir = _manager?.workDir;
      await VpnChannel.startVpn(
        mihomoPort: mixedPort,
        apiPort: apiPort,
        secret: secret,
        configPath: workDir != null ? '$workDir/config.yaml' : null,
      );
      AppLogger.vpn('VPN service started');
    } catch (e) {
      AppLogger.error('Failed to start VPN', 'VPN', e as Exception?);
      rethrow;
    }
  }

  /// Disconnect - clean up all resources
  Future<void> disconnect() async {
    if (!state) return;

    try {
      AppLogger.info('Disconnecting...');

      // 1. Platform-specific cleanup
      if (_isTunMode) {
        try {
          await VpnChannel.stopVpn();
          AppLogger.vpn('VPN service stopped');
        } catch (e) {
          AppLogger.error('Failed to stop VPN', 'DISCONNECT', e as Exception?);
        }
      } else if (SystemProxyChannel.isSupported) {
        try {
          await SystemProxyChannel.disableProxy();
          AppLogger.proxy('System proxy disabled on ${SystemProxyChannel.platformName}');
        } catch (e) {
          AppLogger.error('Failed to disable system proxy', 'DISCONNECT', e as Exception?);
        }
      }

      // 2. Cancel traffic stream
      await _trafficSubscription?.cancel();
      _trafficSubscription = null;

      // 3. Stop mihomo process
      await _manager?.stop();
      _manager = null;

      // 4. Reset providers
      _ref.read(proxiesProvider.notifier).state = {};
      _ref.read(proxyGroupsProvider.notifier).state = [];
      _ref.read(trafficProvider.notifier).state = const TrafficStats(up: 0, down: 0);

      // 5. Update state
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

  /// Test delay for a proxy group
  Future<void> testGroupDelay(String groupName) async {
    if (_manager?.api == null) return;

    try {
      await _manager!.api!.testGroupDelay(groupName);
      // Reload proxies to update delays
      await _loadProxies();
      AppLogger.info('Group delay test completed: $groupName');
    } catch (e) {
      AppLogger.error('Group delay test failed', 'DELAY', e as Exception?);
    }
  }

  /// Select proxy in a group
  Future<void> selectProxy(String groupName, String proxyName) async {
    if (_manager?.api == null) return;

    try {
      await _manager!.api!.selectProxy(groupName, proxyName);
      _ref.read(selectedProxyProvider.notifier).state = {
        ..._ref.read(selectedProxyProvider),
        groupName: proxyName,
      };
      AppLogger.info('Selected proxy: $proxyName in $groupName');
    } catch (e) {
      AppLogger.error('Failed to select proxy', 'PROXY', e as Exception?);
    }
  }

  /// Change proxy mode
  Future<void> changeMode(String mode) async {
    if (_manager?.api == null) return;

    try {
      await _manager!.api!.setMode(mode);
      _ref.read(proxyModeProvider.notifier).state = mode;
      AppLogger.info('Mode changed to: $mode');
    } catch (e) {
      AppLogger.error('Failed to change mode', 'MODE', e as Exception?);
    }
  }

  /// Update subscription and reload
  Future<void> updateSubscription() async {
    final subs = await _loadSubscriptions();
    if (subs.isEmpty) {
      AppLogger.warning('No subscriptions to update');
      return;
    }

    try {
      final subManager = SubscriptionManager();
      final content = await subManager.fetchSubscription(subs.first);
      
      if (content != null && _manager != null) {
        await _manager!.restartWithSubscription(content);
        await _loadProxies();
        AppLogger.info('Subscription updated and reloaded');
      }
    } catch (e) {
      AppLogger.error('Failed to update subscription', 'SUB', e as Exception?);
    }
  }

  @override
  void dispose() {
    disconnect();
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
  final bool bypassLan;

  const AppSettings({
    this.autoStart = false,
    this.themeMode = 'system',
    this.systemProxy = true,
    this.bypassLan = true,
  });

  AppSettings copyWith({
    bool? autoStart,
    String? themeMode,
    bool? systemProxy,
    bool? bypassLan,
  }) {
    return AppSettings(
      autoStart: autoStart ?? this.autoStart,
      themeMode: themeMode ?? this.themeMode,
      systemProxy: systemProxy ?? this.systemProxy,
      bypassLan: bypassLan ?? this.bypassLan,
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
    // Also set platform-specific auto-start
    if (SystemProxyChannel.isSupported) {
      await SystemProxyChannel.setAutoStart(value);
    }
    state = state.copyWith(autoStart: value);
  }

  Future<void> setThemeMode(String value) async {
    state = state.copyWith(themeMode: value);
  }

  Future<void> setSystemProxy(bool value) async {
    state = state.copyWith(systemProxy: value);
  }

  Future<void> setBypassLan(bool value) async {
    state = state.copyWith(bypassLan: value);
  }
}
