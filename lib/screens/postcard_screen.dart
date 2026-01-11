import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_services.dart';
import '../services/firestore_service.dart';

class PostcardScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName; // e.g. "Alice"
  final String plantName;     // e.g. "Lemons"

  const PostcardScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    required this.plantName,
  });

  @override
  State<PostcardScreen> createState() => _PostcardScreenState();
}

class _PostcardScreenState extends State<PostcardScreen> {
  File? _image;
  String _aiMessage = "";
  bool _isLoading = false;
  final TextEditingController _textController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final AIService _aiService = AIService();
  final FirestoreService _fs = FirestoreService();

  @override
  void initState() {
    super.initState();
    // Auto-open camera when screen loads? 
    // Or let user click. Let's let user click for better UX control.
  }

  // 1. Capture Photo & Generate Text
  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() {
      _image = File(photo.path);
      _isLoading = true;
    });

    // 2. Call AI
    try {
      final imageBytes = await photo.readAsBytes();
      final generatedText = await _aiService.generateThankYouNote(
        pickerName: "Me", // Replace with current user name
        plantName: widget.plantName,
        photoBytes: imageBytes,
      );

      setState(() {
        _aiMessage = generatedText;
        _textController.text = generatedText; // Allow user to edit
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Error: $e")));
    }
  }

  // 3. Send Logic
  Future<void> _sendPostcard() async {
    if (_image == null) return;

    setState(() => _isLoading = true);

    try {
      await _fs.sendPhotoMessage(
        widget.chatId, 
        _image!, 
        _textController.text
      );
      
      if (mounted) {
        Navigator.pop(context); // Go back to Chat
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Postcard Sent! +10 Karma")),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // LAYER 1: The Image
          _image != null
              ? Image.file(_image!, fit: BoxFit.cover)
              : Container(color: Colors.grey[900], child: const Icon(Icons.camera_alt, color: Colors.white54, size: 50)),

          // LAYER 2: Dark Gradient Overlay (for text readability)
          if (_image != null)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

          // LAYER 3: The Content
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Loading State
                if (_isLoading)
                   const Padding(
                     padding: EdgeInsets.all(20.0),
                     child: CircularProgressIndicator(color: Colors.white),
                   ),

                // AI Text Bubble (Editable)
                if (_image != null && !_isLoading)
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [const BoxShadow(blurRadius: 10, color: Colors.black26)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
                              SizedBox(width: 5),
                              Text("Drafted by Gemini", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          TextField(
                            controller: _textController,
                            style: const TextStyle(fontSize: 16, fontFamily: 'Nunito', color: Colors.black87),
                            maxLines: 3,
                            decoration: const InputDecoration.collapsed(hintText: "Writing..."),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Buttons
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (_image == null)
                        FloatingActionButton.extended(
                          onPressed: _takePhoto,
                          label: const Text("Snap Harvest"),
                          icon: const Icon(Icons.camera),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                      
                      if (_image != null && !_isLoading) ...[
                        TextButton(
                          onPressed: _takePhoto, // Retake
                          child: const Text("Retake", style: TextStyle(color: Colors.white)),
                        ),
                        FloatingActionButton.extended(
                          onPressed: _sendPostcard,
                          label: const Text("Send Thanks"),
                          icon: const Icon(Icons.send),
                          backgroundColor: const Color(0xFF228B22),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}