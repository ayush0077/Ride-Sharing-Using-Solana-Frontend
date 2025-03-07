import 'dart:ui'; // ✅ Import for BackdropFilter
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_storage.dart';
import '../services/api_service.dart';
import 'forgotpassword_screen.dart';
import 'ridermap_screen.dart';
import 'drivermap_screen.dart';
import 'registration_screen.dart';
import 'change_password_screen.dart';
import 'animated_login_button.dart';  // Adjust path as needed

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final ApiService apiService = ApiService(baseUrl: "http://localhost:3000");

  // Toggle password visibility
  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  // Handle login functionality
  Future<void> _login() async {
    final usernameOrNumber = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (usernameOrNumber.isEmpty || password.isEmpty) {
      _showErrorDialog('Please fill in both fields.');
      return;
    }

    try {
      print("Sending Login Request...");
      final response = await apiService.post('/login', {
        "username": usernameOrNumber,
        "password": password,
      });

      print("Login Response: $response");

      final token = response['token'];
      final userType = response['userType'];
      final publicKey = response['publicKey'] ?? '';
      final passwordChanged = response['passwordChanged'] ?? true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);

      await savePublicKeyAndUserType(publicKey, userType);
      if (!passwordChanged) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChangePasswordScreen(username: usernameOrNumber),
          ),
        );
        return;
      }

      if (userType == 'Rider') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RiderMapScreen()),
        );
      } else if (userType == 'Driver') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverMapScreen()),
        );
      } else {
        _showErrorDialog('Unknown user type.');
      }
    } catch (e) {
      print("Login Failed: $e");
      _showErrorDialog(e.toString());
    }
  }

  // Error dialog popup
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      children: [
        // Background Image
        Positioned.fill(
          child: Image.asset(
            'assets/fonts/ride.jpg',
            fit: BoxFit.cover,
          ),
        ),
        // Semi-transparent overlay
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.3),
          ),
        ),

        // Login Box with Transparent Effect
        Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Frosted Glass Effect
                  child: Container(
                    padding: EdgeInsets.all(20),
                    width: 350,  // Set a fixed width
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2), // Transparent White
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)), // Slight Border
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "RideShare",
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          "Ride the Future",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 30),

                        // Username Input
                        TextField(
                          controller: _usernameController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Username or Contact",
                            labelStyle: TextStyle(color: Colors.white70),
                            prefixIcon: Icon(Icons.person, color: Colors.white),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.white70),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),

                        // Password Input
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Password",
                            labelStyle: TextStyle(color: Colors.white70),
                            prefixIcon: Icon(Icons.lock, color: Colors.white),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.white70),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white,
                              ),
                              onPressed: _togglePasswordVisibility,
                            ),
                          ),
                        ),
                        SizedBox(height: 10),

                        // Forgot Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: const Text("Forgot Password?", style: TextStyle(color: Colors.white)),
                          ),
                        ),

                        SizedBox(height: 16),

                        // Login Button
                        AnimatedLoginButton(
                          text: "Log In",
                          icon: Icons.login,
                          color: Colors.green.shade600,
                          onPressed: _login,
                        ),

                        SizedBox(height: 10),

                        // Register Text
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                            );
                          },
                          child: const Text(
                            "Don't have an account? Register",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}