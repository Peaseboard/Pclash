import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../core/subscription_manager.dart';
import '../models/subscription.dart';

class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionsAsync = ref.watch(subscriptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('配置管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateAll,
            tooltip: '更新所有订阅',
          ),
        ],
      ),
      body: subscriptionsAsync.when(
        data: (subscriptions) {
          if (subscriptions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无配置',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击下方 + 按钮导入远程订阅',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: subscriptions.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final sub = subscriptions[index];
              return RadioListTile<int>(
                title: Text(sub.name),
                subtitle: Text(
                  '最后更新: ${_formatDate(sub.lastUpdated)}'
                  '${sub.expire != null ? ' | 到期: ${sub.expire!.year}-${sub.expire!.month.toString().padLeft(2, '0')}-${sub.expire!.day.toString().padLeft(2, '0')}' : ''}',
                ),
                value: index,
                groupValue: 0, // TODO: Track active subscription
                onChanged: (val) => _selectProfile(val!, sub),
                secondary: Icon(
                  sub.isExpired ? Icons.warning : Icons.cloud_done,
                  color: sub.isExpired ? Colors.red : Colors.blue,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('加载失败: $e'),
            ],
          ),
        ),
      ),
      floatingActionButton: _isLoading
          ? const CircularProgressIndicator()
          : Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'url',
                  onPressed: _showImportUrlDialog,
                  child: const Icon(Icons.link),
                  tooltip: '导入远程订阅',
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'file',
                  onPressed: _importFile,
                  child: const Icon(Icons.folder),
                  tooltip: '导入本地文件',
                ),
              ],
            ),
    );
  }

  void _showImportUrlDialog() {
    _urlController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入远程订阅'),
        content: TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            hintText: 'https://...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _importUrl(),
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  Future<void> _importUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入订阅 URL')),
      );
      return;
    }

    // Close dialog first
    Navigator.pop(context);

    setState(() {
      _isLoading = true;
      _statusMessage = '正在获取订阅配置...';
    });

    try {
      // 1. Add subscription to storage
      final notifier = ref.read(subscriptionsProvider.notifier);
      await notifier.add(url);

      // 2. Immediately fetch and validate content
      final subs = ref.read(subscriptionsProvider).when(
        data: (s) => s,
        loading: () => [],
        error: (_, __) => [],
      );
      final targetSub = subs.firstWhere((s) => s.url == url);

      final subManager = SubscriptionManager();
      final content = await subManager.fetchSubscription(targetSub);

      if (content == null || content.isEmpty) {
        throw Exception('订阅内容为空，请检查 URL 是否正确');
      }

      // 3. Parse content to get node count
      final nodeCount = _countNodes(content);

      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 导入成功！共 $nodeCount 个节点'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 导入失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  int _countNodes(String content) {
    // Count yaml nodes (each line starting with "  - name:" or "- name:")
    final lines = content.split('\n');
    int count = 0;
    for (final line in lines) {
      if (line.contains('- name:') || line.contains('server:')) {
        count++;
      }
    }
    return count > 0 ? count : lines.length ~/ 5; // rough estimate
  }

  Future<void> _selectProfile(int index, Subscription sub) async {
    setState(() {
      _isLoading = true;
      _statusMessage = '正在加载配置: ${sub.name}...';
    });

    try {
      final subManager = SubscriptionManager();
      final content = await subManager.fetchSubscription(sub);

      if (content == null || content.isEmpty) {
        throw Exception('订阅内容为空');
      }

      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 已切换到: ${sub.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // TODO: Reload mihomo config with new content
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 加载失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateAll() async {
    final subs = ref.read(subscriptionsProvider).when(
      data: (s) => s,
      loading: () => [],
      error: (_, __) => [],
    );

    if (subs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可更新的订阅')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '正在更新所有订阅...';
    });

    final subManager = SubscriptionManager();
    int success = 0;
    int failed = 0;

    for (final sub in subs) {
      try {
        final content = await subManager.fetchSubscription(sub);
        if (content != null && content.isNotEmpty) {
          success++;
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
    }

    setState(() {
      _isLoading = false;
      _statusMessage = '';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('更新完成: $success 成功, $failed 失败'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['yaml', 'yml', 'txt', 'conf'],
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已选择文件: ${file.name}')),
        );
      }
      // TODO: Read and parse file content
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
