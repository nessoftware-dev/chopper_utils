# example

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Swagger / OpenApi

The package `swagger_dart_code_generator` (https://pub.dev/packages/swagger_dart_code_generator) is used for converting the OpenAPI specification to OpenAPI dart files.

Steps for creating the OpenAPI dart files:
1. Download file `openapi` from your Swagger UI.
3. Add `.yaml` extension to `openapi`
4. Copy `openapi.yaml` to folder `openapi_input_folder`.
5. Launch `Terminal`
6. Set current path to the flutter project
7. Execute swagger_dart_code_generator-build to generate OpenApi dart files (`dart run build_runner build --delete-conflicting-outputs`)
