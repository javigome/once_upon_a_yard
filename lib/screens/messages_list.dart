import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_services.dart';
import 'chat_screen.dart';

class MessagesListScreen extends StatelessWidget {
  const MessagesListScreen({super.key});

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
              // A trick to find the "other" person's name would require a separate User query
              // For now, we just list the last message.
              
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF228B22),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text("Chat #${docs[index].id.substring(0, 4)}"),
                subtitle: Text(
                  data['lastMessage'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to the Chat Screen we built earlier
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        chatId: docs[index].id,
                        plantName: "Harvest Chat", // Ideally fetch this from data['plantName']
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