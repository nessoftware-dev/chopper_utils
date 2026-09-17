import 'package:flutter_test/flutter_test.dart';
import 'package:example/example_client_calls.dart';

void main() {
  test('private message is retrieved after login', () async {
    final loginResult = await login(
      username: 'demo',
      password: 'demo',
    );

    expect(loginResult.hasError, isFalse);

    final privateMessageResult = await getPrivateMessage();

    expect(privateMessageResult.hasError, isFalse);
    expect(privateMessageResult.value, isNotNull);
  });

  test('two authenticated API calls can be made concurrently', () async {
    final loginResult = await login(
      username: 'demo',
      password: 'demo',
    );
    expect(loginResult.hasError, isFalse);
    final first = getPrivateMessage();
    final second = getPrivateMessage();
    final results = await Future.wait([first, second]);
    expect(results[0].hasError, isFalse);
    expect(results[1].hasError, isFalse);
    expect(results[0].value, isNotNull);
    expect(results[1].value, isNotNull);
  });
}
