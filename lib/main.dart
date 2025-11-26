import 'package:demo/cam_page.dart';
import 'package:demo/map_page.dart';
import 'dart:async';
import 'get.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

final TextEditingController nameController = TextEditingController();
final TextEditingController ageController = TextEditingController();
final TextEditingController cityController = TextEditingController();

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: isLoggedIn ? '/home' : '/get started', // ✅ check here
      routes: {
        '/get started': (context) => getStarted(),
        '/sign up': (context) => MyHomePage(title: 'Hello World'),
        '/login': (context) => LoginPage(),
        '/map': (context) => MapPage(),
        '/home': (context) => BottomBar(),
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController email = TextEditingController();
  final TextEditingController pass = TextEditingController();
  bool visib = false;
  // 🔹 Sign In method
  Future<void> signIn() async {
    if (email.text.isEmpty || pass.text.isEmpty) {
      // Show warning if fields are empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter both email and password"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return; // stop further execution
    }
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: email.text.trim(),
            password: pass.text.trim(),
          );
      print("User logged in: ${userCredential.user?.uid}");

      // ✅ Save login state
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('uid', userCredential.user!.uid);

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      print("Login error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login failed: $e")));
    }
  }

  // 🔹 Sign Up method
  Future<void> signUp() async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.text.trim(),
            password: pass.text.trim(),
          );
      print("User registered: ${userCredential.user?.uid}");

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      print("Signup error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Signup failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('images/page2.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          // color: LinearGradient(colors: [Colors.red,Colors.black]),
          color: Colors.transparent,
          padding: EdgeInsetsGeometry.symmetric(vertical: 20, horizontal: 10),
          child: Center(
            child: GlassContainer(
              vwidth: MediaQuery.of(context).size.width * 0.85,
              vheight: MediaQuery.of(context).size.height * 0.5,
              vchild: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Padding(
                  padding: EdgeInsetsGeometry.all(30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(height: 5),
                      Text(
                        'LOGIN',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.height * 0.05,
                          color: Color.fromRGBO(107, 107, 255, 1),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 20),

                      TextField(
                        controller: email,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hint: Text(
                            'Email',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Colors.white,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: const Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: Color.fromRGBO(77, 77, 255, 1),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 30),

                      TextField(
                        controller: pass,
                        obscureText: visib,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hint: Text(
                            'Password',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          prefixIcon: Icon(Icons.lock, color: Colors.white),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                visib = !visib;
                              });
                            },
                            icon: Icon(
                              visib ? Icons.visibility_off : Icons.visibility,
                            ),
                            color: Colors.white,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: const Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: Color.fromRGBO(77, 77, 255, 1),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 30),

                      ElevatedButton(
                        onPressed: signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromRGBO(77, 77, 255, 1),
                          foregroundColor: Colors.white,
                          minimumSize: Size(
                            MediaQuery.of(context).size.height * 0.9,
                            MediaQuery.of(context).size.width * 0.13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text('SignIn'),
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Don't have an account?",
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.height * 0.018,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(
                                context,
                                '/sign up',
                              );
                            },
                            child: Text(
                              "Register",
                              style: TextStyle(
                                color: Color.fromRGBO(107, 107, 255, 1),
                                fontSize:
                                    MediaQuery.of(context).size.height * 0.018,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool visib = false;
  TextEditingController email = TextEditingController();
  TextEditingController pass = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('images/page2.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          color: Colors.transparent,
          padding: EdgeInsetsGeometry.symmetric(vertical: 20, horizontal: 10),
          child: Center(
            child: GlassContainer(
              vwidth: MediaQuery.of(context).size.width * 0.85,
              vheight: MediaQuery.of(context).size.height * 0.5,
              vchild: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                // child: text,
                child: Padding(
                  padding: EdgeInsetsGeometry.all(30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(height: 5),
                      Text(
                        'REGISTER',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.height * 0.05,
                          color: Color.fromRGBO(107, 107, 255, 1),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 20),

                      TextField(
                        controller: email,
                        style: TextStyle(color: Colors.transparent),
                        decoration: InputDecoration(
                          hint: Text(
                            'Email',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Colors.white,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: const Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: Color.fromRGBO(77, 77, 255, 1),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 30),

                      TextField(
                        controller: pass,
                        obscureText: visib,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hint: Text(
                            'Password',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          prefixIcon: Icon(Icons.lock, color: Colors.white),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                visib = !visib;
                              });
                            },
                            icon: Icon(
                              visib ? Icons.visibility_off : Icons.visibility,
                            ),
                            color: Colors.white,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: const Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: Color.fromRGBO(77, 77, 255, 1),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 30),

                      ElevatedButton(
                        onPressed: () async {
                          if (email.text.isEmpty || pass.text.isEmpty) {
                            // show warning if any field is empty
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Please enter both email and password",
                                ),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return; // stop further execution
                          }
                          try {
                            UserCredential userCredential = await FirebaseAuth
                                .instance
                                .createUserWithEmailAndPassword(
                                  email: email.text,
                                  password: pass.text,
                                );
                            print(
                              "User registered: ${userCredential.user?.uid}",
                            );
                            Navigator.pushReplacementNamed(context, '/home');
                          } catch (e) {
                            print("Error: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromRGBO(77, 77, 255, 1),
                          foregroundColor: Colors.white,
                          minimumSize: Size(
                            MediaQuery.of(context).size.height * 0.9,
                            MediaQuery.of(context).size.width * 0.13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text('SignUp'),
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Already have an account?",
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.height * 0.018,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            child: Text(
                              "Login",
                              style: TextStyle(
                                color: Color.fromRGBO(107, 107, 255, 1),
                                fontSize:
                                    MediaQuery.of(context).size.height * 0.018,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
