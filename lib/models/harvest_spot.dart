import 'package:cloud_firestore/cloud_firestore.dart';

class HarvestSpot {
  final String id;
  final String ownerId;
  final String plantName;
  final String category; // Fruit, Herb, etc.
  final String description;
  final String imageUrl;
  final GeoPoint location;
  final String privacyLevel; // exact, blurred, chat_only
  final DateTime? createdAt;
  final bool isActive;
  final String gardenId;
  final String ownerName;

  HarvestSpot({
    required this.id,
    required this.ownerId,
    required this.plantName,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.location,
    required this.privacyLevel,
    required this.gardenId,
    required this.ownerName,
    this.createdAt,
    this.isActive = true,
  });

  // Factory: Converts JSON (Map) from Firestore -> Dart Object
  factory HarvestSpot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HarvestSpot(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      plantName: data['plantName'] ?? 'Unknown',
      category: data['category'] ?? 'Other',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      privacyLevel: data['privacyLevel'] ?? 'blurred',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
      gardenId: data['gardenId'] ?? '',
      ownerName: data['ownerName'] ?? ''
    );
  }

  // Method: Converts Dart Object -> JSON (Map) for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'plantName': plantName,
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
      'location': location,
      'privacyLevel': privacyLevel,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'isActive': isActive,
      'gardenId': gardenId,
      'ownerName': ownerId
    };
  }
}