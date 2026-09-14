import 'package:app_name/app/di/injector.config.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

/// The service locator. Use only in bootstrap, pages and router guards.
final GetIt getIt = GetIt.instance;

/// Builds the dependency graph for [environment] (`Env.mock` / `Env.api`).
@InjectableInit()
Future<void> configureDependencies(String environment) async =>
    getIt.init(environment: environment);
