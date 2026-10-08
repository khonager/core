import 'dart:convert';

import 'package:http/http.dart' as http;

class GitHubAuthException implements Exception {
  const GitHubAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class GitHubDeviceCode {
  const GitHubDeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUrl,
    required this.expiresAt,
    required this.interval,
  });
  final String deviceCode, userCode, verificationUrl;
  final DateTime expiresAt;
  final Duration interval;
}

class GitHubCredentials {
  const GitHubCredentials({
    required this.token,
    this.refreshToken,
    this.expiresAt,
  });
  final String token;
  final String? refreshToken;
  final DateTime? expiresAt;

  bool get needsRefresh =>
      expiresAt != null &&
      !DateTime.now().add(const Duration(minutes: 5)).isBefore(expiresAt!);

  Map<String, dynamic> toJson() => {
    'token': token,
    if (refreshToken != null) 'refreshToken': refreshToken,
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
  };

  factory GitHubCredentials.fromJson(Map<String, dynamic> json) =>
      GitHubCredentials(
        token: json['token'] as String,
        refreshToken: json['refreshToken'] as String?,
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      );
}

class GitHubAuth {
  GitHubAuth({
    required this.client,
    this.clientId = const String.fromEnvironment('GITHUB_CLIENT_ID'),
    Future<void> Function(Duration)? wait,
  }) : wait = wait ?? Future<void>.delayed;

  final http.Client client;
  final String clientId;
  final Future<void> Function(Duration) wait;
  bool get configured => clientId.isNotEmpty;

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> body,
  ) async {
    final response = await client
        .post(
          Uri.https('github.com', path),
          headers: {'Accept': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw GitHubAuthException(
        'GitHub sign-in is unavailable (${response.statusCode}). Try again later.',
      );
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const GitHubAuthException(
        'GitHub returned an invalid sign-in response.',
      );
    }
  }

  Future<GitHubDeviceCode> start() async {
    if (!configured) {
      throw const GitHubAuthException(
        'GitHub sign-in is not configured in this build.',
      );
    }
    final data = await _post('/login/device/code', {'client_id': clientId});
    if (data['error'] != null) throw _error(data['error'] as String);
    final url = Uri.tryParse(data['verification_uri'] as String? ?? '');
    if (url == null || url.scheme != 'https' || url.host != 'github.com') {
      throw const GitHubAuthException(
        'GitHub returned an invalid verification link.',
      );
    }
    return GitHubDeviceCode(
      deviceCode: data['device_code'] as String,
      userCode: data['user_code'] as String,
      verificationUrl: url.toString(),
      expiresAt: DateTime.now().add(
        Duration(seconds: data['expires_in'] as int),
      ),
      interval: Duration(seconds: data['interval'] as int? ?? 5),
    );
  }

  Future<GitHubCredentials?> poll(
    GitHubDeviceCode code, {
    required bool Function() cancelled,
  }) async {
    var interval = code.interval;
    while (!cancelled() && DateTime.now().isBefore(code.expiresAt)) {
      await wait(interval);
      if (cancelled()) return null;
      if (!DateTime.now().isBefore(code.expiresAt)) break;
      final data = await _post('/login/oauth/access_token', {
        'client_id': clientId,
        'device_code': code.deviceCode,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
      });
      final error = data['error'] as String?;
      if (error == 'authorization_pending') continue;
      if (error == 'slow_down') {
        interval = Duration(
          seconds: data['interval'] as int? ?? interval.inSeconds + 5,
        );
        continue;
      }
      if (error != null) throw _error(error);
      return _credentials(data);
    }
    if (cancelled()) return null;
    throw const GitHubAuthException(
      'The GitHub sign-in code expired. Try again.',
    );
  }

  Future<GitHubCredentials> refresh(GitHubCredentials credentials) async {
    final refreshToken = credentials.refreshToken;
    if (refreshToken == null) {
      throw const GitHubAuthException('GitHub access expired. Sign in again.');
    }
    final data = await _post('/login/oauth/access_token', {
      'client_id': clientId,
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    });
    if (data['error'] != null) throw _error(data['error'] as String);
    return _credentials(data);
  }

  GitHubCredentials _credentials(Map<String, dynamic> data) {
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty || data['token_type'] != 'bearer') {
      throw const GitHubAuthException('GitHub did not return an access token.');
    }
    final expiresIn = data['expires_in'] as int?;
    return GitHubCredentials(
      token: token,
      refreshToken: data['refresh_token'] as String?,
      expiresAt: expiresIn == null
          ? null
          : DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  GitHubAuthException _error(String code) => GitHubAuthException(switch (code) {
    'access_denied' => 'GitHub sign-in was cancelled.',
    'expired_token' ||
    'token_expired' => 'The GitHub sign-in code expired. Try again.',
    'bad_refresh_token' => 'GitHub access expired. Sign in again.',
    'device_flow_disabled' => 'GitHub sign-in is not enabled for this app.',
    'incorrect_client_credentials' =>
      'GitHub sign-in is not configured correctly.',
    _ => 'GitHub sign-in failed ($code). Try again.',
  });
}
