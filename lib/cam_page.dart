import 'dart:ui';
import 'package:demo/map_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class Mycam extends StatefulWidget {
  const Mycam({super.key});

  @override
  State<Mycam> createState() => _MycamState();
}

final TextEditingController nameController = TextEditingController();
final TextEditingController ageController = TextEditingController();
final TextEditingController cityController = TextEditingController();

class _MycamState extends State<Mycam> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("images/page 3.png"),
            fit: BoxFit.cover,
          ),
        ),

        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.01),
            SizedBox(height: MediaQuery.of(context).size.width * 0.2),

            // First Container
            Container(
              height: MediaQuery.of(context).size.height * 0.5,
              width: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),

            SizedBox(height: MediaQuery.of(context).size.width * 0.1),

            // Second Container
            Container(
              height: MediaQuery.of(context).size.height * 0.2,
              width: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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

  final List<Widget> ScreenList = [
    const Mycam(),
    const MapPage(),
    const SettingsPage(),
    const ProfilePage(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenList[currentVal],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentVal,
        onTap: (index) {
          setState(() {
            currentVal = index; // update selected page
          });
        },
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
            backgroundColor: Color.fromARGB(255, 255, 255, 255),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
            backgroundColor: Color.fromARGB(255, 255, 255, 255),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
            backgroundColor: Color.fromARGB(255, 255, 255, 255),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
            backgroundColor: Color.fromARGB(255, 255, 255, 255),
          ),
        ],
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
    return Scaffold(
      appBar: AppBar(
        title: Text("SETTINGS"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("images/page 3.png"),
            fit: BoxFit.cover,
          ),
        ),
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
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            );
          },
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
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('images/page 3.png'),
          fit: BoxFit.cover,
        ),
        color: Color.fromARGB(255, 32, 31, 31),
      ),
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
                      gradient: LinearGradient(
                        colors: [
                          const Color.fromARGB(255, 65, 56, 162),
                          const Color.fromARGB(255, 144, 66, 223),
                        ],
                        begin: Alignment.topLeft, // start point
                        end: Alignment.bottomRight,
                      ),
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
