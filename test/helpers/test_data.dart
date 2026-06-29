// test/helpers/test_data.dart
//
// Shared test fixtures and factory functions for constructing model instances
// with sensible defaults. Each factory accepts named parameters to override
// specific fields for targeted test scenarios.

import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';

/// Creates a [UserModel] with sensible defaults for testing.
UserModel testUserModelFull({
  int id = 1,
  String fullName = 'Test User',
  String email = 'test@example.com',
  String phone = '+919876543210',
  String? profileImageUrl,
  bool isProfileComplete = true,
  String propertyPurpose = 'buy',
}) {
  return UserModel.fromJson({
    'id': id,
    'full_name': fullName,
    'email': email,
    'phone': phone,
    'profile_image_url': profileImageUrl,
    'is_profile_complete': isProfileComplete,
    'property_purpose': propertyPurpose,
    'created_at': '2024-01-15T10:30:00Z',
    'last_login': '2024-06-20T14:22:00Z',
    'preferences': {
      'push_notifications': true,
      'email_notifications': true,
      'similar_properties': true,
    },
  });
}

/// Creates a minimal [PropertyModel] JSON map for testing.
Map<String, dynamic> testPropertyJson({
  int id = 100,
  String title = 'Test Property',
  double basePrice = 5000000.0,
  String propertyType = 'house',
  String purpose = 'buy',
  int bedrooms = 3,
  int bathrooms = 2,
  double areaValue = 1200.0,
  String areaUnit = 'sqft',
  bool isActive = true,
  String? mainImage,
  List<String>? galleryImages,
  double? latitude,
  double? longitude,
}) {
  return {
    'id': id,
    'title': title,
    'base_price': basePrice,
    'property_type': propertyType,
    'purpose': purpose,
    'bedrooms': bedrooms,
    'bathrooms': bathrooms,
    'area_value': areaValue,
    'area_unit': areaUnit,
    'is_active': isActive,
    'main_image': mainImage ?? 'https://example.com/image1.jpg',
    'gallery_image_urls':
        galleryImages ?? ['https://example.com/image1.jpg', 'https://example.com/image2.jpg'],
    'latitude': latitude ?? 28.6139,
    'longitude': longitude ?? 77.2090,
    'address': 'Test Address, New Delhi',
    'city': 'New Delhi',
    'state': 'Delhi',
    'country': 'India',
    'description': 'A beautiful test property with modern amenities.',
    'view_count': 42,
    'like_count': 15,
    'interest_count': 8,
    'created_at': '2024-03-10T08:00:00Z',
    'amenities': [
      {'id': 1, 'name': 'Swimming Pool', 'icon': 'pool'},
      {'id': 2, 'name': 'Gym', 'icon': 'fitness_center'},
    ],
    'virtual_tour_url': null,
    'video_url': null,
    'floor_plan_url': null,
  };
}

/// Creates a [VisitModel] JSON map for testing.
Map<String, dynamic> testVisitJson({
  int id = 1,
  int propertyId = 100,
  String status = 'scheduled',
  String? visitDate,
  String? visitTime,
  String? scheduledDate,
  bool isUpcoming = true,
}) {
  return {
    'id': id,
    'property_id': propertyId,
    'user_id': 1,
    'status': status,
    'visit_date': visitDate ?? '2025-01-15',
    'visit_time': visitTime ?? '10:00:00',
    'scheduled_date': scheduledDate,
    'notes': 'Looking forward to visiting',
    'property': testPropertyJson(id: propertyId),
    'agent': testAgentJson(),
    'created_at': '2024-12-01T10:00:00Z',
  };
}

/// Creates an [AgentModel] JSON map for testing.
Map<String, dynamic> testAgentJson({
  int id = 1,
  String name = 'Test Agent',
  String phone = '+919876543211',
  String email = 'agent@360ghar.com',
}) {
  return {
    'id': id,
    'full_name': name,
    'phone': phone,
    'email': email,
    'profile_image_url': 'https://example.com/agent.jpg',
    'is_active': true,
  };
}

/// Creates a [UnifiedFilterModel] for testing.
UnifiedFilterModel testFilterModel({
  String purpose = 'buy',
  List<String> propertyType = const ['house'],
  double? priceMin,
  double? priceMax,
  int? bedroomsMin,
}) {
  return UnifiedFilterModel(
    purpose: purpose,
    propertyType: propertyType,
    priceMin: priceMin,
    priceMax: priceMax,
    bedroomsMin: bedroomsMin,
  );
}

/// Creates a list of test property JSON maps.
List<Map<String, dynamic>> testPropertyJsonList({int count = 5}) {
  return List.generate(
    count,
    (i) => testPropertyJson(
      id: 100 + i,
      title: 'Property ${i + 1}',
      basePrice: 3000000.0 + (i * 1000000),
    ),
  );
}

/// Creates a paginated property response JSON.
Map<String, dynamic> testPropertyResponseJson({
  int count = 5,
  bool hasMore = false,
  String? nextCursor,
}) {
  return {
    'properties': testPropertyJsonList(count: count),
    'has_more': hasMore,
    'next_cursor': nextCursor,
    'total_count': count,
  };
}
