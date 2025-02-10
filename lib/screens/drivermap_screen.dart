import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/local_storage.dart'; // For SharedPreferences
import 'dart:async';


class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({Key? key}) : super(key: key);

  @override
  _DriverMapScreenState createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = LatLng(27.7172, 85.3280); // Default: Kathmandu
  List<Map<String, dynamic>> _availableRides = []; // Ride requests
  Map<String, dynamic>? _currentRide; // Accepted ride details
  final String backendUrl = "http://localhost:3000/"; // Backend URL
  String? _driverPublicKey; 
     String? _previousRideStatus;// Driver's public key
  
  @override
  void initState() {
    super.initState();
    _loadPublicKey(); // Load driver's public key dynamically
    _getCurrentLocation();
    _fetchAvailableRides();
      // ✅ Poll ride status every 10 seconds
  Timer.periodic(Duration(seconds: 10), (timer) {
    if (mounted) {
      _fetchRideStatus();
    }
  });
 
  }

  /// Load the driver's public key from local storage
  Future<void> _loadPublicKey() async {
    final data = await getPublicKeyAndUserType();
    if (data['userType'] == 'Driver') {
      setState(() {
        _driverPublicKey = data['publicKey'];
      });
    } else {
      Navigator.of(context).pushReplacementNamed('/rider-map'); // Redirect if not a driver
    }
  }

  /// Fetch the driver's current location and update it on the backend.
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLocation = LatLng(position.latitude, position.longitude);
      await _updateDriverLocation(); // Update location on the backend
      _mapController.move(_currentLocation, 14.0); // Center map
    } catch (e) {
      print("Error fetching location: $e");
    }
  }

  /// Update the driver's location on the backend.
  Future<void> _updateDriverLocation() async {
    if (_driverPublicKey == null) return;
    try {
      final url = Uri.parse("${backendUrl}update-location");
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "driverPublicKey": _driverPublicKey,
          "location": {"lat": _currentLocation.latitude, "lng": _currentLocation.longitude},
        }),
      );
    } catch (e) {
      print("Error updating driver location: $e");
    }
  }

bool _isLoading = false; // ✅ Track loading state
  /// Fetch available ride requests from the backend.
Future<void> _fetchAvailableRides() async {
 setState(() => _isLoading = true);
  try {
    final url = Uri.parse("${backendUrl}get-available-rides");
    final response = await http.get(url);

    print("API Response: ${response.body}"); // Debugging

    if (response.statusCode == 200) {
      List<dynamic> rides = jsonDecode(response.body);
      
      if (rides.isEmpty) {
        setState(() {
          _availableRides = [];
        });
        print("No available rides found.");
        return;
      }

      // Add reverse geocoding for pickup/drop locations
      final enrichedRides = await Future.wait(rides.map((ride) async {
        final rideMap = Map<String, dynamic>.from(ride);
        final pickupName = await _reverseGeocode(
            rideMap['pickup']['lat'], rideMap['pickup']['lng']);
        final dropName = await _reverseGeocode(
            rideMap['drop']['lat'], rideMap['drop']['lng']);
        return {...rideMap, 'pickupName': pickupName, 'dropName': dropName};
      }).toList());

      setState(() {
        _availableRides = enrichedRides.cast<Map<String, dynamic>>();
      });
      print("Available rides fetched successfully.");
    } else {
      print("Error fetching rides: ${response.body}");
    }
  } catch (e) {
    print("Exception fetching rides: $e");
  }
  finally {
    setState(() => _isLoading = false); // ✅ Hide loading spinner
  }
}


  /// Perform reverse geocoding to get place names from coordinates
  Future<String> _reverseGeocode(double lat, double lng) async {
  try {
    print("Reverse Geocoding for Lat: $lat, Lng: $lng"); // Debugging

    final url = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      print("Reverse Geocode Response: ${data['display_name']}"); // Debugging
      return data['display_name'] ?? "Unknown location";
    } else {
      return "Unknown location";
    }
  } catch (e) {
    print("Error reverse geocoding: $e");
    return "Unknown location";
  }
}

  /// Accept a ride request.
Future<void> _acceptRide(String? rideId, String? rider) async {
  if (_driverPublicKey == null || rideId == null || rider == null) {
    print("❌ ERROR: Missing required parameters. rideId: $rideId, rider: $rider");
    return;
  }

  try {
    final url = Uri.parse("${backendUrl}accept-ride");
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "rideId": rideId,
        "driverPublicKey": _driverPublicKey,
        "riderPublicKey": rider,  // ✅ Use "rider" instead of "riderPublicKey"
        "status": "Accepted"
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        _currentRide = _availableRides.firstWhere((ride) => ride['rideId'] == rideId);
        _availableRides.removeWhere((ride) => ride['rideId'] == rideId);
      });
      print("✅ Ride accepted successfully!");
    } else {
      print("❌ Error accepting ride: ${response.body}");
    }
  } catch (e) {
    print("❌ Exception while accepting ride: $e");
  }
}


  /// Complete the current ride.
  Future<void> _completeRide() async {
    try {
      final url = Uri.parse("${backendUrl}complete-ride");
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"rideId": _currentRide!['rideId']}),
      );
      setState(() {
        _currentRide = null;
      });
    } catch (e) {
      print("Error completing ride: $e");
    }
  }

  /// Cancel the current ride.
Future<void> _cancelRide() async {
  if (_currentRide == null) {
    print("❌ ERROR: No active ride to cancel.");
    return;
  }

  if (!_currentRide!.containsKey('rider') || _currentRide!['rider'] == null) {
    print("❌ ERROR: Missing riderPublicKey in _currentRide!");
    return;
  }

  try {
    final url = Uri.parse("${backendUrl}cancel-ride");
    final requestBody = jsonEncode({
      "rideId": _currentRide!['rideId'],
      "riderPublicKey": _currentRide!['rider'],  // ✅ Ensure riderPublicKey is included
    });

    print("🔄 Sending cancel request: $requestBody"); // Debugging

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    if (response.statusCode == 200) {
      print("✅ Ride cancelled successfully.");

      setState(() {
        _currentRide = null;  // ✅ Ensure UI updates correctly
      });
    } else {
      print("❌ Failed to cancel ride: ${response.body}");
    }
  } catch (e) {
    print("❌ Error cancelling ride: $e");
  }
}


  Future<void> _fetchRideStatus() async {
  if (_currentRide == null) return; // No active ride

  try {
    final url = Uri.parse("http://localhost:3000/ride-status?rideId=${_currentRide!['rideId']}");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String newStatus = data['status'];

      // ✅ If status changes to "Cancelled", show a Snackbar
      if (newStatus == "Cancelled" && _previousRideStatus != "Cancelled") {
        _showCancellationSnackbar();
      }

      setState(() {
        _previousRideStatus = newStatus;

        // If ride is canceled, reset _currentRide
        if (newStatus == "Cancelled") {
          _currentRide = null;
        }
      });

      print("✅ Ride status updated: $newStatus");
    } else {
      print("❌ Error fetching ride status: ${response.body}");
    }
  } catch (e) {
    print("❌ Exception fetching ride status: $e");
  }
}
Future<void> _logout() async {
  try {
    // Clear stored user data
    await clearLocalStorage(); // ✅ Clears stored public key and user type

    // Navigate to the login screen
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }

    print("✅ Successfully logged out.");
  } catch (e) {
    print("❌ Error during logout: $e");
  }
}


/// Show a Snackbar when ride is cancelled
void _showCancellationSnackbar() {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text("🚨 The ride has been cancelled by the rider!"),
      backgroundColor: Colors.red,
      duration: Duration(seconds: 3),
    ),
  );
}

/// Mark the driver as "Reached" at the destination.
Future<void> _markAsReached() async {
  if (_currentRide == null) {
    print("❌ ERROR: No active ride to update.");
    return;
  }

  try {
    final url = Uri.parse("${backendUrl}mark-reached");
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "rideId": _currentRide!['rideId'],
        "driverPublicKey": _driverPublicKey,
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        // Update the current ride status to "Driver Reached"
        _currentRide!['status'] = 'Driver Reached';
      });
      print("✅ Driver status updated to 'Reached'");
    } else {
      print("❌ Error marking ride as 'Reached': ${response.body}");
    }
  } catch (e) {
    print("❌ Error updating driver status: $e");
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Driver Map"),
          actions: [
    IconButton(
      icon: Icon(Icons.refresh),
      onPressed: _fetchAvailableRides, // ✅ Manually refresh rides
    ),
    IconButton(
      icon: Icon(Icons.logout), // 🔴 Logout button
      onPressed: _logout, // ✅ Calls logout function
    ),
  ],
      ),
      
      body: Column(
        children: [
          // Available Rides List
          if (_currentRide == null)
            Expanded(
              flex: 1,
                child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _availableRides.isNotEmpty
              
                  ? ListView.builder(
                      itemCount: _availableRides.length,
                      itemBuilder: (context, index) {
                        final ride = _availableRides[index];
                        return ListTile(
                          title: Text("Pickup: ${ride['pickupName']}"),
                          subtitle: Text("Drop: ${ride['dropName']}"),
                          trailing: ElevatedButton(
  onPressed: () {
    print("Ride Data: ${ride.toString()}"); // ✅ Debugging Log
    print("rideId: ${ride['rideId']}, rider: ${ride['rider']}"); // ✅ Log rider

    if (ride['rideId'] == null || ride['rider'] == null) {
      print("❌ ERROR: rideId or rider is NULL");
      return; // Prevent sending null values
    }

    _acceptRide(ride['rideId'], ride['rider']); // ✅ Use "rider" instead of "riderPublicKey"
  },
  child: const Text("Accept"),
),

                        );
                      },
                    )
                  : const Center(child: Text("No available rides")),
            ),

          // Accepted Ride Details
          if (_currentRide != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Accepted Ride Details:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
Text(
  "Pickup: ${_currentRide!['pickupName']}",
  style: TextStyle(
    fontFamily: 'NotoSansDevanagari',
    fontSize: 16,
    color: Colors.black, // Force color for visibility
    fontWeight: FontWeight.normal,
    fontFeatures: [FontFeature.enable('liga')], // Helps fix rendering issues
  ),
),
Text(
  "Drop: ${_currentRide!['dropName']}",
  style: TextStyle(
    fontFamily: 'NotoSansDevanagari',
    fontSize: 16,
    color: Colors.black,
    fontWeight: FontWeight.normal,
    fontFeatures: [FontFeature.enable('liga')],
  ),
),


                Text("Fare: Rs. ${(double.parse(_currentRide!['fare'].toString())).toStringAsFixed(2)}"),
                Text("Distance: ${_currentRide!['distance'].toStringAsFixed(2)} km"),
                Text("Duration: ${_currentRide!['duration'].toStringAsFixed(2)} min"),


                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: _completeRide,
                        child: const Text("Complete Ride"),
                      ),
                      ElevatedButton(
                        onPressed: _cancelRide,
                        child: const Text("Cancel Ride"),
                      ),
                        // Reached Button
            ElevatedButton(
              onPressed: _markAsReached,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Blue color for Reached button
              ),
              child: const Text("I Have Reached"),
            ),
                    ],
                  ),
                ],
              ),
            ),

          // Map showing driver's location
          Expanded(
            flex: 2,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _currentLocation,
                zoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation,
                      builder: (ctx) => const Icon(
                        Icons.local_taxi,
                        color: Colors.green,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  clearLocalStorage() {}
}
