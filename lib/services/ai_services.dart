import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  // ⚠️ SECURITY NOTE: In a production app, do not hardcode your API Key.
  // Use a .env file or Firebase Remote Config.
  // For this prototype, replace 'YOUR_API_KEY' with your actual key from Google AI Studio.
  static const String _apiKey = 'AIzaSyAs2tcfyA5rPA62ZGXbvNQBGHYAOj0zHjc';
  
  late final GenerativeModel _flashModel;

  AIService() {
    _flashModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
    );
  }

  /// FEATURE 1: Identify Plant
  /// Takes image bytes, sends them to Gemini, and returns structured data
  /// to auto-fill the "Add Harvest" form.
  Future<Map<String, dynamic>> identifyPlant(Uint8List imageBytes) async {
    // We strictly instruct the model to return ONLY JSON.
    final prompt = TextPart(
      "Analyze this image. Identify the plant. "
      "Return a raw JSON object (no markdown formatting) with these fields: "
      "1. 'name': Common name of the plant. "
      "2. 'category': Choose one of ['Fruit', 'Herb', 'Flower', 'Vegetable', 'Other']. "
      "3. 'months': An array of strings representing typical harvest months in California (e.g. ['June', 'July']). "
      "4. 'confidence': A number between 0 and 1 indicating how sure you are."
    );

    final imagePart = DataPart('image/jpeg', imageBytes);

    return await generateAIResponse(prompt, imagePart);
  }

  /// FEATURE 2: Generate Thank You Note
  /// Creates a custom, warm message based on the picker's name and what they took.
  Future<String> generateThankYouNote({
    required String pickerName, 
    required String plantName,
    Uint8List? photoBytes // Optional: If they took a photo of their haul
  }) async {
    final textPrompt = "Write a very short (max 2 sentences), warm, community-focused thank you note "
        "from a neighbor named $pickerName who just picked some $plantName. "
        "Do not use hashtags. Sound grateful and neighborly.";

    final parts = <Part>[TextPart(textPrompt)];

    if (photoBytes != null) {
      parts.add(DataPart('image/jpeg', photoBytes));
      parts.add(TextPart("Base the tone on the vibe of this photo I just took of the harvest."));
    }

    try {
      final response = await _flashModel.generateContent([Content.multi(parts)]);
      return response.text ?? "Thank you for sharing your garden!";
    } catch (e) {
      return "Thanks so much for the delicious $plantName!";
    }
  }

  // --- Utility ---
  
  String _sanitizeJson(String input) {
    // Removes markdown code blocks if present
    String cleaned = input.replaceAll('```json', '').replaceAll('```', '');
    return cleaned.trim();
  }

  Future<Map<String, dynamic>> plantTips(Uint8List imageBytes) async {
      // We strictly instruct the model to return ONLY JSON.
      final prompt = TextPart(
        "Analyze this image. Identify the plant. "
        "Return a raw JSON object (no markdown formatting) with these fields: "
        "1. 'name': Common name of the plant. "
        "2. 'benefits': An array of strings representing beneficts of given plant. "
        "3. 'growing tips': An array of strings displaying ways to improve current plant. "
        "4. 'confidence': A number between 0 and 1 indicating how sure you are."
      ); 
       final imagePart = DataPart('image/jpeg', imageBytes);

    return await generateAIResponse(prompt, imagePart);
  }

  Future<dynamic> generateAIResponse(TextPart prompt, DataPart imagePart) async {
    try {
      final response = await _flashModel.generateContent([
        Content.multi([prompt, imagePart])
      ]);
    
      final text = response.text;
      
      if (text == null) {
        throw Exception("AI returned no text.");
      }
    
      // Helper to clean up if Gemini wraps response in ```json ... ```
      final cleanJson = _sanitizeJson(text);
      return jsonDecode(cleanJson);
    
    } catch (e) {
      print("AI Identification Error: $e");
      // Fallback data so the app doesn't crash
      return {
        'name': 'Unknown Plant',
        'category': 'Other',
        'months': [],
        'confidence': 0.0
      };
    }
  }

}