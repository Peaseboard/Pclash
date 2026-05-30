import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Robust subscription fetcher with DNS over HTTPS fallback and Proxy support.
/// Logic:
/// 1. Direct System DNS
/// 2. DoH (AliDNS/Cloudflare) -> IP Direct
/// 3. Local Proxy (127.0.0.1:7890) -> Fallback when network is restricted
/// 4. Local Proxy (127.0.0.1:7891) -> Alternate port
class RobustSubscriptionFetcher {
  static const List<Map<String, String>> dohProviders = [
    {'url': 'https://223.5.5.5/resolve', 'name': 'AliDNS'},
    {'url': 'https://1.1.1.1/dns-query', 'name': 'Cloudflare'},
  ];

  /// Main entry: Try all strategies
  static Future<String> fetch(String url) async {
    print('[RobustFetcher] Starting fetch for: $url');
    final uri = Uri.parse(url);

    // Strategy 1: Direct
    try {
      print('[RobustFetcher] Strategy 1: Direct request...');
      return await _directFetch(uri);
    } catch (e) {
      print('[RobustFetcher] Direct failed: $e');
    }

    // Strategy 2: DoH + IP Direct
    try {
      print('[RobustFetcher] Strategy 2: DoH + IP Direct...');
      return await _dohFetch(uri);
    } catch (e) {
      print('[RobustFetcher] DoH failed: $e');
    }

    // Strategy 3: Local Proxy (Port 7890)
    try {
      print('[RobustFetcher] Strategy 3: Local Proxy (7890)...');
      return await _proxyFetch(url, uri.host, 7890);
    } catch (e) {
      print('[RobustFetcher] Proxy 7890 failed: $e');
    }

    // Strategy 4: Local Proxy (Port 7891)
    try {
      print('[RobustFetcher] Strategy 4: Local Proxy (7891)...');
      return await _proxyFetch(url, uri.host, 7891);
    } catch (e) {
      print('[RobustFetcher] Proxy 7891 failed: $e');
    }

    throw Exception('All fetch strategies failed. Please check your network or proxy status.');
  }

  // --- Helpers ---

  static Future<String> _directFetch(Uri uri) async {
    final client = http.Client();
    try {
      final response = await client.get(
        uri,
        headers: {
          'User-Agent': 'ClashX/1.0.0',
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        print('[RobustFetcher] Direct success!');
        return response.body;
      }
      throw Exception('HTTP ${response.statusCode}');
    } finally {
      client.close();
    }
  }

  static Future<String> _dohFetch(Uri uri) async {
    String? realIp;
    for (final provider in dohProviders) {
      try {
        realIp = await _resolveViaDoH(provider['url']!, uri.host);
        if (realIp != null) break;
      } catch (_) {}
    }

    if (realIp == null) throw Exception('DoH resolution failed');

    final ipUrl = uri.replace(host: realIp).toString();
    final client = http.Client();
    try {
      final response = await client.get(
        Uri.parse(ipUrl),
        headers: {
          'User-Agent': 'ClashX/1.0.0',
          'Accept': '*/*',
          'Host': uri.host,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        print('[RobustFetcher] DoH IP Direct success!');
        return response.body;
      }
      throw Exception('HTTP ${response.statusCode}');
    } finally {
      client.close();
    }
  }

  static Future<String> _proxyFetch(String url, String host, int port) async {
    final client = HttpClient();
    try {
      // Set proxy
      client.findProxy = (uri) => 'PROXY 127.0.0.1:$port';
      // Ignore certificate errors for local proxy if needed
      client.badCertificateCallback = (cert, host, port) => true;

      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'ClashX/1.0.0');
      request.headers.set('Accept', '*/*');
      request.headers.set('Host', host);

      final response = await request.close().timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        print('[RobustFetcher] Proxy $port success!');
        return content;
      }
      throw Exception('Proxy HTTP ${response.statusCode}');
    } finally {
      client.close();
    }
  }

  static Future<String?> _resolveViaDoH(String baseUrl, String domain) async {
    final url = '$baseUrl?name=$domain&type=A';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final answers = data['Answer'] as List?; // FIXED: was 'dat' before
      if (answers != null && answers.isNotEmpty) {
        for (final answer in answers) {
          if (answer['type'] == 1) return answer['data'] as String?;
        }
      }
    }
    return null;
  }
}
