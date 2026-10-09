import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

class Device {
  static const channel = MethodChannel('dev.khonager.core/device');
  bool get android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get linux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
  bool get secureStorage => android || linux;
  Future<String?> readToken() async => secureStorage
      ? const FlutterSecureStorage().read(key: 'github.token')
      : null;
  Future<String?> readGitHubAuth() async => secureStorage
      ? const FlutterSecureStorage().read(key: 'github.auth')
      : null;
  Future<void> storeGitHubAuth(String? value) async {
    if (!secureStorage) return;
    const storage = FlutterSecureStorage();
    if (value == null) {
      await storage.delete(key: 'github.auth');
    } else {
      await storage.write(key: 'github.auth', value: value);
    }
  }

  Future<void> storeToken(String? token) async {
    if (!secureStorage) return;
    const storage = FlutterSecureStorage();
    if (token == null) {
      await storage.delete(key: 'github.token');
    } else {
      await storage.write(key: 'github.token', value: token);
    }
  }

  Future<Map<String, dynamic>> status(String id, String? packageId) async {
    if (!android) return {};
    return Map<String, dynamic>.from(
      await channel.invokeMethod('status', {'id': id, 'package': packageId})
          as Map,
    );
  }

  Future<void> download(
    String id,
    String name,
    String url,
    String? packageId,
  ) async {
    if (!android) {
      await open(url);
      return;
    }
    await channel.invokeMethod('download', {
      'id': id,
      'name': name,
      'url': url,
      'package': packageId,
    });
  }

  Future<void> install(String id) =>
      channel.invokeMethod('install', {'id': id});
  Future<void> cancel(String id) => channel.invokeMethod('cancel', {'id': id});
  Future<void> uninstall(String packageId) =>
      channel.invokeMethod('uninstall', {'package': packageId});
  Future<bool> requestNotifications() async =>
      android && (await channel.invokeMethod<bool>('notifications')) == true;
  Future<void> notify(String id, String title, String body) async {
    if (android) {
      await channel.invokeMethod('notify', {
        'id': id,
        'title': title,
        'body': body,
      });
    }
  }

  Future<void> open(String url) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw const FormatException('Unsupported link');
    }
    if (!await launchUrl(
      uri,
      mode: android ? LaunchMode.inAppBrowserView : LaunchMode.platformDefault,
    )) {
      throw StateError('Could not open this link.');
    }
  }
}
