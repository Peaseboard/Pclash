/// Subscription model
class Subscription {
  final String name;
  final String url;
  final String? filePath; // Local YAML file path
  final DateTime lastUpdated;
  final DateTime? expire; // Subscription expiration date
  final int? upload; // Uploaded traffic in bytes
  final int? download; // Downloaded traffic in bytes
  final int? total; // Total traffic in bytes

  const Subscription({
    required this.name,
    required this.url,
    this.filePath,
    required this.lastUpdated,
    this.expire,
    this.upload,
    this.download,
    this.total,
  });

  factory Subscription.fromFile(String filePath) {
    final fileName = filePath.split('/').last;
    return Subscription(
      name: fileName.replaceAll('.yaml', ''),
      url: '',
      filePath: filePath,
      lastUpdated: DateTime.now(),
    );
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      name: json['name'] as String? ?? 'Unknown',
      url: json['url'] as String? ?? '',
      filePath: json['filePath'] as String?,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String? ?? DateTime.now().toIso8601String()),
      expire: json['expire'] != null ? DateTime.parse(json['expire'] as String) : null,
      upload: json['upload'] as int?,
      download: json['download'] as int?,
      total: json['total'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'filePath': filePath,
      'lastUpdated': lastUpdated.toIso8601String(),
      if (expire != null) 'expire': expire!.toIso8601String(),
      if (upload != null) 'upload': upload,
      if (download != null) 'download': download,
      if (total != null) 'total': total,
    };
  }

  /// Check if subscription has expired
  bool get isExpired {
    if (expire == null) return false;
    return expire!.isBefore(DateTime.now());
  }

  /// Get traffic usage progress text
  String get progressText {
    if (upload == null || download == null || total == null || total == 0) {
      return '流量信息未知';
    }
    final used = (upload! + download!).toDouble();
    final totalDouble = total!.toDouble();
    final percentage = ((used / totalDouble) * 100).toStringAsFixed(1);
    final usedStr = _formatBytes(used);
    final totalStr = _formatBytes(totalDouble);
    return '$usedStr / $totalStr ($percentage%)';
  }

  String _formatBytes(double bytes) {
    if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  }
}
