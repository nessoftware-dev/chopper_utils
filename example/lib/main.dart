import 'package:flutter/material.dart';
import 'package:dialog_utils/dialog_utils.dart';
import 'package:chopper/chopper.dart' show Response;
import 'package:example/example_chopper_utils.dart';
import 'package:example/example_client_calls.dart';
import 'package:example/openapi_generated_code/openapi.swagger.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChopperUtils Example',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _lastLog = 'Ready. Press any action below to test API calls.';

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = ExampleChopperUtils().accessToken != null;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('ChopperUtils Demo & Tester'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStateCard(),
            const SizedBox(height: 16),
            // Offered OpenAPI Functions
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'OpenAPI Functions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Test authentication, interceptors, token refresh & 401 retry:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _login,
                          icon: const Icon(Icons.login),
                          label: const Text('Login (authLoginPost)'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _getPublicMessage,
                          icon: const Icon(Icons.public),
                          label: const Text('Public Message (publicMessageGet)'),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                          onPressed: _getPrivateMessage,
                          icon: const Icon(Icons.security),
                          label: const Text('Private Message (401 Retry Test)'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _manualRefresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Token (authRefreshPost)'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          onPressed: !isLoggedIn ? null : _logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout (authLogoutPost)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLogCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStateCard() {
    final bool isLoggedIn = ExampleChopperUtils().accessToken != null;
    final String? accessToken = ExampleChopperUtils().accessToken;
    final String? refreshToken = ExampleChopperUtils().refreshToken;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current State',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Chip(
                  avatar: Icon(
                    isLoggedIn ? Icons.check_circle : Icons.cancel_outlined,
                    size: 16,
                    color: isLoggedIn ? Colors.green : Colors.grey,
                  ),
                  label: Text(isLoggedIn ? 'Authenticated' : 'Logged Out'),
                  backgroundColor: isLoggedIn ? Colors.green.shade50 : Colors.grey.shade100,
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow('App Version:', ExampleChopperUtils().getAppVersion()),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Access Token:',
              accessToken ?? '(none)',
              valueColor: accessToken == 'valid-token'
                  ? Colors.green.shade800
                  : (accessToken == 'expired-token' ? Colors.orange.shade800 : null),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Refresh Token:', refreshToken ?? '(none)'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w500, color: valueColor),
          ),
        ),
      ],
    );
  }

  Widget _buildLogCard() {
    return Card(
      elevation: 2,
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Response / Log Output',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.clear_all, color: Colors.white70, size: 20),
                  tooltip: 'Clear log',
                  onPressed: () => setState(() => _lastLog = 'Cleared.'),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            Text(
              _lastLog,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.greenAccent),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    _log('POST /auth/login...\nSending demo credentials');
    // Show waiting dialog during login
    final result = await DialogUtils().showWaitingDlg<Response<AuthResponse>>(
      context: context,
      message: 'Logging in...',
      future: () => login(username: 'demo', password: 'demo'),
    );

    if (!mounted) return;

    if (result.hasError) {
      _log('LOGIN FAILED\nError: ${result.error}');
    } else {
      final response = result.value!;
      // Update tokens in application state
      setState(() {
        // The mock client deliberately returns 'expired-token' initially
        // to test automatic 401 retry on the next private call
        ExampleChopperUtils().accessToken = response.body!.accessToken;
        ExampleChopperUtils().refreshToken = response.body!.refreshToken;
      });
      _log(
        'LOGIN SUCCESS (Status: ${response.statusCode})\n'
        'Received AccessToken: "${response.body!.accessToken}" (expired)\n'
        'Received RefreshToken: "${response.body!.refreshToken}"\n\n'
        '👉 Next: Click "Private Message (401 Retry Test)" to watch it auto-refresh and retry',
      );
    }
  }

  Future<void> _logout() async {
    _log('POST /auth/logout (authenticated)...');
    // Show waiting dialog during logout
    final result = await DialogUtils().showWaitingDlg<Response>(
      context: context,
      message: 'Logging out...',
      future: () => logout(),
    );

    if (!mounted) return;

    // Clear tokens in application state
    setState(() {
      ExampleChopperUtils().accessToken = null;
      ExampleChopperUtils().refreshToken = null;
    });

    if (result.hasError) {
      _log('LOGOUT ERROR: ${result.error}');
    } else {
      _log(
        'LOGOUT COMPLETE (Status: ${result.value!.statusCode})\n'
        'Tokens cleared in client.',
      );
    }
  }

  Future<void> _getPublicMessage() async {
    _log('GET /public-message (unauthenticated)...');
    // Show waiting dialog during public message request
    final result = await DialogUtils().showWaitingDlg<Response<Message>>(
      context: context,
      message: 'Fetching public message...',
      future: () => getPublicMessage(),
    );

    if (!mounted) return;

    if (result.hasError) {
      _log('PUBLIC MESSAGE FAILED\nError: ${result.error}');
    } else {
      _log(
        'PUBLIC MESSAGE SUCCESS (Status: ${result.value!.statusCode})\n'
        'Message: "${result.value!.body?.message}"',
      );
    }
  }

  Future<void> _getPrivateMessage() async {
    final tokenBefore = ExampleChopperUtils().accessToken;
    _log(
      'GET /private-message (authenticated)...\n'
      'Current token before request: "$tokenBefore"\n'
      'Sending request with OpenApiWithAuth...',
    );

    // Show waiting dialog during private message request
    final result = await DialogUtils().showWaitingDlg<Response<Message>>(
      context: context,
      message: 'Fetching private message...',
      future: () => getPrivateMessage(),
    );

    if (!mounted) return;

    final tokenAfter = ExampleChopperUtils().accessToken;
    if (result.hasError) {
      _log('PRIVATE MESSAGE FAILED\nError: ${result.error}');
    } else {
      // Refresh UI state card with updated token
      setState(() {});
      _log(
        'PRIVATE MESSAGE SUCCESS (Status: ${result.value!.statusCode})\n'
        'Response Body: "${result.value!.body?.message}"\n'
        'Token before call: "$tokenBefore"\n'
        'Token after call:  "$tokenAfter"\n\n'
        '${tokenBefore != tokenAfter ? '🎉 AUTOMATIC 401 REFRESH & RETRY SUCCEEDED!' : '✅ Authenticated with existing valid token.'}',
      );
    }
  }

  Future<void> _manualRefresh() async {
    _log('POST /auth/refresh via refreshUserAccessTokenByOpenApi()...');
    // Show waiting dialog during manual token refresh
    final result = await DialogUtils().showWaitingDlg<bool>(
      context: context,
      message: 'Refreshing access token...',
      future: () => refreshAccessToken(),
    );

    if (!mounted) return;

    // Refresh UI state card with updated token
    setState(() {});
    if (result.hasError) {
      _log('MANUAL REFRESH FAILED: ${result.error}');
    } else {
      _log(
        'MANUAL REFRESH SUCCESS!\n'
        'New AccessToken:  "${ExampleChopperUtils().accessToken}"\n'
        'New RefreshToken: "${ExampleChopperUtils().refreshToken}"',
      );
    }
  }

  void _log(String message) {
    setState(() {
      _lastLog = '[${DateTime.now().toIso8601String().substring(11, 19)}] $message';
    });
  }
}
