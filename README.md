# chopper_utils

Reusable authentication utilities for Chopper-generated OpenAPI clients, with common request headers, coordinated access-token refresh, automatic 401 retries, and optional HTTP logging.

---

## Features

- **Common Request Headers**: Automatically attaches `accept: application/json`, `x-appversion`, and `x-platform` to outgoing requests.
- **Separate Auth & Public Clients**: Lazy initialization for both authenticated and unauthenticated `ChopperService` instances.
- **Automatic Token Injection**: `OpenApiAuthInterceptor` injects the `Bearer` token on authenticated requests.
- **Coordinated Token Refresh**: Uses a `Completer` to deduplicate concurrent token refresh calls when multiple requests fail simultaneously.
- **Smart 401 Retry**: `OpenApiAuthenticator` handles automatic retries on `401 Unauthorized`:
  - Detects in-flight token changes from concurrent requests to avoid duplicate refresh calls.
  - Prevents infinite retry loops if a refreshed token still receives 401.
- **HTTP Logging**: Built-in flag to enable `HttpLoggingInterceptor` for debugging.

---

## Prerequisites & Assumptions

This package is designed around the following conventions:

1. **OpenAPI / Swagger Code Generation**:
   - You are using an OpenAPI code generator for Chopper (such as [`swagger_dart_code_generator`](https://pub.dev/packages/swagger_dart_code_generator)).
   - In the examples below, `Openapi` refers to the generated service class (typically output to `lib/openapi_generated_code/` or `lib/api/`) which exposes an `Openapi.create(...)` factory accepting Chopper interceptors and authenticators.
2. **Bearer Token Authentication**:
   - Your backend protects routes with `Bearer <token>` in the `authorization` header (customizable via `getAuthorizationHeader()` and `getAuthorizationHeaderName()`).
   - The backend responds with HTTP `401 Unauthorized` when an access token is expired or invalid.
3. **Refresh Token Endpoint**:
   - You have a public endpoint (accessible via `getOpenApiWithoutAuth()`) that accepts a refresh token and returns a new access token.
4. **Token Storage**:
   - Token persistence is left up to your application (e.g. `flutter_secure_storage`, `shared_preferences`, or in-memory). Your `ChopperUtils` subclass provides the token through `getAccessToken()` and updates it inside `refreshUserAccessTokenByOpenApi()`.
5. **Target Platforms**:
   - Android, iOS, Windows, macOS, and Linux. (uses `Platform.operatingSystem` for the `x-platform` header).

---

## Getting Started

Add `chopper_utils` to your `pubspec.yaml`:

```yaml
dependencies:
  chopper: ^8.4.0
  chopper_utils: ^0.0.1
```

---

## Usage

### 1. Subclass `ChopperUtils<T>`

Implement the abstract methods to provide your app's version, access token, and refresh logic:

```dart
import 'package:chopper_utils/chopper_utils.dart';
import 'openapi_generated_code/openapi.swagger.dart';

class AppChopperUtils extends ChopperUtils<Openapi> {
  AppChopperUtils({super.useHttpLogging});

  String? accessToken;
  String? refreshToken;

  @override
  String getAppVersion() => '1.0.0';

  @override
  String? getAccessToken() => accessToken;

  @override
  Openapi createOpenApiWithoutAuth() {
    return Openapi.create(
      baseUrl: Uri.parse('your server url string'),
      interceptors: getOpenApiHdrInterceptor(),
    );
  }

  @override
  Openapi createOpenApiWithAuth() {
    return Openapi.create(
      baseUrl: Uri.parse('your server url string'),
      interceptors: getOpenApiAuthInterceptor(),
      authenticator: OpenApiAuthenticator<Openapi>(this),
    );
  }

  @override
  Future<bool> refreshUserAccessTokenByOpenApi() async {
    if (refreshToken == null) return false;
    // Call your API's refresh endpoint using the unauthenticated client
    final response = await getOpenApiWithoutAuth().refreshToken(
      // pass your refresh token payload
    );
    if (!response.isSuccessful || response.body == null) {
      return false;
    }
    // Store the updated tokens
    accessToken = response.body!.accessToken;
    refreshToken = response.body!.refreshToken;
    return true;
  }
}
```

---

### 2. Making API Calls

Use `getOpenApiWithoutAuth()` for public endpoints (login, registration) and `getOpenApiWithAuth()` for protected endpoints:

```dart
final api = AppChopperUtils(useHttpLogging: true);

// Public call (unauthenticated) — e.g. login, register, or public resources
final loginResponse = await api.getOpenApiWithoutAuth().login(
  // your login parameters
);

// Store tokens returned from login so getAccessToken() and refresh logic can use them
if (loginResponse.isSuccessful && loginResponse.body != null) {
  api.accessToken = loginResponse.body!.accessToken;
  api.refreshToken = loginResponse.body!.refreshToken;
}

// Protected call (automatically injects Bearer token and retries on 401)
final dataResponse = await api.getOpenApiWithAuth().getProtectedData();
```

---

## 3. Customizing Headers

`ChopperUtils` provides flexible options for customizing request headers.

For simple use cases, you can customize individual headers such as **Authorization** header format and name, **App Version** header name, or **Platform** header name.

For more advanced use cases, you can override `getCommonHeaders()` and/or `getAuthHeaders()` to customize the complete set of headers used by the client.

### Customizing Individual Headers

You can override the individual header methods provided by `ChopperUtils`:

```dart
class AppChopperUtils extends ChopperUtils<Openapi> {
  @override
  String getAuthorizationHeader(String accessToken) {
    return 'Token $accessToken';
  }

  @override
  String getAuthorizationHeaderName() => 'X-API-Key';

  @override
  String getAppVersionHeaderName() => 'X-App-Version';

  @override
  String getPlatformHeaderName() => 'X-Platform';
}
```

### Customizing Complete Header Sets

If you need more control over the headers, you can override `getCommonHeaders()` and/or `getAuthHeaders()`.

`getCommonHeaders()` defines the headers shared by requests.

By default, `getAuthHeaders()` includes the headers returned by `getCommonHeaders()` and adds the authentication-specific headers.

```dart
class AppChopperUtils extends ChopperUtils<Openapi> {
  @override
  Map<String, String> getCommonHeaders() {
    return {
      'accept': 'application/json',
      'x-app-version': '1.2.3',
      'x-platform': Platform.operatingSystem,
      'x-custom-header': 'custom-value',
    };
  }

  @override
  Map<String, String> getAuthHeaders(String accessToken) {
    return {
      ...getCommonHeaders(),
      'x-custom-auth-header': 'custom-value',
    };
  }
}
```

When overriding `getAuthHeaders()`, include `getCommonHeaders()` if you want to retain the common headers defined by your `ChopperUtils` implementation.

You can also add or override authentication-specific headers in the returned map. If the same header name is present in both maps, the value defined in `getAuthHeaders()` takes precedence.

If you want complete control over authenticated request headers, you can omit `getCommonHeaders()` and return your own set of headers instead:

```dart
@override
Map<String, String> getAuthHeaders(String accessToken) {
  return {
    'authorization': 'Bearer $accessToken',
  };
}
```

Use the individual header methods when you only need to change specific headers. Use `getCommonHeaders()` and/or `getAuthHeaders()` when you need more control over the complete set of request headers.

---

### Recommended: Centralize API Access

For larger applications, it is recommended to keep a single `ChopperUtils` instance and expose API operations through dedicated service functions.

This keeps client creation, authentication, token refresh, and error handling in one place. Callers do not need to know how the Chopper clients are configured.

A typical implementation can use a singleton:

```dart
class AppChopperUtils extends ChopperUtils<Openapi> {
  AppChopperUtils._() : super(useHttpLogging: true); // enable http logging or just use AppChopperUtils._();

  static final AppChopperUtils instance = AppChopperUtils._();

  factory AppChopperUtils() => instance;

  String? accessToken;
  String? refreshToken;

  // ... ChopperUtils implementation
}
```

> **Note:** `ChopperUtils` does not provide persistent storage for access or refresh tokens. This is intentional. Token storage is application-specific and is usually part of the application's existing user/session data management. For example, an application may already persist the user's profile and authentication data using its chosen storage solution. Providing another storage mechanism here would therefore be redundant and could unnecessarily constrain the application's architecture.

API operations can then use the shared instance and return a `FutureResult`:

`FutureResult` provides a consistent way to represent either a successful result or an error without throwing exceptions from the service layer. This makes API calls easier to consume and keeps error handling consistent across the application.

For more information, see the [`future_result`](https://pub.dev/packages/future_result) package.

```dart
Future<FutureResult<Response<Message>>> getPrivateMessage() async {
  final Openapi api = AppChopperUtils().getOpenApiWithAuth();
  try {
    final response = await api.privateMessageGet();
    if (response.isSuccessful) {
      return FutureResult.success(response);
    }
    return FutureResult.error('api.privateMessageGet failed. Status: ${response.statusCode}, error: ${response.error}',
    );
  } catch (e) {
    return FutureResult.error('api.privateMessageGet caught an exception: ${e.toString()}.');
  }
}
```

The rest of the application can call the operation without dealing with Chopper configuration:

```dart
final result = await getPrivateMessage();
if (result.hasError) {
  // Handle error
} else {
  final response = result.value;
  // Use response
}
```

This approach has several advantages:
- API client configuration is centralized.
- Authentication and token refresh remain encapsulated in `ChopperUtils`.
- API operations can expose a simple interface to the rest of the application.
- Service-layer API calls can consistently use `FutureResult` for error handling.
- The application does not need to know whether a request uses an authenticated or unauthenticated Chopper client.

For small applications, calling `getOpenApiWithoutAuth()` and `getOpenApiWithAuth()` directly is also perfectly valid.

For a complete implementation of this approach, see the example:
- [`example_chopper_utils.dart`](example/lib/example_chopper_utils.dart) — shared `ChopperUtils` instance and client configuration
- [`example_client_calls.dart`](example/lib/example_client_calls.dart) — API operations built on top of the shared instance


### Reacting to a Failed Token Refresh

`refreshUserAccessTokenCompleterByOpenApi()` can be overridden in your `ChopperUtils` implementation if the application needs to react when refreshing the access token fails.

For example, an application may want to invalidate its local session and notify the UI so that the user can log in again:

```dart
@override
Future<bool> refreshUserAccessTokenCompleterByOpenApi() async {
  final success = await super.refreshUserAccessTokenCompleterByOpenApi();
  if (!success) {
    // Notify the application that the user session has expired.
    // For example: authStateController.sessionExpired();
  }
  return success;
}
```

The base implementation coalesces concurrent refresh requests, so only one refresh operation is performed when multiple requests fail with `401` at the same time. However, multiple callers can still receive the resulting `false` value. If the application reacts to the failure by triggering a global logout or navigation, make sure that this reaction is handled only once.

---

## How 401 Handling Works

1. **First 401**: When a request fails with `401 Unauthorized`, `OpenApiAuthenticator` triggers `refreshUserAccessTokenCompleterByOpenApi()`.
2. **Concurrent Requests**: If multiple requests fail with `401` around the same time, the first one initiates the refresh; any others wait on the same `Completer`.
3. **In-flight Detection**: If a request's 401 response arrives *after* another request has already refreshed the token, it immediately retries with the new token without triggering a redundant refresh.
4. **Loop Protection**: If a retried request still fails with 401 using the refreshed token, the authenticator returns `null`, preventing infinite retry loops.
