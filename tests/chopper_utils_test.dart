import 'package:chopper/chopper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chopper_utils/chopper_utils.dart';

class FakeChopperService extends ChopperService {
  @override
  Type get definitionType => FakeChopperService;
}

class TestChopperUtils extends ChopperUtils<FakeChopperService> {
  TestChopperUtils({
    this.accessToken,
    this.refreshResult = true,
  });

  String? accessToken;
  bool refreshResult;

  int createWithoutAuthCount = 0;
  int createWithAuthCount = 0;
  int refreshCount = 0;

  @override
  String getAppVersion() => '1.0.0';

  @override
  String? getAccessToken() => accessToken;

  @override
  Future<bool> refreshUserAccessTokenByOpenApi() async {
    refreshCount++;
    return refreshResult;
  }

  @override
  FakeChopperService createOpenApiWithoutAuth() {
    createWithoutAuthCount++;
    return FakeChopperService();
  }

  @override
  FakeChopperService createOpenApiWithAuth() {
    createWithAuthCount++;
    return FakeChopperService();
  }
}

void main() {
  test('getOpenApiWithoutAuth caches the service', () {
    final utils = TestChopperUtils();

    final first = utils.getOpenApiWithoutAuth();
    final second = utils.getOpenApiWithoutAuth();

    expect(identical(first, second), isTrue);
    expect(utils.createWithoutAuthCount, 1);
  });

  test('getOpenApiWithAuth caches the service', () {
    final utils = TestChopperUtils();

    final first = utils.getOpenApiWithAuth();
    final second = utils.getOpenApiWithAuth();

    expect(identical(first, second), isTrue);
    expect(utils.createWithAuthCount, 1);
  });

  test('authenticated and unauthenticated services are created independently', () {
    final utils = TestChopperUtils();

    final withoutAuth = utils.getOpenApiWithoutAuth();
    final withAuth = utils.getOpenApiWithAuth();

    expect(identical(withoutAuth, withAuth), isFalse);
    expect(utils.createWithoutAuthCount, 1);
    expect(utils.createWithAuthCount, 1);
  });

  test('getCommonHeaders returns expected headers', () {
    final utils = TestChopperUtils();

    final headers = utils.getCommonHeaders();

    expect(headers['accept'], 'application/json');
    expect(headers['x-appversion'], '1.0.0');
  });

  test('getAuthHeaders contains bearer token', () {
    final utils = TestChopperUtils(
      accessToken: 'different-token',
    );

    final headers = utils.getAuthHeaders('abc123');

    expect(headers['Authorization'], 'Bearer abc123');
  });
}
