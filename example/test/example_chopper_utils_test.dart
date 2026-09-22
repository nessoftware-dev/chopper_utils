import 'package:example/example_client_calls.dart';
import 'package:example/example_chopper_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('private message is retrieved after login', () async {
    final loginResult = await login(
      username: 'demo',
      password: 'demo',
    );

    expect(loginResult.hasError, isFalse);

    if (!loginResult.hasError) {
      final response = loginResult.value!;
      ExampleChopperUtils().accessToken = response.body!.accessToken;
      ExampleChopperUtils().refreshToken = response.body!.refreshToken;

      final privateMessageResult = await getPrivateMessage();

      expect(privateMessageResult.hasError, isFalse);
      expect(privateMessageResult.value, isNotNull);
    }
  });

  test('two authenticated API calls can be made concurrently', () async {
    final loginResult = await login(
      username: 'demo',
      password: 'demo',
    );

    expect(loginResult.hasError, isFalse);

    if (!loginResult.hasError) {
      final response = loginResult.value!;
      ExampleChopperUtils().accessToken = response.body!.accessToken;
      ExampleChopperUtils().refreshToken = response.body!.refreshToken;

      final first = getPrivateMessage();
      final second = getPrivateMessage();
      final results = await Future.wait([first, second]);

      expect(results[0].hasError, isFalse);
      expect(results[1].hasError, isFalse);
      expect(results[0].value, isNotNull);
      expect(results[1].value, isNotNull);
    }
  });
}
