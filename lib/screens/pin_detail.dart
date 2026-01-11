import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // For types
import 'package:once_upon_a_yard/models/harvest_spot.dart';
import '../theme/theme.dart'; // Assuming you have your colors here
import '../services/firestore_service.dart';
import 'chat_screen.dart';

class PinDetailScreen extends StatelessWidget {
  final HarvestSpot spotData;

  const PinDetailScreen({super.key, required this.spotData});

  @override
  Widget build(BuildContext context) {
    // Extract data safely
    final String plantName = spotData.plantName ?? "Unknown Plant";
    final String imageUrl = spotData.imageUrl ?? 'https://via.placeholder.com/400';
    final String category = spotData.category ?? "Other";
    final String description = spotData.description ?? "No description provided.";
    final String privacy = spotData.privacyLevel ?? "blurred";
    
    // Mock harvest months (In real app, parse this from spotData['months'])
    final List<String> activeMonths = ['Jan', 'Feb', 'Dec']; 

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. THE PARALLAX HEADER
          SliverAppBar(
            expandedHeight: 300.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF228B22),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                plantName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                ),
              ),
              background: Hero(
                tag: spotData.id ?? 'hero', // Smooth transition from Map
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.1), // Slight dim for text readability
                  colorBlendMode: BlendMode.darken,
                ),
              ),
            ),
          ),

          // 2. THE BODY CONTENT
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. Category & Status Badge
                    Row(
                      children: [
                        _buildBadge(category, Colors.green.shade100, Colors.green.shade800),
                        const SizedBox(width: 10),
                        _buildBadge("Ripe Now", Colors.orange.shade100, Colors.orange.shade800),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // B. Owner's Note
                    const Text(
                      "Gardener's Note",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF228B22)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(fontSize: 16, height: 1.5, color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 25),

                    // C. Harvest Calendar
                    const Text(
                      "Seasonality",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF228B22)),
                    ),
                    const SizedBox(height: 10),
                    _buildSeasonalityChart(activeMonths),
                    
                    const SizedBox(height: 25),

                    // D. Location Privacy Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            privacy == 'exact' ? Icons.location_on : Icons.blur_on,
                            color: Colors.grey[600],
                            size: 30,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  privacy == 'exact' ? "Exact Location" : "Approximate Location",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  privacy == 'exact' 
                                      ? "123 Green St (Address visible)"
                                      : "Specific address revealed after you schedule a pickup.",
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 100), // Space for bottom button
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
      
      // 3. THE "ACTION" BUTTON
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ElevatedButton.icon(
         onPressed: () async {
            final fs = FirestoreService();
            
            // Show a quick loader
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connecting...")));
            
            // 1. Get/Create Room
            // Note: spotData['ownerId'] should exist. If null, we default to a test string.
            String roomId = await fs.getOrCreateChatRoom(
              spotData.id, 
              spotData.ownerId ?? 'unknown_owner'
            );

            if (context.mounted) {
              // 2. Navigate
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChatScreen(
                  chatId: roomId,
                  plantName: spotData.plantName,
                )),
              );
            }
          },
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text("Ask to Pick", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF228B22),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 5,
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildSeasonalityChart(List<String> activeMonths) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: months.map((m) {
          final isActive = activeMonths.contains(m);
          return Container(
            margin: const EdgeInsets.only(right: 8),
            width: 35,
            height: 35,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? const Color(0xFF228B22) : Colors.transparent,
              border: Border.all(color: isActive ? const Color(0xFF228B22) : Colors.grey.shade300),
            ),
            child: Text(
              m[0], // First letter
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}