import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

/// Loads JSON fixtures from `assets/fixtures/` for mock data sources.
@lazySingleton
class FixtureLoader {
  /// Creates a [FixtureLoader] reading from [_bundle].
  FixtureLoader(this._bundle);

  final AssetBundle _bundle;

  /// Decodes `assets/fixtures/<name>` as a JSON array of objects.
  Future<List<Map<String, dynamic>>> list(String name) async {
    final raw = await _bundle.loadString('assets/fixtures/$name');
    return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
