import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_storage.dart';
import '../services/api_service.dart';
import 'forgotpassword_screen.dart';
import 'ridermap_screen.dart';
import 'drivermap_screen.dart';
import 'registration_screen.dart';

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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);

      await savePublicKeyAndUserType(publicKey, userType);

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
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade800, Colors.purpleAccent.shade200],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 10,
                shadowColor: Colors.black45,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 🚖 App Title
                      Text(
                        "RideShare",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 5),
                      // 🚗 Tagline
                      Text(
                        "Ride the Future",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 30),

                      // 🆔 Username Field
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: "Username or Contact",
                          prefixIcon: Icon(Icons.person, color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // 🔒 Password Field
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: Icon(Icons.lock, color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.blue,
                            ),
                            onPressed: _togglePasswordVisibility,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),

                      // 🔹 Forgot Password
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
                          child: const Text("Forgot Password?"),
                        ),
                      ),
                      SizedBox(height: 16),

                      // 🚀 Animated Login Button
                      AnimatedLoginButton(
                        text: "Log In",
                        icon: Icons.login,
                        color: Colors.green.shade600,
                        onPressed: _login,
                      ),
                      SizedBox(height: 10),

                      // 📌 Register Navigation
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                          );
                        },
                        child: const Text("Don't have an account? Register"),
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

// 🎨 Custom Animated Login Button
class AnimatedLoginButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const AnimatedLoginButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  _AnimatedLoginButtonState createState() => _AnimatedLoginButtonState();
}

class _AnimatedLoginButtonState extends State<AnimatedLoginButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 100),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: _isPressed
                ? []
                : [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(2, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text(
                widget.text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}