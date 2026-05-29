import 'package:flutter/material.dart';
import 'welcome_screen.dart'; // ✅ Ito yung hiwalay na welcome screen mo

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/bluebackground.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 50),

              // 🔹 Logo + App Name
              Image.asset(
                "assets/images/logo.png",
                height: 150,
                width: 150,
              ),
              const SizedBox(height: 20),
              const Text(
                "HealthTrack",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Spacer(),

              // 🔹 Get Started Button
              SizedBox(
                width: 220,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WelcomeScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 20,
                    ),
                  ),
                  child: const Text(
                    "Get Started",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 🔹 Bottom Section (Version + Description)
              Column(
                children: const [
                  Text(
                    "Version 1.0.0",
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Preventive HealthCare Management",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}