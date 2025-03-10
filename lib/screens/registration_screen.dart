import 'dart:ui'; // ✅ Import for BackdropFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/local_storage.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bikeNumberController = TextEditingController();
  final TextEditingController _licenseNumberController = TextEditingController();
  String userType = 'Rider'; // Default user type
  final ApiService apiService = ApiService(baseUrl: "http://localhost:3000"); // Base URL for backend

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final contact = _contactController.text.trim();
    final password = _passwordController.text.trim();
    final email = _emailController.text.trim();
    final bikeNumber = _bikeNumberController.text.trim();
    final licenseNumber = _licenseNumberController.text.trim();

    if (name.isEmpty || contact.isEmpty || password.isEmpty || email.isEmpty) {
      _showErrorDialog('Please fill in all required fields.');
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      _showErrorDialog("Please enter a valid email address.");
      return;
    }

    if (userType == 'Driver' && (bikeNumber.isEmpty || licenseNumber.isEmpty)) {
      _showErrorDialog('Please provide bike number and license number for drivers.');
      return;
    }

    final body = {
      "name": name,
      "contact": contact,
      "password": password,
      "email": email,
      "userType": userType,
      if (userType == 'Driver') "bikeNumber": bikeNumber,
      if (userType == 'Driver') "licenseNumber": licenseNumber,
    };

    try {
      final response = await apiService.post('/register', body);
      print("Registration successful: $response");
      await savePublicKeyAndUserType(response['publicKey'], userType);
      Navigator.pop(context);
    } catch (error) {
      print("Registration failed: $error");
      _showErrorDialog("Registration failed. Please try again.");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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

          // Transparent Registration Box
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 350,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Register as:",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          const SizedBox(height: 10),

                          // User Type Dropdown
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white70),
                                color: Colors.white.withOpacity(0.1),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
                              child: DropdownButton<String>(
                                value: userType,
                                onChanged: (String? value) {
                                  setState(() {
                                    userType = value!;
                                  });
                                },
                                isExpanded: false,
                                iconEnabledColor: Colors.white,
                                dropdownColor: Colors.black87,
                                style: TextStyle(color: Colors.white),
                                underline: Container(),
                                items: const [
                                  DropdownMenuItem(value: "Rider", child: Text("Rider", style: TextStyle(color: Colors.white))),
                                  DropdownMenuItem(value: "Driver", child: Text("Driver", style: TextStyle(color: Colors.white))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          _buildTextField(_nameController, "Name", Icons.person),
                          const SizedBox(height: 12),
                          _buildTextField(_contactController, "Contact", Icons.phone, keyboardType: TextInputType.number),
                          const SizedBox(height: 12),
                          _buildTextField(_passwordController, "Password", Icons.lock, obscureText: true),
                          const SizedBox(height: 12),
                          _buildTextField(_emailController, "Email", Icons.email),
                          const SizedBox(height: 12),

                          if (userType == 'Driver') ...[
                            _buildTextField(_bikeNumberController, "Bike Number", Icons.motorcycle),
                            const SizedBox(height: 12),
                            _buildTextField(_licenseNumberController, "License Number", Icons.card_membership),
                            const SizedBox(height: 20),
                          ],

                          // Back Button and Register Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Back Button
                              IconButton(
                                icon: Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                              const SizedBox(width: 10),

                              // Register Now Button
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  child: const Text("Register Now"),
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
        ],
      ),
    );
  }

  // Custom TextField builder
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscureText = false,TextInputType keyboardType = TextInputType.text,}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
        inputFormatters: keyboardType == TextInputType.number
        ? [FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(10)] // Only allow digits
        : [],
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white70),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
      
    );
  }
}
