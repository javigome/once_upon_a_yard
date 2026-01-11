import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSession {
  final String id;
  final String spotId;
  final List<String> participants;
  final String lastMessage;
  final DateTime? lastUpdated;
  final DateTime? scheduledTime;

  ChatSession({
    required this.id,
    required this.spotId,
    required this.participants,
    required this.lastMessage,
    this.lastUpdated,
    this.scheduledTime,
  });

  factory ChatSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatSession(
      id: doc.id,
      spotId: data['spotId'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
      scheduledTime: (data['scheduledTime'] as Timestamp?)?.toDate(),
    );
  }
}