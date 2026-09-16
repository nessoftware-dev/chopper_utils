import 'package:chopper/chopper.dart' show Response;
import 'package:result_utils/result_utils.dart';
import 'package:example/example_chopper_utils.dart';
import 'package:example/openapi_generated_code/openapi.swagger.dart';

// Logs in using the unauthenticated OpenApi client.

Future<FutureResult<Response<AuthResponse>>> login(
  ExampleChopperUtils chopperUtils, {
  required String username,
  required String password,
}) async {
  late final Response<AuthResponse> response;
  try {
    response = await chopperUtils.getOpenApiWithoutAuth().authLoginPost(
      body: LoginRequest(username: username, password: password),
    );
  } catch (e) {
    return FutureResult.error(e.toString());
  }
  if (response.isSuccessful && response.body != null) {
    return FutureResult.success(response);
  } else {
    return FutureResult.error('Status: ${response.statusCode}, error: ${response.error}');
  }
}

// Logs out using the authenticated OpenApi client.

Future<FutureResult<Response>> logout(ExampleChopperUtils chopperUtils) async {
  late final Response response;
  try {
    response = await chopperUtils.getOpenApiWithAuth().authLogoutPost();
  } catch (e) {
    return FutureResult.error(e.toString());
  }
  if (response.isSuccessful) {
    return FutureResult.success(response);
  } else {
    return FutureResult.error('Status: ${response.statusCode}, error: ${response.error}');
  }
}

// Manually refreshes the access token via `refreshUserAccessTokenByOpenApi`.

Future<FutureResult<bool>> refreshAccessToken(ExampleChopperUtils chopperUtils) async {
  late final bool success;
  try {
    success = await chopperUtils.refreshUserAccessTokenByOpenApi();
  } catch (e) {
    return FutureResult.error(e.toString());
  }
  if (success) {
    return FutureResult.success(true);
  } else {
    return FutureResult.error('refreshUserAccessTokenByOpenApi returned false');
  }
}

// Fetches the public message using the unauthenticated OpenApi client.

Future<FutureResult<Response<Message>>> getPublicMessage(ExampleChopperUtils chopperUtils) async {
  late final Response<Message> response;
  try {
    response = await chopperUtils.getOpenApiWithoutAuth().publicMessageGet();
  } catch (e) {
    return FutureResult.error(e.toString());
  }
  if (response.isSuccessful) {
    return FutureResult.success(response);
  } else {
    return FutureResult.error('Status: ${response.statusCode}, error: ${response.error}');
  }
}

/// Fetches the private message using the authenticated OpenApi client.
///
/// If the current access token is expired, OpenApiAuthenticator intercepts
/// the 401 response, refreshes the token, and retries automatically.

Future<FutureResult<Response<Message>>> getPrivateMessage(ExampleChopperUtils chopperUtils) async {
  late final Response<Message> response;
  try {
    response = await chopperUtils.getOpenApiWithAuth().privateMessageGet();
  } catch (e) {
    return FutureResult.error(e.toString());
  }
  if (response.isSuccessful) {
    return FutureResult.success(response);
  } else {
    return FutureResult.error('Status: ${response.statusCode}, error: ${response.error}');
  }
}
