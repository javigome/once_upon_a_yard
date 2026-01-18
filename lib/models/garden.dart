import 'package:cloud_firestore/cloud_firestore.dart';

class Garden {
  final String id;
  final String ownerId;
  final String gardenName;
  final String description;
  final GeoPoint location;
  final String privacyLevel; // exact, blurred, chat_only
  final DateTime? createdAt;
  final bool isActive;

  Garden({
    required this.id, 
    required this.ownerId, 
    required this.description, 
    required this.location, 
    required this.privacyLevel, 
    required this.gardenName,
    this.createdAt,
    this.isActive = true,
  });

  factory Garden.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Garden(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      gardenName: data['gardenName'] ?? 'Unknown',
      description: data['description'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
      privacyLevel: data['privacyLevel'] ?? 'blurred'
    );
  }

   Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'gardenName': gardenName,
      'description': description,
      'location': location,
      'privacyLevel': privacyLevel,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'isActive': isActive,
    };
  }
}