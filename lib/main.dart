import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/drivermap_screen.dart'; // Driver Map Screen
import 'screens/ridermap_screen.dart'; // Rider Map Screen
import 'screens/login_screen.dart'; // Login Screen
import 'screens/registration_screen.dart'; // Registration Screen
import 'screens/welcome_screen.dart';
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Ride Sharing',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'NotoSansDevanagari', // ✅ Set global font for the entire app
        ),
        initialRoute: '/login', // Set initial route to login
        routes: {
          '/welcome': (context)=>  WelcomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegistrationScreen(),
          '/driverMap': (context) => const DriverMapScreen(),
          '/riderMap': (context) => const RiderMapScreen(),
        },
      ),
    );
  }
}
