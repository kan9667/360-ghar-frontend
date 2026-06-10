import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/unified_filter_model.dart';

void main() {
  group('UnifiedFilterModel.toApiQueryParams', () {
    test('normalizes purpose/property_type and remaps date keys', () {
      final filters = UnifiedFilterModel(
        purpose: 'shortStay',
        propertyType: ['Apartment', 'builderFloor', 'Loft', 'flatmate', 'All'],
        checkInDate: DateTime(2026, 2, 1),
        checkOutDate: DateTime(2026, 2, 3),
        propertyIds: [7, 9],
        genderPreference: 'Female',
        sharingType: 'shared room',
      );

      final params = filters.toApiQueryParams();

      expect(params['purpose'], 'short_stay');
      expect(params['property_type'], ['apartment', 'builder_floor', 'loft', 'flatmate']);
      expect(params['check_in'], '2026-02-01');
      expect(params['check_out'], '2026-02-03');
      expect(params['ids'], [7, 9]);
      expect(params['gender_preference'], 'female');
      expect(params['sharing_type'], 'shared_room');
      expect(params.containsKey('check_in_date'), isFalse);
      expect(params.containsKey('check_out_date'), isFalse);
    });

    test('normalizes legacy property type aliases', () {
      final filters = const UnifiedFilterModel(
        purpose: 'pg',
        propertyType: ['flat', 'independent-house', 'plots', 'office-space', 'roommate'],
      );

      final params = filters.toApiQueryParams();

      expect(params['purpose'], 'rent');
      expect(params['property_type'], ['apartment', 'house', 'plot', 'office', 'flatmate']);
    });
  });

  group('LocationData parsing', () {
    test('fromJson throws on missing coordinates instead of defaulting to 0,0', () {
      expect(
        () => LocationData.fromJson({'name': 'Delhi', 'latitude': null, 'longitude': null}),
        throwsFormatException,
      );
    });

    test('tryFromJson returns null on missing coordinates and parses valid input', () {
      expect(LocationData.tryFromJson({'name': 'Delhi'}), isNull);
      expect(LocationData.tryFromJson(null), isNull);

      final location = LocationData.tryFromJson({
        'name': 'Delhi',
        'latitude': 28.6139,
        'longitude': 77.2090,
      });
      expect(location?.latitude, 28.6139);
      expect(location?.longitude, 77.2090);
    });
  });
}
