import 'package:app_name/core/config/env.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

/// Registrations for third-party types.
@module
abstract class RegisterModule {
  /// Shared HTTP client for the REST API.
  @Environment(Env.api)
  @lazySingleton
  Dio get dio => Dio()..options.baseUrl = AppConfig.apiBaseUrl;

  /// Asset bundle used by `FixtureLoader`.
  @lazySingleton
  AssetBundle get assetBundle => rootBundle;
}
