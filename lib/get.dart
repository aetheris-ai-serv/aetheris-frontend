import 'package:flutter/material.dart';
import 'dart:ui';

// =====================================================================
// GET STARTED — Onboarding/Splash Screen
// =====================================================================
class GetStarted extends StatefulWidget {
  const GetStarted({super.key});

  @override
  State<GetStarted> createState() => _getStartedState();
}

class _getStartedState extends State<GetStarted> {
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
                                color: Colors.redAccent,
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
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4D4DFF),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          // Goes to Login page
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: const Text(
                          "Get started",
                          style: TextStyle(fontSize: 16, color: Colors.white),
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

// =====================================================================
// GLASS CONTAINER — Reusable glassmorphism widget
// =====================================================================
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
