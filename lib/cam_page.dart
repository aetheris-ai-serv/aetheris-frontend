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
  CameraController? _cameraController;
  late List<CameraDescription> _cameras;
  bool _isCameraReady = false;
  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();

    _cameraController = CameraController(
      _cameras[0], // rear camera
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    if (!mounted) return;

    _frameTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_cameraController!.value.isInitialized) {
        final XFile file = await _cameraController!.takePicture();
        final Uint8List bytes = await file.readAsBytes();
        await sendFrame(bytes);
      }
    });

    setState(() {
      _isCameraReady = true;
    });
  }

  Future<void> sendFrame(Uint8List imageBytes) async {
    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("http://10.242.46.233:8000/frame"),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          imageBytes,
          filename: "frame.jpg",
          contentType: MediaType("image", "jpeg"),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("📤 Frame sent");
      debugPrint("📥 Backend response: ${response.body}");
    } catch (e) {
      debugPrint("❌ Error sending frame: $e");
    }
  }

  @override
  void dispose() {
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

            // First Container
            Container(
              height: MediaQuery.of(context).size.height * 0.5,
              width: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                color: const Color.fromARGB(173, 160, 160, 160),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF4D4DFF), // border color
                  width: 2, // border width
                ),
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

            SizedBox(height: MediaQuery.of(context).size.width * 0.1),

            // Second Container
            Container(
              height: MediaQuery.of(context).size.height * 0.2,
              width: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                color: const Color.fromARGB(173, 160, 160, 160),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF4D4DFF), // border color
                  width: 2, // border width
                ),
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
      body: ScreenList[currentVal],

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
