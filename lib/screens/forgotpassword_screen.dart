import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import http package
import 'dart:convert'; // Add this import for jsonEncode

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();

  // Function to reset the password
void _resetPassword() async {
  final email = _emailController.text.trim();

  // Check if email is empty
  if (email.isEmpty) {
    _showErrorDialog('Please enter your email.');
    return;
  }

  print('Attempting to reset password for email: $email');  // Debugging line

  try {
    // Sending the email to the backend for password reset
    final response = await http.post(
      Uri.parse('http://localhost:3000/reset-password'), // Your backend URL
      headers: {
        "Content-Type": "application/json",  // Add header for JSON format
      },
      body: jsonEncode({
        'email': email,  // Send email as part of the JSON body
      }),
    );

    // Debugging response status code
    print('Response status code: ${response.statusCode}');
    print('Response body: ${response.body}');  // Print response body

    // Check the response from the backend
    if (response.statusCode == 200) {
      // If success, show success message
      _showErrorDialog('Password reset link sent to $email.');
    } else {
      // If there's any error
      _showErrorDialog('Failed to send reset link. Please try again.');
    }
  } catch (error) {
    // Handle any network errors
    print('Error occurred while sending the reset link: $error');  // Debugging line
    _showErrorDialog('Failed to send reset link. Please try again.');
  }
}


  // Function to show error message in a dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Notice'),
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
        title: const Text("Forgot Password"),
        backgroundColor: Colors.green, // Green background for the AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Container(
            width: 350, // Set fixed width similar to the registration screen
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Enter your email to reset your password.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      labelStyle: const TextStyle(color: Colors.blueAccent),
                      filled: true,
                      fillColor: Colors.blue.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade400),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _resetPassword, // Call _resetPassword when pressed
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, // Green button background color
                      foregroundColor: Colors.white, // White text color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // Rounded corners for the button
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    child: const Text("Reset Password"), // Button text
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
