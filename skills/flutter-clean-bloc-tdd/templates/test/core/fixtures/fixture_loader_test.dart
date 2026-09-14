import 'package:app_name/core/fixtures/fixture_loader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAssetBundle extends Mock implements AssetBundle {}

void main() {
  test('list decodes a JSON array from assets/fixtures/', () async {
    final bundle = _MockAssetBundle();
    when(
      () => bundle.loadString('assets/fixtures/things.json'),
    ).thenAnswer((_) async => '[{"id": "1"}, {"id": "2"}]');

    final items = await FixtureLoader(bundle).list('things.json');

    expect(items, [
      {'id': '1'},
      {'id': '2'},
    ]);
  });
}
