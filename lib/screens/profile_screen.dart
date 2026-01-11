import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:once_upon_a_yard/models/harvest_spot.dart';
import '../services/auth_services.dart';
import 'pin_detail.dart'; // To preview their own pins

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

    // --- HELPER WIDGETS ---

  Widget _buildHarvestCard(BuildContext context, HarvestSpot data, String spotId) {
    bool isActive = data.isActive ?? true;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        // Image Thumbnail
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            data.imageUrl ?? 'https://via.placeholder.com/100',
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (c,e,s) => Container(width: 60, height: 60, color: Colors.grey[300]),
          ),
        ),
        // Plant Info
        title: Text(
          data.plantName ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.category ?? 'Other'),
            const SizedBox(height: 4),
            // Status Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isActive ? Colors.green : Colors.red, width: 0.5),
              ),
              child: Text(
                isActive ? "Active" : "Inactive",
                style: TextStyle(
                  fontSize: 10, 
                  color: isActive ? Colors.green[800] : Colors.red[800],
                  fontWeight: FontWeight.bold
                ),
              ),
            )
          ],
        ),
        // Actions
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'toggle') {
              // Toggle Active Status
              FirebaseFirestore.instance.collection('harvest_spots').doc(spotId).update({
                'isActive': !isActive
              });
            } else if (value == 'delete') {
               // Confirm Delete
               FirebaseFirestore.instance.collection('harvest_spots').doc(spotId).delete();
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'toggle',
              child: Text(isActive ? 'Mark Inactive' : 'Mark Active'),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Text('Delete Spot', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: () {
          // Preview how others see it
          // Note: Add 'id' to data manually so PinDetail works
          // var fullData = HarvestSpot.fromFirestore(data as DocumentSnapshot<Object?>);
          // fullData.id = spotId;
          
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PinDetailScreen(spotData: data)),
          );
        },
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: const Color(0xFF228B22).withOpacity(0.8),
      padding: const EdgeInsets.all(0),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 30),
          Icon(Icons.grass, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(
            "Your garden is empty.",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 5),
          const Text(
            "Share your first harvest on the map!",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final String uid = auth.currentUserId;

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for contrast
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await auth.signOut();
            },
            tooltip: "Log Out",
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. HEADER SECTION
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(0xFFE8F5E9), // Light Green
                    child: Icon(Icons.person, size: 50, color: Color(0xFF228B22)),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    auth.currentUserName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Community Gardener",
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  // Optional: Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatChip(Icons.eco, "Karma: 120"),
                      const SizedBox(width: 10),
                      _buildStatChip(Icons.star, "Rating: 4.9"),
                    ],
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            // 2. MY HARVESTS SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "My Garden",
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.grey[800]
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 10),

            // 3. THE LIST OF SPOTS
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('harvest_spots')
                  .where('ownerId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
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
                  return _buildEmptyState();
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true, // Vital when inside SingleChildScrollView
                  physics: const NeverScrollableScrollPhysics(), // Let outer view scroll
                  itemCount: docs.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final String spotId = docs[index].id;
                    final HarvestSpot data = HarvestSpot.fromFirestore(docs[index]);
                   
                    return _buildHarvestCard(context, data, spotId);
                  },
                );
              },
            ),
            
            const SizedBox(height: 50), // Bottom padding
          ],
        ),
      ),
    );
  }


}