import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../theme/theme.dart';
import 'postcard_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String plantName;

  const ChatScreen({
    super.key, 
    required this.chatId, 
    required this.plantName
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final FirestoreService _fs = FirestoreService();

  // Pick Date & Time Logic
  void _pickScheduleTime() async {
    // 1. Pick Date
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF228B22)),
          ),
          child: child!,
        );
      },
    );

    if (date == null) return;

    // 2. Pick Time
    if (!mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF228B22)),
          ),
          child: child!,
        );
      },
    );

    if (time == null) return;

    // 3. Combine & Save
    final DateTime scheduledDateTime = DateTime(
      date.year, date.month, date.day, time.hour, time.minute
    );

    _fs.schedulePickup(widget.chatId, scheduledDateTime);
  }

  void _handleSend() {
    if (_msgController.text.trim().isEmpty) return;
    _fs.sendMessage(widget.chatId, _msgController.text.trim());
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.plantName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Text("Arranging pickup", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Color(0xFF228B22)),
            onPressed: _pickScheduleTime,
            tooltip: "Schedule Pickup",
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.grey),
            tooltip: "Send Thank You Postcard",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PostcardScreen(
                  chatId: widget.chatId,
                  otherUserName: "Neighbor", // In real app, pass actual name
                  plantName: widget.plantName,
                )),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          // MESSAGE LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _fs.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                
                return ListView.builder(
                  reverse: true, // Start from bottom
                  itemCount: docs.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final bool isMe = data['senderId'] == "test_picker_id"; // Replace with Auth check
                    final bool isSystem = data['isSystem'] ?? false;

                    if (isSystem) {
                      return _buildSystemBubble(data['text']);
                    }
                    return _buildMessageBubble(data['text'], isMe);
                  },
                );
              },
            ),
          ),

          // INPUT AREA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)],
            ),
            child: Row(
              children: [
                // Quick Schedule Button
                IconButton(
                  icon: const Icon(Icons.event_available, color: Colors.orange),
                  onPressed: _pickScheduleTime,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: "Enter Text here",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF228B22),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _handleSend,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI WIDGETS ---

  Widget _buildMessageBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFdcf8c6) : Colors.white, // WhatsApp green style
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))
          ],
        ),
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildSystemBubble(String text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 16, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}