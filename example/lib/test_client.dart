import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Creates a mock HTTP client simulating backend authentication and API endpoints

http.Client createTestClient() {
  return MockClient((request) async {
    switch (request.url.path) {
      case '/auth/login':
        // Simulate network latency
        await Future<void>.delayed(
          const Duration(milliseconds: 1000), // simulate realistic latency
        );
        return http.Response(
          '{"accessToken":"expired-token","refreshToken":"refresh-token"}',
          200,
          headers: {'content-type': 'application/json'},
        );

      case '/auth/refresh':
        // Simulate network latency
        await Future<void>.delayed(
          const Duration(milliseconds: 1000), // simulate realistic latency
        );
        // Decode request body to inspect refresh token
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['refreshToken'] != 'refresh-token') {
          return _jsonResponse(401, {'message': 'Invalid refresh token'});
        }
        return _jsonResponse(200, {'accessToken': 'valid-token', 'refreshToken': 'refresh-token'});

      case '/auth/logout':
        await Future<void>.delayed(
          const Duration(milliseconds: 1000), // simulate realistic latency
        );
        return http.Response('', 204);

      case '/public-message':
        await Future<void>.delayed(
          const Duration(milliseconds: 1000), // simulate realistic latency
        );
        return http.Response('{"message":"public"}', 200, headers: {'content-type': 'application/json'});

      case '/private-message':
        await Future<void>.delayed(
          const Duration(milliseconds: 1000), // simulate realistic latency
        );
        if (request.headers['authorization'] == 'Bearer valid-token') {
          return http.Response('{"message":"private"}', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{"message":"expired"}', 401);

      default:
        await Future<void>.delayed(
          const Duration(milliseconds: 500), // simulate realistic latency
        );
        return http.Response('Not found', 404);
    }
  });
}

// Helper to construct a JSON HTTP response
http.Response _jsonResponse(int statusCode, Map<String, Object?> body) {
  return http.Response(jsonEncode(body), statusCode, headers: {'content-type': 'application/json'});
}
