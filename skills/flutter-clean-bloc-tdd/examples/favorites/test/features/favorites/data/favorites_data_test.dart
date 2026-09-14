import 'dart:convert';

import 'package:app_name/core/error/exceptions.dart';
import 'package:app_name/core/error/failures.dart';
import 'package:app_name/core/fixtures/fixture_loader.dart';
import 'package:app_name/core/logging/logger_service.dart';
import 'package:app_name/features/favorites/data/datasources/favorites_remote_data_source.dart';
import 'package:app_name/features/favorites/data/mappers/favorite_venue_mapper.dart';
import 'package:app_name/features/favorites/data/models/favorite_venue_dto.dart';
import 'package:app_name/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:app_name/features/favorites/domain/entities/favorite_venue.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';

class _MockRemote extends Mock implements FavoritesRemoteDataSource {}

/// Answers Dio requests with [handler] and records them.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

final _dto = FavoriteVenueDto(
  id: 'v1',
  name: 'Blue Note',
  imageUrl: 'https://picsum.photos/seed/v1/200',
  addedAt: DateTime.utc(2026, 9, 1, 18, 30),
);

final _entity = FavoriteVenue(
  id: 'v1',
  name: 'Blue Note',
  imageUrl: Uri.parse('https://picsum.photos/seed/v1/200'),
  addedAt: DateTime.utc(2026, 9, 1, 18, 30),
);

void main() {
  setUpAll(() => LoggerService.configure(Logger(level: Level.off)));

  group('FavoriteVenueDto + mapper', () {
    test('parses the fixture and maps every item to an entity', () {
      final entities = fixtureList(
        'favorites.json',
      ).map(FavoriteVenueDto.fromJson).map((d) => d.toEntity()).toList();

      expect(entities, hasLength(3));
      expect(entities.first, _entity);
    });

    test('normalises addedAt with an offset to UTC', () {
      final entity = FavoriteVenueDto.fromJson(
        fixtureList('favorites.json')[1],
      ).toEntity();

      expect(entity.addedAt.isUtc, isTrue);
      expect(entity.addedAt, DateTime.utc(2026, 8, 20, 7));
    });

    test('throws when a required field is missing', () {
      expect(
        () => FavoriteVenueDto.fromJson(const {'id': 'v1'}),
        throwsA(anything),
      );
    });
  });

  group('FavoritesApiDataSource', () {
    late Dio dio;
    late _FakeAdapter adapter;
    late FavoritesApiDataSource dataSource;

    void respond(Future<ResponseBody> Function(RequestOptions o) handler) {
      adapter = _FakeAdapter(handler);
      dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = adapter;
      dataSource = FavoritesApiDataSource(dio);
    }

    test('GET /v1/favorites returns parsed DTOs', () async {
      respond((_) async => _json(fixtureList('favorites.json')));

      final result = await dataSource.getFavorites();

      expect(result.map((d) => d.id), ['v1', 'v2', 'v3']);
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/v1/favorites');
    });

    test('DELETE /v1/favorites/{id} sends the id in the path', () async {
      respond((_) async => ResponseBody.fromString('', 204));

      await dataSource.removeFavorite('v1');

      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.path, '/v1/favorites/v1');
    });

    test('404 surfaces through the repository as NotFoundFailure', () async {
      respond((_) async => _json(const {'error': 'nope'}, 404));

      final result = await FavoritesRepositoryImpl(
        dataSource,
      ).removeFavorite('v1');

      expect(result.getLeft().toNullable(), isA<NotFoundFailure>());
    });

    test('connection error surfaces as NetworkFailure', () async {
      respond(
        (o) async => throw DioException.connectionError(
          requestOptions: o,
          reason: 'offline',
        ),
      );

      final result = await FavoritesRepositoryImpl(dataSource).getFavorites();

      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
    });
  });

  group('FavoritesMockDataSource', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late FavoritesMockDataSource dataSource;

    setUp(
      () => dataSource = FavoritesMockDataSource(FixtureLoader(rootBundle)),
    );

    test('loads the bundled fixture', () async {
      final result = await dataSource.getFavorites();

      expect(result.map((d) => d.id), ['v1', 'v2', 'v3']);
    });

    test('removed favorites are not returned again', () async {
      await dataSource.removeFavorite('v2');

      final result = await dataSource.getFavorites();

      expect(result.map((d) => d.id), ['v1', 'v3']);
    });
  });

  group('FavoritesRepositoryImpl', () {
    late _MockRemote remote;
    late FavoritesRepositoryImpl repository;

    setUp(() {
      remote = _MockRemote();
      repository = FavoritesRepositoryImpl(remote);
    });

    group('getFavorites', () {
      test('maps DTOs to entities on success', () async {
        when(remote.getFavorites).thenAnswer((_) async => [_dto]);

        final result = await repository.getFavorites();

        expect(result.getRight().toNullable(), [_entity]);
      });

      final cases = <(String, AppException, Matcher)>[
        (
          'ApiException 401 -> AuthFailure',
          const ApiException('unauthorized', statusCode: 401),
          isA<AuthFailure>(),
        ),
        (
          'ApiException 404 -> NotFoundFailure',
          const ApiException('missing', statusCode: 404),
          isA<NotFoundFailure>(),
        ),
        (
          'ApiException 500 -> ServerFailure(500)',
          const ApiException('boom', statusCode: 500),
          isA<ServerFailure>().having((f) => f.code, 'code', 500),
        ),
        (
          'NetworkException -> NetworkFailure',
          const NetworkException('offline'),
          isA<NetworkFailure>(),
        ),
      ];
      for (final (description, exception, matcher) in cases) {
        test(description, () async {
          when(remote.getFavorites).thenThrow(exception);

          final result = await repository.getFavorites();

          expect(result.getLeft().toNullable(), matcher);
        });
      }

      test('unexpected error maps to UnknownFailure (never throws)', () async {
        when(remote.getFavorites).thenThrow(const FormatException('bad json'));

        final result = await repository.getFavorites();

        expect(result.getLeft().toNullable(), isA<UnknownFailure>());
      });
    });

    group('removeFavorite', () {
      test('returns Right(unit) on success', () async {
        when(() => remote.removeFavorite('v1')).thenAnswer((_) async {});

        final result = await repository.removeFavorite('v1');

        expect(result, const Right<Failure, Unit>(unit));
        verify(() => remote.removeFavorite('v1')).called(1);
      });

      test('maps AppException to its failure', () async {
        when(
          () => remote.removeFavorite('v1'),
        ).thenThrow(const NetworkException('offline'));

        final result = await repository.removeFavorite('v1');

        expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      });

      test('unexpected error maps to UnknownFailure', () async {
        when(() => remote.removeFavorite('v1')).thenThrow(StateError('boom'));

        final result = await repository.removeFavorite('v1');

        expect(result.getLeft().toNullable(), isA<UnknownFailure>());
      });
    });
  });
}
