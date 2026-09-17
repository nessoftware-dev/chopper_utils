import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Client createTestClient() {
  return MockClient((request) async {
    switch (request.url.path) {
      case '/auth/login':
        await Future<void>.delayed(
          const Duration(milliseconds: 100), // simulate realistic latency
        );
        return http.Response(
          '{"accessToken":"expired-token","refreshToken":"refresh-token"}',
          200,
          headers: {'content-type': 'application/json'},
        );

      case '/auth/refresh':
        await Future<void>.delayed(
          const Duration(milliseconds: 200), // simulate realistic latency
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['refreshToken'] != 'refresh-token') {
          return _jsonResponse(401, {'message': 'Invalid refresh token'});
        }
        return _jsonResponse(200, {'accessToken': 'valid-token', 'refreshToken': 'refresh-token'});

      case '/auth/logout':
        await Future<void>.delayed(
          const Duration(milliseconds: 100), // simulate realistic latency
        );
        return http.Response('', 204);

      case '/public-message':
        await Future<void>.delayed(
          const Duration(milliseconds: 200), // simulate realistic latency
        );
        return http.Response('{"message":"public"}', 200, headers: {'content-type': 'application/json'});

      case '/private-message':
        await Future<void>.delayed(
          const Duration(milliseconds: 200), // simulate realistic latency
        );
        if (request.headers['authorization'] == 'Bearer valid-token') {
          return http.Response('{"message":"private"}', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{"message":"expired"}', 401);

      default:
        await Future<void>.delayed(
          const Duration(milliseconds: 50), // simulate realistic latency
        );
        return http.Response('Not found', 404);
    }
  });
}

http.Response _jsonResponse(int statusCode, Map<String, Object?> body) {
  return http.Response(jsonEncode(body), statusCode, headers: {'content-type': 'application/json'});
}
