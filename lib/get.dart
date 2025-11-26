import 'package:flutter/material.dart';
import 'main.dart';
import 'dart:ui';

class getStarted extends StatefulWidget {
  const getStarted({super.key});

  @override
  State<getStarted> createState() => _getStartedState();
}

Future<void> main() async {
  runApp(const Myapp());
}

class Myapp extends StatelessWidget {
  const Myapp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // home: const MyHomePage(title: 'Flutter Demo Home Page'),
      initialRoute: '/get started',
      routes: {'/sign up': (context) => MyHomePage(title: 'Hello World')},
    );
  }
}

class _getStartedState extends State<getStarted> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('images/page1.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Container(
            child: Center(
              child: Container(
                width: (MediaQuery.of(context).size.width),
                height: (MediaQuery.of(context).size.height),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Top text
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 80.0,
                        left: 20,
                        right: 20,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.17,
                            ),
                            Text(
                              "Get",
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.height * 0.062,
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              "started",
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.height * 0.062,
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              "with",
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.height * 0.062,
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.05,
                            ),
                            Text(
                              "AETHERIS",
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.height * 0.068,
                                color: Colors.redAccent, // bluish accent
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.11),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 10,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        height: MediaQuery.of(context).size.height * 0.08,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                SizedBox(height: 10),
                                Text(
                                  'Get started',
                                  style: TextStyle(
                                    color: const Color.fromARGB(
                                      255,
                                      79,
                                      142,
                                      236,
                                    ),
                                    fontSize:
                                        MediaQuery.of(context).size.height *
                                        0.04,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 75),
                            IconButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/sign up',
                                );
                              },
                              icon: Icon(
                                Icons.arrow_forward_ios,
                                color: const Color.fromARGB(255, 79, 142, 236),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget vchild;
  final double vwidth;
  final double vheight;

  const GlassContainer({
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
            color: Colors.white.withValues(alpha: 0.2),
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
