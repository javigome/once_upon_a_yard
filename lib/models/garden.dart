import 'package:cloud_firestore/cloud_firestore.dart';

class Garden {
  final String id;
  final String ownerId;
  final String name;
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
    required this.name,
    this.createdAt,
    this.isActive = true,
  });

  factory Garden.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Garden(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      name: data['name'] ?? 'Unknown',
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
      'name': name,
      'description': description,
      'location': location,
      'privacyLevel': privacyLevel,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'isActive': isActive,
    };
  }
}