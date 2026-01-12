import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart'; // Import Geolocator
import 'package:once_upon_a_yard/data/plants.dart';
import 'package:once_upon_a_yard/models/harvest_spot.dart';
import '../services/firestore_service.dart';
import 'add_harvest.dart';
import 'pin_detail.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Google Maps Controller
  final Completer<GoogleMapController> _controller = Completer();
  
  // State variables
  String? _mapStyle;
  Set<Marker> _markers = {};
  // BitmapDescriptor? _customIcon;

  // Services
  final FirestoreService _firestoreService = FirestoreService();

  // Fallback: San Francisco (used if permission denied)
  static const CameraPosition 
  _kDefaultLocation = CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {_showWelcomeMessage(context);});
    _loadEmojiMarkers();
    _loadMapStyle();
    _listenToHarvests();
    
    _getUserLocation();
   
  }
// Cache to store the generated Bitmaps
  final Map<String, BitmapDescriptor> _emojiIcons = {};

  Future<void> _showWelcomeMessage(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Welcome to the Community!'),
          content: const Text(
            'Before you start sharing and harvesting, please agree to our community safety guidelines.\n'
            '\nFor Harvesters: By participating, you agree to enter properties at your own risk. Only pick what is explicitly offered, and be aware of potential plant allergies. Always supervise children.\n'
            '\nFor Sharers: Please only list edible, non-toxic plants from our verified list. Ensure the pickup area is safe and accessible as described in your listing.\n'
            '\nFor Everyone: Be a good neighbor! Only visit during posted hours and be respectful of property. This is a community based on trust and goodwill.',
          ),
          actions: <Widget>[
            // TextButton(
            //   style: TextButton.styleFrom(textStyle: Theme.of(context).textTheme.labelLarge),
            //   child: const Text('Disable'),
            //   onPressed: () {
            //     Navigator.of(context).pop();
            //   },
            // ),
            TextButton(
              style: TextButton.styleFrom(textStyle: Theme.of(context).textTheme.labelLarge),
              child: const Text('I Agree & Continue'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadEmojiMarkers() async {
    try {
      // Loop through our data map
      for (var entry in plantEmojis.entries) {
        final String name = entry.key;
        final String emoji = entry.value;
        
        // Generate the icon
        final BitmapDescriptor icon = await _createEmojiMarker(emoji);
        
        // Save to cache
        _emojiIcons[name] = icon;
      }
      // Don't forget the fallback!
      _emojiIcons['Other'] = await _createEmojiMarker('🌱');

      if (!mounted) return; // Stop if the screen is closed

      setState(() {}); // Refresh map once loaded
    } catch (e) {
      print("Error generating emoji markers: $e");
    }
  }
  // 1. Get User Location & Move Camera
  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // A. Check if GPS is on
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are disabled.
      return;
    }

    // B. Check Permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return; // Permission denied, stay at default location
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return; // Permissions are permanently denied
    } 

    // C. Get Position
    Position position = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    // D. Move Map Camera
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 16.0, // Zoom in closer for "Neighborhood" feel
      ),
    ));
  }

  // 2. Load the "Lush Green" JSON style
  Future<void> _loadMapStyle() async {
    try {
      _mapStyle = await rootBundle.loadString('assets/styles/map_style.json');
      // Apply style if controller is already ready
      if (_controller.isCompleted) {
        final controller = await _controller.future;
        controller.setMapStyle(_mapStyle);
      }
    } catch (e) {
      print("Could not load map style: $e");
    }
  }

  // 4. Real-time Database Listener
  void _listenToHarvests() {
    _firestoreService.getHarvestSpots().listen((spotsData) {
      setState(() {
        _markers = spotsData.map((spot) {
         // 1. Get location
          final GeoPoint point = spot.location; 
          
          // 2. Get Plant Name (e.g., "Lemons")
          final String plantName = spot.plantName ?? 'Other';

          // 3. Find the matching Emoji Icon
          // First try exact name match, then fallback to 'Other'
          final BitmapDescriptor iconToUse = _emojiIcons[plantName] ?? 
                                             _emojiIcons['Other'] ?? 
                                             BitmapDescriptor.defaultMarker;
          return Marker(
            markerId: MarkerId(spot.id),
            position: LatLng(point.latitude, point.longitude),
            icon: iconToUse,
            onTap: () => _showSpotPreview(context, spot),
          );
        }).toSet();
      });
    });
  }


  // 5. Spot Preview Popup
  void _showSpotPreview(BuildContext context, HarvestSpot spot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: 380,
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                child: Image.network(
                  spot.imageUrl ?? 'https://via.placeholder.com/400', 
                  height: 140, 
                  width: double.infinity, 
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(height: 140, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spot.plantName ?? "Unknown Plant",
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                        ),
                        Text(
                          "${spot.category} • Available",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                        "About Garden",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                      ),
                        Text(
                          "Describe garden",
                        // style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Time available for pick up:",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                      ),
                        Text(
                        "Available ${spot.category}",
                        // style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                      ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close sheet
                        Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (context) => PinDetailScreen(spotData: spot))
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(14),
                        backgroundColor: const Color(0xFF90EE90),
                      ),
                      child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF228B22)),
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<BitmapDescriptor> _createEmojiMarker(String emoji) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 120.0; // High res for crisp icons
    
    // 1. Draw a white circle background (Optional: makes emoji pop)
    final Paint paint = Paint()..color = Colors.white;
    final double radius = size / 2;
    canvas.drawCircle(Offset(radius, radius), radius, paint);
    
    // 2. Draw a Green Border (Optional)
    final Paint borderPaint = Paint()
      ..color = const Color(0xFF228B22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(Offset(radius, radius), radius - 2, borderPaint);

    // 3. Draw the Emoji
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    textPainter.text = TextSpan(
      text: emoji,
      style: const TextStyle(
        fontSize: 70.0, // Adjust relative to canvas size
        fontFamily: 'Roboto', // Ensures emoji rendering on Android
      ),
    );
    
    textPainter.layout();
    
    // Center the emoji on the canvas
    final double x = (size - textPainter.width) / 2;
    final double y = (size - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(x, y));

    // 4. Convert to Image -> Bytes -> BitmapDescriptor
    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // THE MAP
          GoogleMap(
            initialCameraPosition: _kDefaultLocation,
            markers: _markers,
            myLocationEnabled: true, // Shows the blue dot
            myLocationButtonEnabled: false, // We use our own logic/UI
            zoomControlsEnabled: false,
            compassEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              if (_mapStyle != null) {
                controller.setMapStyle(_mapStyle);
              }
            },
          ),

          // TOP OVERLAY (Search/Filter)
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey),
                  const SizedBox(width: 10),
                  Text("Search lemons, mint, flowers...", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          ),

          // RE-CENTER BUTTON (Optional but helpful)
          Positioned(
            bottom: 110,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: "recenter_btn",
              backgroundColor: Colors.white,
              foregroundColor: Colors.grey[700],
              onPressed: _getUserLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          // BOTTOM FAB (Add Harvest)
          Positioned(
            bottom: 40,
            right: 20,
            child: FloatingActionButton.extended(
              heroTag: "add_harvest_btn",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddHarvestScreen()),
                );
              },
              backgroundColor: const Color(0xFF228B22),
              icon: const Icon(Icons.add_location_alt_outlined, color: Colors.white),
              label: const Text("Share Harvest", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}