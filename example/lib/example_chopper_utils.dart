import 'package:chopper_utils/chopper_utils.dart';
import 'package:http/http.dart' as http;
import 'openapi_generated_code/openapi.swagger.dart';
import 'test_client.dart';

class ExampleChopperUtils extends ChopperUtils<Openapi> {
  ExampleChopperUtils._() : testClient = createTestClient();

  static final ExampleChopperUtils instance = ExampleChopperUtils._();

  factory ExampleChopperUtils() => instance;

  final http.Client testClient;

  String? accessToken;
  String? refreshToken;

  @override
  String getAppVersion() => '1.0.0';

  @override
  String? getAccessToken() => accessToken;

  @override
  Openapi createOpenApiWithoutAuth() {
    return Openapi.create(httpClient: testClient, interceptors: getOpenApiHdrInterceptor());
  }

  @override
  Openapi createOpenApiWithAuth() {
    return Openapi.create(
      httpClient: testClient,
      interceptors: getOpenApiAuthInterceptor(),
      authenticator: OpenApiAuthenticator<Openapi>(this),
    );
  }

  @override
  Future<bool> refreshUserAccessTokenByOpenApi() async {
    if (refreshToken == null) {
      return false;
    }
    final response = await getOpenApiWithoutAuth().authRefreshPost(
      body: RefreshTokenRequest(refreshToken: refreshToken!),
    );
    if (!response.isSuccessful || (response.body == null)) {
      return false;
    }
    accessToken = response.body!.accessToken;
    refreshToken = response.body!.refreshToken;
    return true;
  }
}
