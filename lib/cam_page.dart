import 'dart:convert';
import 'dart:ui';
import 'package:demo/map_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/speed_service.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class Mycam extends StatefulWidget {
  const Mycam({super.key});

  @override
  State<Mycam> createState() => _MycamState();
}

final TextEditingController nameController = TextEditingController();
final TextEditingController ageController = TextEditingController();
final TextEditingController cityController = TextEditingController();

class _MycamState extends State<Mycam> {
  Timer? _frameTimer;
  CameraController? _cameraController;
  late List<CameraDescription> _cameras;
  bool _isDetecting = false;
  bool _isProcessing = false; // Track if frame is being processed
  // ignore: unused_field
  bool _isCameraReady = false;
  double trafficLevel = 0.0;
  String trafficStatus = "Unknown";
  DateTime? lastUpdateTime; // Track when we last got data
  final String baseUrl = "https://aetheris-backend-h4xm.onrender.com";

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    _cameraController = CameraController(
      _cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    await _cameraController!.setFlashMode(FlashMode.off);

    if (mounted) {
      setState(() => _isCameraReady = true);
    }
  }

  Future<void> startDetection() async {
    if (_isDetecting) return;

    _frameTimer?.cancel();
    setState(() => _isDetecting = true);

    try {
      await http.post(Uri.parse("$baseUrl/start-detection"));
    } catch (e) {
      debugPrint("❌ Start detection error: $e");
    }

    // Send frame every 3 seconds (reduced from 5 for better responsiveness)
    _frameTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _captureAndSendFrame();
    });

    // Send first frame immediately
    _captureAndSendFrame();
  }

  Future<void> stopDetection() async {
    if (!_isDetecting) return;

    setState(() => _isDetecting = false);

    _frameTimer?.cancel();
    _frameTimer = null;

    try {
      await http.post(Uri.parse("$baseUrl/stop-detection"));
    } catch (e) {
      debugPrint("❌ Stop detection error: $e");
    }
  }

  Future<void> _captureAndSendFrame() async {
    if (!_isDetecting || _isProcessing || !mounted) return;

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isTakingPicture) return;

    setState(() => _isProcessing = true);

    try {
      final XFile file = await controller.takePicture();
      final Uint8List bytes = await file.readAsBytes();
      await sendFrameAndGetStatus(bytes);
    } catch (e) {
      debugPrint("❌ Capture error: $e");
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> sendFrameAndGetStatus(Uint8List imageBytes) async {
    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/frame"),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          imageBytes,
          filename: "frame.jpg",
          contentType: MediaType("image", "jpeg"),
        ),
      );

      // IMPORTANT: Wait for response and parse it
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 15), // Add timeout
        onTimeout: () {
          throw TimeoutException('Frame processing took too long');
        },
      );

      if (streamedResponse.statusCode == 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        final data = jsonDecode(responseBody);

        if (mounted) {
          setState(() {
            trafficLevel = (data["traffic_level"] ?? 0).toDouble();
            trafficStatus = data["traffic_status"] ?? "Unknown";
            lastUpdateTime = DateTime.now();
          });
        }
        debugPrint("✅ Frame processed: $trafficStatus ($trafficLevel)");
      } else {
        debugPrint("❌ Server error: ${streamedResponse.statusCode}");
      }
    } on TimeoutException catch (e) {
      debugPrint("⏱️ Timeout: $e");
      // Optionally show "Processing..." state to user
    } catch (e) {
      debugPrint("❌ Error sending frame: $e");
    }
  }

  @override
  void dispose() {
    _isDetecting = false;
    _frameTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(color: Color(0xFF0A0A0E)),
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.01),

            // Camera Preview
            Container(
              height: MediaQuery.of(context).size.height * 0.5,
              width: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                color: const Color.fromARGB(173, 160, 160, 160),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF4D4DFF), width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ModelViewer(
                  backgroundColor: Color(0xFF0A0A0E),
                  src: 'images/cybertruck.glb',
                  alt: 'My 3d model',
                  autoRotate: true,
                  autoRotateDelay: 0, // Start rotating immediately (no delay)
                  cameraControls: true,
                  disableZoom: true,
                  maxCameraOrbit:
                      "auto 90deg auto", // Lock vertical angle at 90deg
                  minCameraOrbit: "auto 90deg auto",
                  shadowIntensity: 0.7,
                  shadowSoftness: 0.8,
                ),
              ),
            ),

            SizedBox(height: 20),

            // Processing indicator
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4D4DFF),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Processing...",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),

            // Traffic Level Display
            Text(
              "Traffic Level: ${trafficLevel.toStringAsFixed(1)}",
              style: TextStyle(
                color: trafficLevel > 7 ? Colors.red : Colors.green,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              trafficStatus,
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),

            // Show last update time
            if (lastUpdateTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Updated ${_getTimeAgo(lastUpdateTime!)}",
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ),

            SizedBox(height: MediaQuery.of(context).size.width * 0.1),

            // Power Button
            GestureDetector(
              onTap: () {
                if (_isDetecting) {
                  stopDetection();
                } else {
                  startDetection();
                }
              },
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0A0A0E),
                  border: Border.all(color: Color(0xFF4D4DFF), width: 3),
                  boxShadow: _isDetecting
                      ? [
                          BoxShadow(
                            color: Color(0xFF4D4DFF).withOpacity(0.6),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: Color(0xFF4D4DFF).withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Icon(
                    Icons.power_settings_new,
                    size: 50,
                    color: _isDetecting ? Color(0xFF4D4DFF) : Colors.white54,
                  ),
                ),
              ),
            ),

            SizedBox(height: 12),

            // Status Text
            Text(
              _isDetecting ? "ACTIVE" : "INACTIVE",
              style: TextStyle(
                color: _isDetecting ? Color(0xFF4D4DFF) : Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 5) return "just now";
    if (diff.inSeconds < 60) return "${diff.inSeconds}s ago";
    return "${diff.inMinutes}m ago";
  }
}

class BottomBar extends StatefulWidget {
  const BottomBar({super.key});

  @override
  State<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> {
  int currentVal = 0;

  @override
  void initState() {
    super.initState();

    // 🔥 START SPEED TRACKING WHEN APP OPENS
    SpeedService().start();
  }

  final List<Widget> ScreenList = [
    const Mycam(),
    const MapPage(),
    const MyactivityPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 👈 IMPORTANT
      body: IndexedStack(index: currentVal, children: ScreenList),

      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BottomNavigationBar(
              currentIndex: currentVal,
              onTap: (index) {
                if (currentVal == 0 && index != 0) {
                  // Leaving camera tab
                  final cam = ScreenList[0];
                  if (cam is Mycam) {
                    // handled via dispose + timer cancel
                  }
                }
                setState(() => currentVal = index);
              },

              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: const Color(0xFF4D4DFF),
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: false,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.map_outlined),
                  activeIcon: Icon(Icons.map),
                  label: 'Map',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_outlined),
                  activeIcon: Icon(Icons.bar_chart),
                  label: 'My activity',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyactivityPage extends StatefulWidget {
  const MyactivityPage({super.key});

  @override
  State<MyactivityPage> createState() => _MyactivityPageState();
}

class _MyactivityPageState extends State<MyactivityPage> {
  final int numberOfContainers = 5;
  final List<String> myTexts = [
    "Privacy",
    "Notifications",
    "About and Support",
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        // backgroundColor: Colors.transparent,
        body: Container(
          width: double.infinity,
          height: double.infinity,

          decoration: BoxDecoration(color: Color(0xFF0A0A0E)),
          child: ListView.builder(
            itemCount: myTexts.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      myTexts[index],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4D4DFF),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _image; // store picked image
  final ImagePicker _picker = ImagePicker();
  User? user;
  String? uid;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    uid = user?.email; // safe null-check
    _loadImage();
  }

  // Load saved image path
  Future<void> _loadImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image');
    if (path != null) {
      setState(() {
        _image = File(path);
      });
    }
  }

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut(); // sign out from Firebase
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // clear login data

    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image', pickedFile.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Color(0xFF0A0A0E)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Container(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.start, // Arrange inner widgets
                children: <Widget>[
                  // First inner container
                  Container(
                    width: 400,
                    height: 300,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4D4DFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Top text
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 30.0,
                            left: 20,
                            right: 20,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 60,
                                  backgroundImage: _image != null
                                      ? FileImage(_image!)
                                      : null,
                                  child: _image == null
                                      ? const Icon(Icons.person, size: 60)
                                      : null,
                                ),
                                const SizedBox(height: 10),

                                // Button to pick photo
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text("Edit"),
                                ),
                                Container(),
                                SizedBox(height: 10),
                                Column(
                                  children: [
                                    Text(
                                      "Email: ${uid ?? 'Not logged in'}",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Second inner container
                  SizedBox(height: 20),
                  GlassContainer2(
                    vwidth: 400,
                    vheight: 100,
                    vchild: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Top text
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 10.0,
                            left: 20,
                            right: 20,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "Driving details",
                                  style: TextStyle(
                                    fontSize: 38,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 20),

                                Container(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () => logout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(0, 244, 67, 54),
                      foregroundColor: Colors.white,
                      shadowColor: WidgetStateColor.transparent,
                      minimumSize: Size(100, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(Icons.logout),
                    label: Text("Logout"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassContainer2 extends StatelessWidget {
  final Widget vchild;
  final double vwidth;
  final double vheight;

  const GlassContainer2({
    super.key,
    required this.vwidth,
    required this.vheight,
    required this.vchild,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaY: 10, sigmaX: 10),
        child: Container(
          width: vwidth,
          height: vheight,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              width: 1.5,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: Center(child: vchild),
        ),
      ),
    );
  }
}
