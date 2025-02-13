import 'package:flutter/material.dart';
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
  final TextEditingController _bikeNumberController = TextEditingController();
  final TextEditingController _licenseNumberController = TextEditingController();
  String userType = 'Rider'; // Default user type
  final ApiService apiService = ApiService(baseUrl: "http://localhost:3000"); // Base URL for backend

  /// Register User
  Future<void> _register() async {
    final name = _nameController.text.trim();
    final contact = _contactController.text.trim();
    final password = _passwordController.text.trim();
    final bikeNumber = _bikeNumberController.text.trim();
    final licenseNumber = _licenseNumberController.text.trim();

    // Validate form fields
    if (name.isEmpty || contact.isEmpty || password.isEmpty) {
      _showErrorDialog('Please fill in all required fields.');
      return;
    }
    if (userType == 'Driver' && (bikeNumber.isEmpty || licenseNumber.isEmpty)) {
      _showErrorDialog('Please provide bike number and license number for drivers.');
      return;
    }

    // Prepare API request body
    final body = {
      "name": name,
      "contact": contact,
      "password": password,
      "userType": userType,
      if (userType == 'Driver') "bikeNumber": bikeNumber,
      if (userType == 'Driver') "licenseNumber": licenseNumber,
    };

    try {
      // Call the API using ApiService
      final response = await apiService.post('/register', body);
      print("Registration successful: $response");

      // Save public key and user type locally (if applicable)
      await savePublicKeyAndUserType(response['publicKey'], userType);

      // Navigate to login or home
      Navigator.pop(context); // Go back to the previous screen
    } catch (error) {
      print("Registration failed: $error");
      _showErrorDialog("Registration failed. Please try again.");
    }
  }

  /// Show error dialog
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
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Register as:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.blue.shade50,
                ),
                child: DropdownButton<String>(
                  value: userType,
                  onChanged: (String? value) {
                    setState(() {
                      userType = value!;
                    });
                  },
                  isExpanded: false,
                  iconEnabledColor: Colors.blueAccent,
                  items: const [
                    DropdownMenuItem(value: "Rider", child: Text("Rider")),
                    DropdownMenuItem(value: "Driver", child: Text("Driver")),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildTextField(_nameController, "Name", Icons.person),
              const SizedBox(height: 12),
              _buildTextField(_contactController, "Contact", Icons.phone),
              const SizedBox(height: 12),
              _buildTextField(_passwordController, "Password", Icons.lock, obscureText: true),
              const SizedBox(height: 12),

              // Only show these fields for the Driver
              if (userType == 'Driver') ...[
                _buildTextField(_bikeNumberController, "Bike Number", Icons.motorcycle),
                const SizedBox(height: 12),
                _buildTextField(_licenseNumberController, "License Number", Icons.card_membership),
                const SizedBox(height: 20),
              ],

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent, // Button color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: _register,
                child: const Text("Register"),
              ),
            ],
          ),
        ),
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
