import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatting
import '../services/api_service.dart'; // Import ApiService
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

    // Validate Email format
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
      Navigator.pop(context); // Go back to the previous screen
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
      appBar: AppBar(
        title: const Text("Register"),
        backgroundColor: Colors.green, // Green background like the reference image
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
        child: Center(
          child: Container(
            width: 350, // Form width similar to the reference
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 3,
                  blurRadius: 6,
                  offset: Offset(0, 3), // Shadow position
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Register as:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Center(  // Added Center widget to make DropdownButton centered
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12), 
                        border: Border.all(color: Colors.blue.shade400), // Light blue border similar to TextField
                        color: Colors.blue.shade50, // Background color matching TextField
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10), 
                      child: DropdownButton<String>(
                        value: userType,
                        onChanged: (String? value) {
                          setState(() {
                            userType = value!;
                          });
                        },
                        isExpanded: false, // Non full width for dropdown
                        iconEnabledColor: Colors.blueAccent,
                        style: TextStyle(color: Colors.black),
                        underline: Container(),
                        items: const [
                          DropdownMenuItem(value: "Rider", child: Text("Rider")),
                          DropdownMenuItem(value: "Driver", child: Text("Driver")),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(_nameController, "Name", Icons.person),
                  const SizedBox(height: 12),
                  _buildContactField(),  // Using a custom function for phone validation
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
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // Green button
                        foregroundColor: Colors.white, // White text
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _register,
                      child: const Text("Register Now"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Custom Contact Field builder for phone number validation
  Widget _buildContactField() {
    return TextField(
      controller: _contactController,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,  // Only digits are allowed
      ],
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.phone, color: Colors.blueAccent),
        labelText: "Contact",
        labelStyle: const TextStyle(color: Colors.blueAccent),
        filled: true,
        fillColor: Colors.blue.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade400),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
    );
  }

  // Custom TextField builder for DRY code
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.blueAccent),
        filled: true,
        fillColor: Colors.blue.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade400),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
    );
  }
}
