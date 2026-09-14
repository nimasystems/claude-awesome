import 'dart:convert';
import 'dart:io';

/// Reads `assets/fixtures/<name>` — the same bytes the mock data sources
/// load through `FixtureLoader`, so tests and the mock flavor cannot drift.
String fixture(String name) => File('assets/fixtures/$name').readAsStringSync();

/// Decodes a fixture holding a JSON array of objects.
List<Map<String, dynamic>> fixtureList(String name) =>
    (jsonDecode(fixture(name)) as List<dynamic>).cast<Map<String, dynamic>>();
