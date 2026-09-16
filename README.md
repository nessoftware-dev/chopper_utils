# chopper_utils

Reusable Chopper utilities for authenticated and unauthenticated API clients, common request headers, coordinated access-token refresh, automatic 401 retries, and optional HTTP logging.

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
   - Designed for native mobile and desktop platforms (uses `Platform.operatingSystem` for the `x-platform` header).

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
import 'package:http/http.dart' as http;
import 'openapi_generated_code/openapi.swagger.dart';

class ApiUtils extends ChopperUtils<Openapi> {
  ApiUtils({super.useHttpLogging});

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
final api = ApiUtils(useHttpLogging: true);

// Public call (unauthenticated) — e.g. login, register, or public resources
final loginResponse = await api.getOpenApiWithoutAuth().login(
  // your login parameters
);

// Protected call (automatically injects Bearer token and retries on 401)
final dataResponse = await api.getOpenApiWithAuth().getProtectedData();
```

---

### 3. Customizing Headers

You can override default header names or formats:

```dart
class CustomApiUtils extends ChopperUtils<Openapi> {
  // Customize header names
  @override
  String getAppVersionHeaderName() => 'x-client-version';

  @override
  String getPlatformHeaderName() => 'x-os';

  // Customize token format
  @override
  String getAuthorizationHeader(String accessToken) => 'JWT $accessToken';
}
```

---

## How 401 Handling Works

1. **First 401**: When a request fails with `401 Unauthorized`, `OpenApiAuthenticator` triggers `refreshUserAccessTokenCompleterByOpenApi()`.
2. **Concurrent Requests**: If multiple requests fail with `401` around the same time, the first one initiates the refresh; any others wait on the same `Completer`.
3. **In-flight Detection**: If a request's 401 response arrives *after* another request has already refreshed the token, it immediately retries with the new token without triggering a redundant refresh.
4. **Loop Protection**: If a retried request still fails with 401 using the refreshed token, the authenticator returns `null`, preventing infinite retry loops.
