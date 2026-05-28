import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  final List<Map<String, dynamic>> _profiles = [
    {
      'name': '默认配置',
      'type': 'subscription',
      'url': 'https://example.com/sub',
      'lastUpdated': DateTime.now().subtract(const Duration(minutes: 10)),
      'active': true,
    },
    {
      'name': '备用机场',
      'type': 'subscription',
      'url': 'https://backup.com/sub',
      'lastUpdated': DateTime.now().subtract(const Duration(days: 2)),
      'active': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('配置管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateAll,
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: _profiles.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final profile = _profiles[index];
          return RadioListTile<int>(
            title: Text(profile['name']),
            subtitle: Text(
              '最后更新: ${_formatDate(profile['lastUpdated'])}',
            ),
            value: index,
            groupValue: _profiles.indexWhere((p) => p['active']),
            onChanged: (val) => _selectProfile(val!),
            secondary: Icon(
              profile['type'] == 'subscription' ? Icons.cloud : Icons.folder,
              color: profile['active'] ? Colors.blue : Colors.grey,
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'url',
            onPressed: _importUrl,
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

  void _selectProfile(int index) {
    setState(() {
      for (int i = 0; i < _profiles.length; i++) {
        _profiles[i]['active'] = (i == index);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已切换到: ${_profiles[index]['name']}')),
    );
  }

  void _updateAll() {
    // Update all subscriptions
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在更新所有配置...')),
    );
  }

  void _importUrl() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入远程订阅'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'https://...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
        ],
      ),
    );
  }

  void _importFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      // Process file
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
