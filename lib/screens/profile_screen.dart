import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:once_upon_a_yard/data/plants.dart';
import 'package:once_upon_a_yard/models/harvest_spot.dart';
import 'package:once_upon_a_yard/screens/add_harvest.dart';
import '../services/auth_services.dart';
import 'pin_detail.dart'; // To preview their own pins

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showEditGardenSheet(BuildContext context, String id, String currentName, String currentDesc) {
    final nameCtrl = TextEditingController(text: currentName);
    final descCtrl = TextEditingController(text: currentDesc);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Edit Garden Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Garden Name", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                FirebaseFirestore.instance.collection('gardens').doc(id).update({
                  'name': nameCtrl.text,
                  'description': descCtrl.text,
                });
                Navigator.pop(context);
              },
              child: const Text("Save Changes"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
   
  void _showEditHarvestSheet(BuildContext context, String id, HarvestSpot data) {
  final nameCtrl = TextEditingController(text: data.plantName);
  // Assuming HarvestSpot model has a description or you're using category
  final categoryCtrl = TextEditingController(text: data.category);

  showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Edit Harvest", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Plant Name")),
            const SizedBox(height: 10),
            TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: "Category")),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                FirebaseFirestore.instance.collection('harvest_spots').doc(id).update({
                  'plantName': nameCtrl.text,
                  'category': categoryCtrl.text,
                });
                Navigator.pop(context);
              },
              child: const Text("Update Harvest"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  } 
  
  void _confirmDeleteGarden(BuildContext context, String gardenId, String gardenName) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text("Delete $gardenName?"),
      content: const Text("This will also remove all harvests associated with this garden. This action cannot be undone."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            _deleteGardenAndHarvests(gardenId);
          },
          child: const Text("DELETE", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

  Future<void> _deleteGardenAndHarvests(String gardenId) async {
  final batch = FirebaseFirestore.instance.batch();
  
  // 1. Reference the Garden
  DocumentReference gardenRef = FirebaseFirestore.instance.collection('gardens').doc(gardenId);
  batch.delete(gardenRef);

  // 2. Find all Harvests linked to this Garden
  QuerySnapshot harvests = await FirebaseFirestore.instance
      .collection('harvest_spots')
      .where('gardenId', isEqualTo: gardenId)
      .get();

  // 3. Add them to the batch
  for (var doc in harvests.docs) {
    batch.delete(doc.reference);
  }

  // 4. Commit everything at once
  await batch.commit();
}
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
        trailing:
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(text: TextSpan( text: plantEmojis[data.plantName] ?? plantEmojis['Herbs (Mixed)'],  style: const TextStyle(fontSize: 20)) ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditHarvestSheet(context, spotId, data);
                }
                else if (value == 'toggle') {
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
                const PopupMenuItem(value: 'edit', child: ListTile(
                    leading: Icon(Icons.edit_note, color: Colors.grey),
                    title: Text('Edit Details'),
                    contentPadding: EdgeInsets.zero,
                  ),),
                PopupMenuItem<String>(
                  value: 'toggle',
                  child: ListTile(
                    leading: const Icon(Icons.check, color: Colors.green),
                    title: Text(isActive ? 'Mark Inactive' : 'Mark Active'),
                    contentPadding: EdgeInsets.zero,
                  ),),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child:  ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete Spot', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),),
              ],
            )
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

  Widget _buidMenuAnchor(BuildContext context) {
    final FocusNode _buttonFocusNode = FocusNode(debugLabel: 'Menu Button');
    final auth = AuthService();

    return MenuAnchor(
      childFocusNode: _buttonFocusNode,
      menuChildren: [
      MenuItemButton(onPressed: (){}, child: const Text('Mission')),
      MenuItemButton(onPressed: (){}, child: const Text('About Us')),
      MenuItemButton(onPressed: () async {
              await auth.signOut();}, child: const Text('Log Out')),
    ],
     builder: (_, MenuController controller, Widget? child) {
        return IconButton(
          focusNode: _buttonFocusNode,
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: const Icon(Icons.more_vert),
        );
     }
    );
  }
  
  Widget _buildGardenSection(BuildContext context, String gardenId, dynamic gardenData) {
    String name = gardenData['name'];
    String description =  gardenData['description'];
   return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Aligns items to the top
          children: [
            // GARDEN INFO (Left Side)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  if (description != null)
                    Text(
                      description,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                ],
              ),
            ),

            // GARDEN ACTIONS (Right Side)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) {
                if (value == 'add_harvest') {
                  // Navigate to AddHarvestScreen and pass the gardenId
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddHarvestScreen(preSelectedGardenId: gardenId),
                    ),
                  );
                } else if (value == 'edit') {
                  _showEditGardenSheet(context, gardenId, name, description);
                } else if (value == 'delete') {
                  _confirmDeleteGarden(context, gardenId, name);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'add_harvest',
                  child: ListTile(
                    leading: Icon(Icons.add_circle_outline, color: Colors.green),
                    title: Text('Add Harvest Here'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_note),
                    title: Text('Edit Garden'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Delete Garden', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
      // Nested Stream for Harvests within this Garden
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('harvest_spots')
            .where('gardenId', isEqualTo: gardenId) // Filter by this garden
            .snapshots(),
        builder: (context, harvestSnapshot) {
          if (!harvestSnapshot.hasData || harvestSnapshot.data!.docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: Text("No harvests logged in this garden yet.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            );
          }

          final harvestDocs = harvestSnapshot.data!.docs;

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: harvestDocs.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final spotId = harvestDocs[index].id;
              final data = HarvestSpot.fromFirestore(harvestDocs[index]);
              return _buildHarvestCard(context, data, spotId);
            },
          );
        },
      ),
      const Divider(height: 40, thickness: 1, indent: 20, endIndent: 20),
    ],
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
        actions: [_buidMenuAnchor(context)],
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
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFE8F5E9), // Light Green
                    child: Image.asset(
                      './assets/profile_icon/lemon.png',
                      // height: 100,
                      // width: 50,
                      color: null, // Ensure no color filter is applied
                      fit: BoxFit.scaleDown,
                    ),
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
                      const SizedBox(width: 10),
                      _buildStatChip(Icons.star, "Rating: 4.9"),
                    ],
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            const SizedBox(height: 10),

            // 3. THE LIST OF GARDENS (with nested harvests)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('gardens')
                  .where('ownerId', isEqualTo: uid) // Get user's gardens
                  .snapshots(),
              builder: (context, gardenSnapshot) {
                if (gardenSnapshot.hasError) return Text("Error: ${gardenSnapshot.error}");
                if (gardenSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!gardenSnapshot.hasData || gardenSnapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(); // No gardens created yet
                }

                final gardenDocs = gardenSnapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: gardenDocs.length,
                  itemBuilder: (context, index) {
                    final gardenData = gardenDocs[index].data() as Map<String, dynamic>;
                    final gardenId = gardenDocs[index].id;
                    
                    return _buildGardenSection(
                      context, 
                      gardenId, 
                      gardenData
                    );
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