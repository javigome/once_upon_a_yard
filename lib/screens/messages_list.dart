import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/auth_services.dart';
import 'chat_screen.dart';

class MessagesListScreen extends StatelessWidget {
  const MessagesListScreen({super.key});
  String formatTimestamp(dynamic timestamp) {
  if (timestamp == null) return '';
  
  DateTime date;
  if (timestamp is Timestamp) {
    date = timestamp.toDate();
  } else {
    return '';
  }

  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return DateFormat('EEEE').format(date); // e.g., "Tuesday"
  
  return DateFormat('MMM d').format(date); // e.g., "Jan 22"
}

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUserId;    
    return Scaffold(
      appBar: AppBar(title: const Text("My Messages")),
      body: StreamBuilder<QuerySnapshot>(
        // Query: Find chats where 'participants' array contains my ID
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: user)
            .orderBy('lastUpdated', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
        // 1. Handle Errors (Crucial for debugging)
              if (snapshot.hasError) {
                print("Error in Profile Stream: ${snapshot.error}"); // Check your Debug Console
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Could not load garden.\n${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }
          if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No messages yet. Go plant something!"));
          }
          
          final docs = snapshot.data!.docs;
         
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final List<dynamic> participants = data['participants'] ?? [];
              // Find the 'other' ID
              final String otherUserId = participants.firstWhere(
                (id) => id != user, 
                orElse: () => '',
              );
              final List<dynamic> readBy = data['readBy'] ?? [];
              final bool isUnread = !readBy.contains(user); // 'user' is the current UID
              // GET THE NAME DIRECTLY FROM THE CHAT DOCUMENT
              final Map<String, dynamic> names = data['participantNames'] ?? {};
              final String otherUserName = names[otherUserId] ?? "Gardener";
              return ListTile(
                leading: Stack(
                  children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF228B22),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      if(isUnread)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                  ],
                ),
                title: 
                 Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child:  Text(
                      otherUserName,
                      style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                      color: isUnread ? Colors.black : Colors.grey[800],),
                    )),
                    // --- THE TIMESTAMP ---
                    Text(
                      formatTimestamp(data['lastUpdated']),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                 ),
               
                subtitle: Text(
                  data['lastMessage'] ?? 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                    color: isUnread ? Colors.black87 : Colors.grey,
                  ),
                ),
                onTap: () {
                  if (isUnread) {
                    FirebaseFirestore.instance.collection('chats').doc(docs[index].id).update({
                      'readBy': FieldValue.arrayUnion([user]),
                    });
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        chatId: docs[index].id,
                        plantName: data['plantName'] ?? 'Chat',
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}