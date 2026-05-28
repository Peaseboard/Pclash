import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../utils/constants.dart';
import 'proxy_screen.dart';
import 'subscription_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeTab(),
    ProxyScreen(),
    SubscriptionScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz),
            label: '节点',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_download_outlined),
            selectedIcon: Icon(Icons.cloud_download),
            label: '订阅',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

/// Home Tab - Connection toggle + traffic display
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isConnectedProvider);
    final traffic = ref.watch(trafficProvider);
    final mode = ref.watch(proxyModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              AppConstants.appVersion,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),

            // Connection toggle button
            _ConnectionButton(
              isConnected: isConnected,
              onTap: () => _toggleConnection(context, ref),
            ),

            const SizedBox(height: 48),

            // Mode selector
            _ModeSelector(currentMode: mode),

            const SizedBox(height: 32),

            // Traffic display
            _TrafficDisplay(traffic: traffic),

            const SizedBox(height: 32),

            // Quick info cards
            const _QuickInfoCards(),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleConnection(BuildContext context, WidgetRef ref) async {
    final connected = ref.read(isConnectedProvider);

    if (!connected) {
      // Start connection
      ref.read(isConnectedProvider.notifier).state = true;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接成功')),
        );
      }
    } else {
      // Stop connection
      ref.read(isConnectedProvider.notifier).state = false;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已断开')),
        );
      }
    }
  }
}

class _ConnectionButton extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onTap;

  const _ConnectionButton({
    required this.isConnected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isConnected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          boxShadow: isConnected
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isConnected ? Icons.check_circle : Icons.power_settings_new,
              size: 48,
              color: isConnected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              isConnected ? '已连接' : '点击连接',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isConnected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends ConsumerWidget {
  final String currentMode;

  const _ModeSelector({required this.currentMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modes = const [
      ('rule', '规则模式'),
      ('global', '全局模式'),
      ('direct', '直连模式'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '代理模式',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: modes.map((m) {
                final isSelected = currentMode == m.$1;
                return ChoiceChip(
                  label: Text(m.$2),
                  selected: isSelected,
                  onSelected: (_) {
                    ref.read(proxyModeProvider.notifier).state = m.$1;
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficDisplay extends StatelessWidget {
  final traffic;

  const _TrafficDisplay({required this.traffic});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Icon(
                  Icons.arrow_upward,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  traffic.formattedUp,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '上传',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            VerticalDivider(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Column(
              children: [
                Icon(
                  Icons.arrow_downward,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  traffic.formattedDown,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '下载',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickInfoCards extends StatelessWidget {
  const _QuickInfoCards();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 24),
                  SizedBox(height: 8),
                  Text('安全加密'),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.speed_outlined, size: 24),
                  SizedBox(height: 8),
                  Text('智能路由'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
