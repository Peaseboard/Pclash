/// Subscription model
class Subscription {
  final String name;
  final String url;
  final DateTime? expire;
  final int? totalBytes;
  final int? uploadBytes;
  final int? downloadBytes;
  final int? remainingDays;
  final DateTime lastUpdated;

  const Subscription({
    required this.name,
    required this.url,
    this.expire,
    this.totalBytes,
    this.uploadBytes,
    this.downloadBytes,
    this.remainingDays,
    required this.lastUpdated,
  });

  factory Subscription.fromUrl(String url, String? name) {
    return Subscription(
      name: name ?? _extractName(url),
      url: url,
      lastUpdated: DateTime.now(),
    );
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      expire: json['expire'] != null ? DateTime.parse(json['expire'] as String) : null,
      totalBytes: json['total_bytes'] as int?,
      uploadBytes: json['upload_bytes'] as int?,
      downloadBytes: json['download_bytes'] as int?,
      remainingDays: json['remaining_days'] as int?,
      lastUpdated: DateTime.parse(json['last_updated'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'expire': expire?.toIso8601String(),
      'total_bytes': totalBytes,
      'upload_bytes': uploadBytes,
      'download_bytes': downloadBytes,
      'remaining_days': remainingDays,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  String get progressText {
    if (totalBytes == null) return '无限制';
    final used = (uploadBytes ?? 0) + (downloadBytes ?? 0);
    final total = totalBytes!;
    return '${_formatBytes(used)} / ${_formatBytes(total)}';
  }

  double get progressPercent {
    if (totalBytes == null || totalBytes == 0) return 0;
    final used = (uploadBytes ?? 0) + (downloadBytes ?? 0);
    return used / totalBytes!;
  }

  bool get isExpired {
    if (expire == null) return false;
    return DateTime.now().isAfter(expire!);
  }

  static String _extractName(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['name'] ?? uri.host;
    } catch (_) {
      return '订阅';
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
