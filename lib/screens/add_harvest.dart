import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:once_upon_a_yard/services/auth_services.dart';
import '../services/ai_services.dart';
import '../services/firestore_service.dart';
import 'package:geolocator/geolocator.dart'; // Ensure you have this for location

class AddHarvestScreen extends StatefulWidget {
  const AddHarvestScreen({super.key});

  @override
  State<AddHarvestScreen> createState() => _AddHarvestScreenState();
}

class _AddHarvestScreenState extends State<AddHarvestScreen> {
  int _currentStep = 0;
  bool _isAnalyzing = false;
  File? _selectedImage;
    final user = AuthService().currentUserId;
   // Services
  final ImagePicker _picker = ImagePicker();
  final AIService _aiService = AIService();
  final firestoreService = FirestoreService();

  // Form Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
      // Controllers for the New Garden form
  final TextEditingController _gardenNameController = TextEditingController();
  final TextEditingController _gardenDescriptionController = TextEditingController();

  // Form State
  String _selectedCategory = 'Fruit';
  String _privacyLevel = 'blurred'; // exact, blurred, chat_only
  final List<String> _categories = ['Fruit', 'Herb', 'Flower', 'Vegetable', 'Other'];
  bool _isNewGarden = false;
  String? _selectedGarden;
  // late List<String> _existingGardens;

  // --- LOGIC: AI PLANT ID ---
  Future<void> _pickAndIdentifyImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(source: source, maxWidth: 800);
      if (photo == null) return;

      setState(() {
        _selectedImage = File(photo.path);
        _isAnalyzing = true; // Start loading spinner
      });

      // Convert to bytes for Gemini
      final Uint8List imageBytes = await photo.readAsBytes();
      
      // Call the AI Brain
      final aiResult = await _aiService.identifyPlant(imageBytes);

      // Auto-fill the UI
      setState(() {
        _nameController.text = aiResult['name'] ?? "Unknown Plant";
        
        // Try to match the category returned by AI, otherwise default to Other
        String aiCat = aiResult['category'] ?? 'Other';
        if (_categories.contains(aiCat)) {
          _selectedCategory = aiCat;
        } else {
          _selectedCategory = 'Other';
        }
        
        _isAnalyzing = false; // Stop loading spinner
      });

      // Auto-advance to details step if successful
      if (aiResult['name'] != null) {
         setState(() => _currentStep = 2);
      }

    } catch (e) {
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not identify plant: $e")),
      );
    }
  }

    Widget _buildPhotoBtn(IconData icon, String label, ImageSource source) {
    return Column(
      children: [
        IconButton(
          onPressed: _isAnalyzing ? null : () => _pickAndIdentifyImage(source),
          icon: Icon(icon, size: 40, color: const Color(0xFF228B22)),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Future<void> _submitHarvest() async {
    if (_selectedImage == null || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add a photo and name!")),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF228B22))),
    );
    try {
      // 1. Get current location (in real app, use the map picker result)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      // 2. Call the Service
      await firestoreService.addHarvestSpot(
        imageFile: _selectedImage!,
        plantName: _nameController.text,
        category: _selectedCategory,
        description: _descController.text,
        lat: position.latitude,
        lng: position.longitude,
        garden: _selectedGarden?.split(',').first ?? _gardenNameController.text,
        gardenDescription: _selectedGarden?.split(',').last ?? _gardenDescriptionController.text,
        privacyLevel: _privacyLevel,
        // months: [],
        ownerId: user
      );

      // 3. Success!
      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context); // Close Add Screen
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Success! Your garden is on the map."),
          backgroundColor: Color(0xFF228B22),
        ),
      );

    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
Widget _buildExistingGardenDropdown(String userId) {
  return StreamBuilder<QuerySnapshot>(
    // Fetching the gardens collection
    stream: FirebaseFirestore.instance.collection('harvest_spots').where('isActive', isEqualTo: true)
        .where('ownerId', isEqualTo: userId).where('garden', isNotEqualTo: '').snapshots().distinct(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Text('Error: ${snapshot.error}');
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return CircularProgressIndicator();
      }

      // Convert Firestore documents into a list of DropdownMenuItems
      List<DropdownMenuItem<String>> gardenItems = snapshot.data!.docs.map((doc) {
        return DropdownMenuItem<String>(
          value: '${doc['garden']}, ${doc['gardenDescription']}', // Use document ID as the value
          child: Text(doc['garden']), // Display the 'name' field
        );
      }).toList();
      return DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Choose Garden', 
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.yard, color: const Color(0xFF228B22)),
        ),
        value: _selectedGarden,
        items: gardenItems,
        onChanged: (val) {
          setState(() {
            _selectedGarden = val;
          });
        },
        hint: Text("Select an existing garden"),
      );
    },
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("What would you like to share?")),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 2) {
            setState(() => _currentStep += 1);
          } else {
            // FINISH
            _submitHarvest();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          } else {
            Navigator.pop(context);
          }
        },
        controlsBuilder: (context, details) {
          // Customizing buttons to look "Green"
          return Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  child: Text(_currentStep == 2 ? "PLANT IT!" : "NEXT"),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text("BACK", style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          );
        },
        steps: [
          // STEP 1: LOCATION
          Step(
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.editing,
            title: const Text('Select or Create Garden'),
            content: Column(
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Existing'), icon: Icon(Icons.history)),
                    ButtonSegment(value: true, label: Text('New Garden'), icon: Icon(Icons.add_location_alt)),
                  ],
                  selected: {_isNewGarden},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() => _isNewGarden = newSelection.first);
                  },
                ),
                const SizedBox(height: 20),
                if (!_isNewGarden)
                 _buildExistingGardenDropdown(user)
                else
                  Column(
                    children: [
                      TextFormField(
                        controller: _gardenNameController,
                        decoration: const InputDecoration(labelText: 'Garden Name', border: OutlineInputBorder()),
                      ),
                      SizedBox(height: 12),
                      // OutlinedButton.icon(
                      //   onPressed: () {}, // Location logic
                      //   icon: Icon(Icons.my_location),
                      //   label: Text("Get Current Location"),
                      //   style: OutlinedButton.styleFrom(minimumSize: Size(double.infinity, 45)),
                      // ),
                      SizedBox(height: 12),
                      TextFormField(
                        controller: _gardenDescriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          hintText: 'e.g. Soil type, sun exposure...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // STEP 2: PHOTO & AI
          Step(
            title: const Text("What are you sharing?"),
            subtitle: const Text("Snap a photo to auto-fill details"),
            content: Column(
              children: [
                if (_selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Image.file(_selectedImage!, height: 150, fit: BoxFit.cover),
                  ),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPhotoBtn(Icons.camera_alt, "Camera", ImageSource.camera),
                    _buildPhotoBtn(Icons.photo_library, "Gallery", ImageSource.gallery),
                  ],
                ),
                
                if (_isAnalyzing)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         CircularProgressIndicator(color: Color(0xFF228B22)),
                         SizedBox(width: 15),
                         Text("Consulting nature spirits...")
                      ],
                    ),
                  ),
              ],
            ),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.editing,
          ),

          // STEP 3: DETAILS
          Step(
            title: const Text("Confirm Details"),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Plant Name"),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(labelText: "Category"),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: "Notes (e.g. 'Bring a ladder!')"),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                const Text("Privacy", style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  initialValue: _privacyLevel,
                  items: const [
                    DropdownMenuItem(value: 'exact', child: Text("Exact Address (Best for public)")),
                    DropdownMenuItem(value: 'blurred', child: Text("Blurred (Show approx area)")),
                    DropdownMenuItem(value: 'chat_only', child: Text("Hide (Reveal only in chat)")),
                  ],
                  onChanged: (v) => setState(() => _privacyLevel = v!),
                ),
              ],
            ),
            isActive: _currentStep >= 2,
          ),
        ],
      ),
    );
  }
}