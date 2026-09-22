import 'dart:async';
import 'dart:io' show Platform;
import 'package:chopper/chopper.dart';
import 'package:result_utils/result_utils.dart';

abstract class ChopperUtils<T extends ChopperService> {
  ChopperUtils({this.useHttpLogging = false});

  final bool useHttpLogging;

  T? _openApiWithoutAuth;
  T? _openApiWithAuth;

  Completer<bool>? _refreshUserAccessTokenCompleter;

  /// === abstract functions which must be overwritten

  String getAppVersion(); // return the app version as string
  String? getAccessToken(); // return the current user's access token

  // refresh the user's accesss token with a refresh token
  Future<bool> refreshUserAccessTokenByOpenApi();

  T createOpenApiWithoutAuth(); // return the Openapi class to be used for server calls without authentification
  T createOpenApiWithAuth(); // return the Openapi class to be used for server calls with authentification

  /// === functions for optional overwriting headers

  /// Returns the authorization header value for the given access token.
  String getAuthorizationHeader(String accessToken) {
    return 'Bearer $accessToken';
  }

  /// Returns the header name used for authorization.
  String getAuthorizationHeaderName() => 'authorization';

  /// Returns the header name used for the app version.
  String getAppVersionHeaderName() => 'x-appversion';

  /// Returns the header name used for the client platform.
  String getPlatformHeaderName() => 'x-platform';

  /// === utility functions

  /// Returns standard headers sent with every request.
  Map<String, String> getCommonHeaders() {
    return {
      'accept': 'application/json',
      getAppVersionHeaderName(): getAppVersion(),
      getPlatformHeaderName(): Platform.operatingSystem,
    };
  }

  /// Returns standard headers combined with the authorization header.
  Map<String, String> getAuthHeaders(String accessToken) {
    return {
      ...getCommonHeaders(),
      getAuthorizationHeaderName(): getAuthorizationHeader(accessToken),
    };
  }

  /// Return the chopper/OpenApi class to be used for server calls without authentification
  T getOpenApiWithoutAuth() {
    return _openApiWithoutAuth ??= createOpenApiWithoutAuth();
  }

  /// Return the chopper/OpenApi class to be used for server calls with authentification
  T getOpenApiWithAuth() {
    return _openApiWithAuth ??= createOpenApiWithAuth();
  }

  /// Return the chopper/OpenApi interceptor for the extra parameters header but without authorization header.
  List<Interceptor> getOpenApiHdrInterceptor() {
    return [
      OpenApiHdrInterceptor<T>(this),
      if (useHttpLogging) HttpLoggingInterceptor(),
    ];
  }

  /// Return the chopper/OpenApi interceptor for the authorization header and the extra parameters.
  List<Interceptor> getOpenApiAuthInterceptor() {
    return [
      OpenApiAuthInterceptor<T>(this),
      if (useHttpLogging) HttpLoggingInterceptor(),
    ];
  }

  /// Checks whether an error is acceptable for automatic retry.
  bool isAcceptableOpenApiError({required String errorMsg}) {
    // check known errors of FutureBuilder snapshot and return true if just a reload can be executed.
    // Most of them are iOS resume errors (except connection lost).
    var acceptable = (errorMsg.contains('Connection closed') ||
        errorMsg.contains('Connection reset') ||
        errorMsg.contains('Bad file descriptor') ||
        errorMsg.contains('Read failed') ||
        errorMsg.contains('Write failed'));
    return acceptable;
  }

  /// Refreshes user access token using a completer to coalesce concurrent calls.
  Future<bool> refreshUserAccessTokenCompleterByOpenApi() async {
    if (_refreshUserAccessTokenCompleter != null) {
      return _refreshUserAccessTokenCompleter!.future;
    }
    _refreshUserAccessTokenCompleter = Completer<bool>();
    // Refresh token via service call and convert to FutureResult
    FutureResult result = await futureToResult(
      refreshUserAccessTokenByOpenApi(),
    );
    if (result.hasError) {
      // Complete completer with failure
      _refreshUserAccessTokenCompleter!.complete(false);
      _refreshUserAccessTokenCompleter = null;
      return false;
    } else {
      // Complete completer with refresh outcome
      _refreshUserAccessTokenCompleter!.complete(result.value);
      _refreshUserAccessTokenCompleter = null;
      return result.value;
    }
  }
}

/// ============== OpenApiHdrInterceptor ==============

/// OpenApiHdrInterceptor sets the extra header parameters.

class OpenApiHdrInterceptor<T extends ChopperService> implements Interceptor {
  const OpenApiHdrInterceptor(this.utils);

  final ChopperUtils<T> utils;

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(
    Chain<BodyType> chain,
  ) async {
    // Fetch common headers
    Map<String, String> headers = utils.getCommonHeaders();
    // Attach headers to request
    Request request = applyHeaders(chain.request, headers);
    // Proceed with the request execution chain
    Response<BodyType> response = await chain.proceed(request);
    return response;
  }
}

/// ============== OpenApiAuthInterceptor ==============

/// OpenApiAuthInterceptor sets the (possible refreshed) access token whenever a request will be send.

class OpenApiAuthInterceptor<T extends ChopperService> implements Interceptor {
  const OpenApiAuthInterceptor(this.utils);

  final ChopperUtils<T> utils;

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(
    Chain<BodyType> chain,
  ) async {
    // Retrieve current access token
    String? accessToken = utils.getAccessToken();
    if (accessToken == null) {
      // Forward request without adding auth headers
      return chain.proceed(chain.request);
    }
    // Prepare auth headers with access token
    Map<String, String> headers = utils.getAuthHeaders(accessToken);
    // Attach headers to request
    Request request = applyHeaders(chain.request, headers);
    // Proceed with the request execution chain
    Response<BodyType> response = await chain.proceed(request);
    return response;
  }
}

/// ============== OpenApiAuthenticator ==============

/// OpenApiAuthenticator handles the 401 error (access token invalid)
/// by refreshing the access token via refresh token (refreshUserAccessTokenByOpenApi),
/// setting the refreshed user data (in refreshUserAccessTokenByOpenApi)
/// and returning the request with the refreshed header authorization.

class OpenApiAuthenticator<T extends ChopperService> extends Authenticator {
  OpenApiAuthenticator(this.utils);

  final ChopperUtils<T> utils;

  @override
  FutureOr<Request?> authenticate(
    Request request,
    Response<dynamic> response, [
    Request? originalRequest,
  ]) async {
    if (response.statusCode == 401) {
      // Retrieve current access token
      final String? currentToken = utils.getAccessToken();
      if (currentToken == null) {
        return null; // return null to finish OpenApiAuthenticator.authenticate
      }
      // Read current authorization header value
      final String authHeaderName = utils.getAuthorizationHeaderName();
      final String currHeaderValue = utils.getAuthorizationHeader(currentToken);
      final String? usedHeaderValue = request.headers[authHeaderName];
      // If another concurrent request already refreshed the token while this
      // request was in flight, retry immediately with the new token without refreshing again.
      if (usedHeaderValue != currHeaderValue) {
        // Retry immediately using refreshed token
        return applyHeaders(request, utils.getAuthHeaders(currentToken));
      }
      // Refresh user access token
      var success = await utils.refreshUserAccessTokenCompleterByOpenApi();
      if (success) {
        // Retrieve newly refreshed access token
        String? newToken = utils.getAccessToken();
        // Prevent infinite loop: if the refreshed token is identical to what failed, retrying will just produce another 401.
        // Return only a new request with new token if the token is different.
        if ((newToken != null) && (newToken != currentToken)) {
          // Prepare new authorization headers
          Map<String, String> headers = utils.getAuthHeaders(newToken);
          // Build request with updated authorization headers
          Request newRequest = applyHeaders(request, headers);
          return newRequest; // return request with new token
        }
      }
    }
    return null; // return null to finish OpenApiAuthenticator.authenticate
  }
}
