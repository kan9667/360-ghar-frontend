// test/features/explore/data/properties_remote_datasource_test.dart
//
// Unit tests for [PropertiesRemoteDatasource].
// Mocks [ApiClient] to verify property fetching, single-property detail,
// and response parsing (including envelope normalization).

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/properties/data/datasources/properties_remote_datasource.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/test_data.dart';

void main() {
  late MockApiClient apiClient;
  late PropertiesRemoteDatasource datasource;

  setUp(() {
    apiClient = MockApiClient();
    datasource = PropertiesRemoteDatasource(apiClient);
  });

  /// Stubs a GET request to the properties endpoint (any query params).
  void stubPropertiesGet(dynamic body) {
    when(
      () => apiClient.get(
        ApiPaths.properties,
        queryParams: any(named: 'queryParams'),
        useCache: any(named: 'useCache'),
      ),
    ).thenAnswer((_) async => ApiResponse(statusCode: 200, body: body, headers: {}));
  }

  group('fetchProperties', () {
    test('returns parsed properties on success', () async {
      final propertyJsonList = testPropertyJsonList(count: 3);
      stubPropertiesGet({'items': propertyJsonList, 'has_more': false, 'limit': 20});

      final response = await datasource.fetchProperties(
        latitude: 28.6139,
        longitude: 77.2090,
        radiusKm: 10,
        filters: const UnifiedFilterModel(),
      );

      expect(response.items.length, 3);
      expect(response.items.first.title, 'Property 1');
      expect(response.hasMore, isFalse);
    });

    test('handles nested data envelope', () async {
      final propertyJsonList = testPropertyJsonList(count: 2);
      // Response wrapped in { data: { items: [...], has_more: true, ... } }
      stubPropertiesGet({
        'data': {'items': propertyJsonList, 'has_more': true, 'next_cursor': 'abc123', 'limit': 20},
      });

      final response = await datasource.fetchProperties(
        latitude: 28.6139,
        longitude: 77.2090,
        radiusKm: 10,
        filters: const UnifiedFilterModel(),
      );

      expect(response.items.length, 2);
      expect(response.hasMore, isTrue);
      expect(response.nextCursor, 'abc123');
    });

    test('handles bare list response gracefully', () async {
      final propertyJsonList = testPropertyJsonList(count: 1);
      stubPropertiesGet(propertyJsonList);

      final response = await datasource.fetchProperties(
        latitude: 28.6139,
        longitude: 77.2090,
        radiusKm: 10,
        filters: const UnifiedFilterModel(),
      );

      expect(response.items.length, 1);
    });

    test('propagates API exception', () async {
      when(
        () => apiClient.get(
          ApiPaths.properties,
          queryParams: any(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).thenThrow(ServerException('Server down', statusCode: 500));

      expect(
        () => datasource.fetchProperties(
          latitude: 28.6139,
          longitude: 77.2090,
          radiusKm: 10,
          filters: const UnifiedFilterModel(),
        ),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('fetchPropertyById', () {
    test('returns a PropertyModel on success', () async {
      when(
        () => apiClient.get(ApiPaths.propertyById('42'), useCache: any(named: 'useCache')),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: testPropertyJson(id: 42, title: 'Sea View Villa'),
          headers: {},
        ),
      );

      final property = await datasource.fetchPropertyById('42');

      expect(property.title, 'Sea View Villa');
      expect(property.id, 42);
    });

    test('unwraps data envelope for single property', () async {
      when(
        () => apiClient.get(ApiPaths.propertyById('99'), useCache: any(named: 'useCache')),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: {'data': testPropertyJson(id: 99, title: 'Penthouse')},
          headers: {},
        ),
      );

      final property = await datasource.fetchPropertyById('99');
      expect(property.title, 'Penthouse');
    });

    test('throws FormatException when response body is empty', () async {
      when(
        () => apiClient.get(ApiPaths.propertyById('1'), useCache: any(named: 'useCache')),
      ).thenAnswer(
        (_) async => ApiResponse(statusCode: 200, body: <String, dynamic>{}, headers: {}),
      );

      expect(() => datasource.fetchPropertyById('1'), throwsA(isA<FormatException>()));
    });
  });
}
