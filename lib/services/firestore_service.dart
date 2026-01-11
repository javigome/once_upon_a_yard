import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart'; // Add this to pubspec if missing
import 'package:firebase_auth/firebase_auth.dart';
import '../models/harvest_spot.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  // Helper to get current ID
  String get _uid => _auth.currentUser?.uid ?? '';

  // --- 1. WRITE: Create a new Harvest Spot ---
  Future<void> addHarvestSpot({
    required File imageFile,
    required String plantName,
    required String category,
    required String description,
    required double lat,
    required double lng,
    required String privacyLevel, // 'exact', 'blurred', 'chat_only'
    String? ownerId,
    // required Array months
    }) async {
    try {
      // Step A: Upload the Image to Storage
      // We use a unique ID so files don't overwrite each other
      String fileName = 'harvests/${_uuid.v4()}.jpg';
      Reference ref = _storage.ref().child(fileName);
      
      UploadTask uploadTask = ref.putFile(imageFile);
      
      TaskSnapshot snapshot = await uploadTask;
      
      // Step B: Get the public download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Step C: Save Metadata to Firestore
      await _db.collection('harvest_spots').add({
        'plantName': plantName,
        'category': category, // "Fruit", "Herb", etc.
        'description': description,
        'imageUrl': downloadUrl,
        'location': GeoPoint(lat, lng), // Native Firestore location type
        'privacyLevel': privacyLevel,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'ownerId': _uid, // Placeholder until Auth is fully linked
      });

    }on FirebaseException catch (e) {
        // Handle specific errors like 'permission-denied' or 'canceled'
      print("Upload failed: ${e.code}");
    } 
    catch (e) {
      print("Error adding harvest: $e");
      throw Exception('Failed to upload harvest spot');
    }
  }

  // --- 2. READ: Get Stream of Spots for the Map ---
  // We use a Stream so the map updates in REAL-TIME if someone adds a spot nearby.
  Stream<List<HarvestSpot>> getHarvestSpots() {
    return _db.collection('harvest_spots')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
         return snapshot.docs.map((doc) => HarvestSpot.fromFirestore(doc)).toList();
        });
  }

  // --- 3. READ: Get Single Spot Details ---
  Future<Map<String, dynamic>?> getSpotDetails(String spotId) async {
    DocumentSnapshot doc = await _db.collection('harvest_spots').doc(spotId).get();
    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    }
    return null;
  }

  // --- 4. CHAT: Get or Create Chat Room ---
  Future<String> getOrCreateChatRoom(String spotId, String ownerId) async {

    // 1. Check if chat already exists
    final QuerySnapshot existing = await _db.collection('chats')
        .where('spotId', isEqualTo: spotId)
        .where('participants', arrayContains: _uid)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    // 2. Create new chat
    final docRef = await _db.collection('chats').add({
      'spotId': spotId,
      'participants': [_uid, ownerId],
      'lastMessage': 'Chat started',
      'lastUpdated': FieldValue.serverTimestamp(),
      'scheduledTime': null, // Crucial for the pickup logic
    });

    return docRef.id;
  }

  // --- 5. CHAT: Send Message ---
  Future<void> sendMessage(String chatId, String text, {bool isSystem = false}) async {
    await _db.collection('chats').doc(chatId).collection('messages').add({
      'text': text,
      'senderId': isSystem ? 'system' : _uid, // Replace with Auth ID
      'createdAt': FieldValue.serverTimestamp(),
      'isSystem': isSystem,
    });

    // Update parent to show latest snippet
    await _db.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // --- 6. CHAT: Schedule Pickup ---
  Future<void> schedulePickup(String chatId, DateTime date) async {
    // 1. Update the official schedule time in the doc
    await _db.collection('chats').doc(chatId).update({
      'scheduledTime': Timestamp.fromDate(date),
    });

    // 2. Add a visible system message
    final formattedDate = DateFormat('EEEE, MMM d @ h:mm a').format(date);
    await sendMessage(chatId, "📅 Pickup confirmed for $formattedDate", isSystem: true);
  }
  
  // --- 7. CHAT: Message Stream ---
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _db.collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
  // --- 8. CHAT: Send Photo Message ---
  Future<void> sendPhotoMessage(String chatId, File imageFile, String caption) async {
    try {
      // A. Upload Image
      String fileName = 'chat_photos/${_uuid.v4()}.jpg';
      Reference ref = _storage.ref().child(fileName);
      await ref.putFile(imageFile);
      String downloadUrl = await ref.getDownloadURL();

      // B. Add Message to Chat
      await _db.collection('chats').doc(chatId).collection('messages').add({
        'text': caption, // The AI generated note
        'imageUrl': downloadUrl,
        'senderId': _uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isSystem': false,
        'type': 'postcard', // Special type for rendering
      });

      // C. Update Chat Preview
      await _db.collection('chats').doc(chatId).update({
        'lastMessage': '📷 Sent a postcard',
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      print("Error sending postcard: $e");
      throw Exception("Could not send postcard");
    }
  }
}