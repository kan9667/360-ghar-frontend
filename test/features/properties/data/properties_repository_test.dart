// test/features/properties/data/properties_repository_test.dart
//
// Unit tests for [PropertiesRepository]. Covers:
// - getProperties success
// - getProperties error propagation
// - getPropertyDetail success
// - getPropertiesByIds handles individual failures gracefully (batch with try/catch)

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/properties/data/datasources/properties_remote_datasource.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/getx_test_binding.dart';
import '../../../helpers/mocks.dart';

void main() {
  late MockPropertiesRemoteDatasource mockRemoteDatasource;
  late MockApiClient mockApiClient;
  late PropertiesRepository repository;

  setUpAll(() {
    registerFallbackValue(const UnifiedFilterModel());
    registerFallbackValue(<int>[]);
  });

  setUp(() {
    GetxTestBinding.init();
    mockRemoteDatasource = MockPropertiesRemoteDatasource();
    mockApiClient = MockApiClient();

    GetxTestBinding.bind()
      ..register<PropertiesRemoteDatasource>(mockRemoteDatasource)
      ..register<ApiClient>(mockApiClient);

    repository = PropertiesRepository();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('PropertiesRepository', () {
    // ── getProperties success ──────────────────────────────────────────

    test('getProperties returns response on success', () async {
      final expectedResponse = testPropertyResponse(
        items: [testPropertyModel(id: 1), testPropertyModel(id: 2)],
        hasMore: false,
      );

      when(
        () => mockRemoteDatasource.fetchProperties(
          filters: any(named: 'filters'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          radiusKm: any(named: 'radiusKm'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          excludeSwiped: any(named: 'excludeSwiped'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => expectedResponse);

      final result = await repository.getProperties(
        filters: const UnifiedFilterModel(),
        cursor: null,
        limit: 20,
        latitude: 28.6139,
        longitude: 77.2090,
      );

      expect(result.items.length, 2);
      expect(result.hasMore, false);
      expect(result.items.first.id, 1);
    });

    // ── getProperties error propagation ────────────────────────────────

    test('getProperties propagates AppException', () async {
      when(
        () => mockRemoteDatasource.fetchProperties(
          filters: any(named: 'filters'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          radiusKm: any(named: 'radiusKm'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          excludeSwiped: any(named: 'excludeSwiped'),
          useCache: any(named: 'useCache'),
        ),
      ).thenThrow(NetworkException('No internet'));

      expect(
        () => repository.getProperties(
          filters: const UnifiedFilterModel(),
          cursor: null,
          limit: 20,
          latitude: 28.6139,
          longitude: 77.2090,
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('getProperties propagates unexpected exceptions', () async {
      when(
        () => mockRemoteDatasource.fetchProperties(
          filters: any(named: 'filters'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          radiusKm: any(named: 'radiusKm'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          excludeSwiped: any(named: 'excludeSwiped'),
          useCache: any(named: 'useCache'),
        ),
      ).thenThrow(Exception('Unexpected'));

      expect(
        () => repository.getProperties(
          filters: const UnifiedFilterModel(),
          cursor: null,
          limit: 20,
          latitude: 28.6139,
          longitude: 77.2090,
        ),
        throwsA(isA<Exception>()),
      );
    });

    // ── getPropertyDetail success ──────────────────────────────────────

    test('getPropertyDetail returns property on success', () async {
      final property = testPropertyModel(id: 42);

      when(() => mockRemoteDatasource.fetchPropertyById('42')).thenAnswer((_) async => property);

      final result = await repository.getPropertyDetail(42);

      expect(result.id, 42);
      expect(result.title, 'Test Property 42');
    });

    test('getPropertyDetail propagates AppException', () async {
      when(
        () => mockRemoteDatasource.fetchPropertyById('99'),
      ).thenThrow(NetworkException('Timeout'));

      expect(() => repository.getPropertyDetail(99), throwsA(isA<NetworkException>()));
    });

    // ── getPropertiesByIds ─────────────────────────────────────────────

    test('getPropertiesByIds returns empty list for empty input', () async {
      final result = await repository.getPropertiesByIds([]);

      expect(result, isEmpty);
    });

    test('getPropertiesByIds returns results from batch endpoint', () async {
      final properties = [testPropertyModel(id: 1), testPropertyModel(id: 2)];

      when(
        () => mockRemoteDatasource.fetchPropertiesByIds(any()),
      ).thenAnswer((_) async => properties);

      final result = await repository.getPropertiesByIds([1, 2]);

      expect(result.length, 2);
      expect(result.first.id, 1);
    });

    test('getPropertiesByIds falls back to individual fetch on batch failure', () async {
      when(
        () => mockRemoteDatasource.fetchPropertiesByIds(any()),
      ).thenThrow(Exception('Batch endpoint not supported'));

      // Individual fetch succeeds
      when(() => mockRemoteDatasource.fetchPropertyById(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments[0] as String;
        return testPropertyModel(id: int.parse(id));
      });

      final result = await repository.getPropertiesByIds([10, 20, 30]);

      expect(result.length, 3);
      expect(result.map((p) => p.id), containsAll([10, 20, 30]));
    });

    test('getPropertiesByIds handles individual failures gracefully', () async {
      when(
        () => mockRemoteDatasource.fetchPropertiesByIds(any()),
      ).thenThrow(Exception('Batch failed'));

      // Individual fetches: id=10 succeeds, id=20 fails, id=30 succeeds
      when(() => mockRemoteDatasource.fetchPropertyById(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments[0] as String;
        if (id == '20') throw Exception('Not found');
        return testPropertyModel(id: int.parse(id));
      });

      final result = await repository.getPropertiesByIds([10, 20, 30]);

      // Should have 2 results (id=20 was skipped)
      expect(result.length, 2);
      expect(result.map((p) => p.id), containsAll([10, 30]));
    });

    test('getPropertiesByIds returns empty when all individual fetches fail', () async {
      when(
        () => mockRemoteDatasource.fetchPropertiesByIds(any()),
      ).thenThrow(Exception('Batch failed'));

      when(() => mockRemoteDatasource.fetchPropertyById(any())).thenThrow(Exception('All failed'));

      final result = await repository.getPropertiesByIds([1, 2]);

      expect(result, isEmpty);
    });
  });
}
