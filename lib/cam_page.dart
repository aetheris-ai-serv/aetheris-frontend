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
  Timer? _backendTimer;
  CameraController? _cameraController;
  late List<CameraDescription> _cameras;
  bool _isCameraReady = false;
  bool _isDetecting = false;
  bool _isCapturing = false;

  double trafficLevel = 0.0;
  String trafficStatus = "Unknown";
  final String baseUrl = "https://aetheris-backend-a56i.onrender.com";

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

  Future<void> fetchTrafficStatus() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/status"));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            trafficLevel = (data["traffic_level"] ?? 0).toDouble();
            trafficStatus = data["traffic_status"] ?? "Unknown";
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Status fetch error: $e");
    }
  }

  Future<void> startDetection() async {
    if (_isDetecting) return;

    _frameTimer?.cancel();
    _backendTimer?.cancel();

    setState(() => _isDetecting = true);

    try {
      await http.post(Uri.parse("$baseUrl/start-detection"));
    } catch (e) {
      debugPrint("❌ Start detection error: $e");
    }

    // Fetch traffic status every 2 seconds
    _backendTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => fetchTrafficStatus(),
    );

    // Send frame every 5 seconds
    _frameTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_isDetecting || _isCapturing || !mounted) return;

      final controller = _cameraController;
      if (controller == null || !controller.value.isInitialized) return;
      if (controller.value.isTakingPicture) return;

      _isCapturing = true;

      try {
        final XFile file = await controller.takePicture();
        final Uint8List bytes = await file.readAsBytes();
        await sendFrame(bytes);
      } catch (e) {
        debugPrint("❌ Capture error: $e");
      } finally {
        _isCapturing = false;
      }
    });
  }

  Future<void> stopDetection() async {
    if (!_isDetecting) return;

    setState(() => _isDetecting = false);

    _frameTimer?.cancel();
    _backendTimer?.cancel();
    _frameTimer = null;
    _backendTimer = null;

    try {
      await http.post(Uri.parse("$baseUrl/stop-detection"));
    } catch (e) {
      debugPrint("❌ Stop detection error: $e");
    }
  }

  Future<void> sendFrame(Uint8List imageBytes) async {
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

      await request.send();
      debugPrint("📤 Frame sent successfully");
    } catch (e) {
      debugPrint("❌ Error sending frame: $e");
    }
  }

  @override
  void dispose() {
    _isDetecting = false;
    _frameTimer?.cancel();
    _backendTimer?.cancel();
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
                child: _isCameraReady
                    ? CameraPreview(_cameraController!)
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4D4DFF),
                        ),
                      ),
              ),
            ),

            SizedBox(height: 20),

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

            SizedBox(height: MediaQuery.of(context).size.width * 0.1),

            // Control Buttons
            Container(
              height: MediaQuery.of(context).size.height * 0.2,
              width: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                color: const Color.fromARGB(173, 160, 160, 160),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF4D4DFF), width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _isDetecting ? null : startDetection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: const Text("START"),
                  ),
                  ElevatedButton(
                    onPressed: _isDetecting ? stopDetection : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: const Text("STOP"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
    const SettingsPage(),
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
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Settings',
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

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
