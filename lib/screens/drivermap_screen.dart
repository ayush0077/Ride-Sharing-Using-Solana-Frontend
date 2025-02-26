import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_storage.dart'; // For SharedPreferences
import 'dart:async';
import 'PaymentScreen.dart'; // ✅ Import the PaymentScreen file
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:math';



class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({Key? key}) : super(key: key);

  @override
  _DriverMapScreenState createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  final MapController _mapController = MapController();
  LatLng _currentLocation =LatLng(27.695585080429666, 85.2973644247388); // Default: Kathmandu
  List<Map<String, dynamic>> _availableRides = []; // Ride requests
  Map<String, dynamic>? _currentRide; // Accepted ride details
  final String backendUrl = "http://localhost:3000/"; // Backend URL
  String? _driverPublicKey;
  String? _previousRideStatus; // Driver's public key
  LatLng _fixedPickupLocation = LatLng(27.7120, 85.3100);
  WebSocketChannel? _channel; // Add this to manage the WebSocket connection
List<LatLng> _routeCoordinates = []; 
bool _hasDriverReached = false; // Flag to check if the driver has reached
bool _hasAcceptedRide = false;
LatLng _dropLocation = LatLng(0, 0);  // Default value (will be updated after driver reaches)
bool _isMoving = false;
Timer? _movementTimer;
bool _isRideStarted = false;
@override
void initState() {
  super.initState();
  _loadPublicKey(); // Load driver's public key dynamically
  _getCurrentLocation();
  _fetchAvailableRides();
  _initializeWebSocket(); // Initialize WebSocket connection
}

void _initializeWebSocket() {
  // Establish the WebSocket connection
  _channel = WebSocketChannel.connect(
    Uri.parse('ws://localhost:3000/'), // WebSocket server URL
  );

  // Listen to incoming WebSocket messages
  _channel!.stream.listen((message) {
    _handleWebSocketMessage(message);  // Handle incoming message
  });
}

void _handleWebSocketMessage(String message)async  {
   if (message.startsWith("Broadcast:")) {
      message = message.replaceFirst("Broadcast: ", "");
    }
  final data = jsonDecode(message);

  if (data['event'] == 'newRide') {
     if (data['event'] == 'newRide') {
    print("🚖 New Ride Received! Adding to the available rides list.");
    final ride = data['ride'];
    final rideId = ride['rideId'] ?? 'Unknown Ride';
    final rider = ride['rider'] ?? 'Unknown Rider'; 
    final pickup = ride['pickup'] ?? {}; // Ensure this is a Map
    final drop = ride['drop'] ?? {}; // Ensure this is a Map
    final fare = ride['fare'] ?? '0';
    final distance = (ride['distance'] != null) ? double.tryParse(ride['distance'].toString()) ?? 0.0 : 0.0;  // ✅ Fix distance
    final duration = (ride['duration'] != null) ? double.tryParse(ride['duration'].toString()) ?? 0.0 : 0.0;  // ✅ Fix duration
    final status = ride['status'] ?? 'Unknown';

    print("📍 Extracted Pickup: $pickup");
    print("📍 Extracted Drop: $drop");

    // 🟢 Convert lat/lng into human-readable addresses
    final pickupName = await _reverseGeocode(pickup['lat'], pickup['lng']);
    final dropName = await _reverseGeocode(drop['lat'], drop['lng']);

    setState(() {
      _availableRides.add({
        'rideId': rideId,
        'rider': rider,
        'pickup': pickup,
        'drop': drop,
        'pickupName': pickupName, // ✅ Now including human-readable name
        'dropName': dropName, // ✅ Now including human-readable name
        'fare': fare.toStringAsFixed(2),
        'distance': distance,
        'duration': duration,
        'status': status
      });
    });
     print("✅ Ride added to available rides!");
  }
  }
  // Handle ride accepted event
  if (data['event'] == 'rideAccepted') {
    _handleRideAccepted(data);
  }

  // Handle ride status change event
  if (data['event'] == 'rideStatusChanged') {
    _handleRideStatusChanged(data);
  }
}

void _handleRideAccepted(Map<String, dynamic> data) {
  // Update the available rides list and current ride
  setState(() {
    _availableRides.add(data['ride']); 
    _currentRide = data['ride'];
  });
}

void _handleRideStatusChanged(Map<String, dynamic> data) {
  // Update the status of the current ride if the ride ID matches
  if (_currentRide != null && _currentRide!['rideId'] == data['rideId']) {
    setState(() {
      _currentRide!['status'] = data['status'];
    });
  }
}


  /// Load the driver's public key from local storage
  Future<void> _loadPublicKey() async {
    final data = await getPublicKeyAndUserType();
    if (data['userType'] == 'Driver') {
      setState(() {
        _driverPublicKey = data['publicKey'];
      });
    } else {
      Navigator.of(context)
          .pushReplacementNamed('/rider-map'); // Redirect if not a driver
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
          "location": {
            "lat": _currentLocation.latitude,
            "lng": _currentLocation.longitude
          },
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
    } finally {
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
      print(
          "❌ ERROR: Missing required parameters. rideId: $rideId, rider: $rider");
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
          "riderPublicKey": rider,
          "status": "Accepted"
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _currentRide =
              _availableRides.firstWhere((ride) => ride['rideId'] == rideId);
          _availableRides.removeWhere((ride) => ride['rideId'] == rideId);
          _hasAcceptedRide = true;
          _isMoving = false; 
                _isRideStarted = false; // Reset ride start flag
      _hasDriverReached = false; // Reset driver reached flag
        });
              // Send WebSocket message about the ride acceptance
      

      if (_channel != null) {
        _channel!.sink.add(jsonEncode({
          'event': 'rideAccepted',
          'ride': _currentRide,  // Ensure _currentRide is not null
        }));
      }
      

        // Now update the fixed pickup location based on the pickup address
        String pickupAddress =
            _currentRide!['pickupName']; // Address of pickup location
        LatLng pickupLatLng = await _getLatLngFromAddress(
            pickupAddress); // Fetch LatLng from address

        setState(() {
          _fixedPickupLocation =
              pickupLatLng; // Update the fixed pickup location
        });
        // Fetch and show the route from the driver's current location to the pickup location
      _fetchRouteToPickup(pickupLatLng);
        print("✅ Ride accepted successfully and pickup location updated!");
        _startMovingToPickup();

      } else {
        print("❌ Error accepting ride: ${response.body}");
      }
    } catch (e) {
      print("❌ Exception while accepting ride: $e");
    }
  }
@override
void dispose() {
  super.dispose();
  _channel?.sink.close();  // Close the WebSocket connection
}
Future<void> _fetchRouteToPickup(LatLng pickupLatLng) async {
  try {
    final routeUrl = Uri.parse(
      "https://router.project-osrm.org/route/v1/driving/${_currentLocation.longitude},${_currentLocation.latitude};${pickupLatLng.longitude},${pickupLatLng.latitude}?overview=full&geometries=geojson"
    );

    final routeResponse = await http.get(routeUrl);

    if (routeResponse.statusCode == 200) {
      final data = jsonDecode(routeResponse.body);
      final List coordinates = data['routes'][0]['geometry']['coordinates'];

if (mounted) { // Check if the widget is still in the widget tree
  setState(() {
    _routeCoordinates = coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
  });
}

      print("✅ Route to pickup fetched successfully!");
    } else {
      print("❌ Error fetching route to pickup: ${routeResponse.body}");
    }
  } catch (e) {
    print("❌ Error fetching route: $e");
  }
}
  Future<LatLng> _getLatLngFromAddress(String address) async {
    try {
      final url = Uri.parse(
        "https://nominatim.openstreetmap.org/search?format=json&q=$address",
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lng = double.parse(data[0]['lon']);
          return LatLng(lat, lng); // Return the LatLng of the pickup address
        } else {
          throw Exception("Address not found");
        }
      } else {
        throw Exception("Failed to fetch location");
      }
    } catch (e) {
      print("Error getting LatLng from address: $e");
      return LatLng(0, 0); // Default location if geocoding fails
    }
  }

  Future<void> _completeRide() async {
    if (_currentRide == null) {
      print("❌ ERROR: No active ride to complete.");
      return;
    }

    try {
      final url = Uri.parse("${backendUrl}complete-ride");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"rideId": _currentRide!['rideId']}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _currentRide = null;
        });

        // ✅ Navigate to Payment Screen after completing the ride
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PaymentScreen()),
          );
        }

        print("✅ Ride completed successfully.");
      } else {
        print("❌ Error completing ride: ${response.body}");
      }
    } catch (e) {
      print("❌ Error completing ride: $e");
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
        "riderPublicKey":
            _currentRide!['rider'], // ✅ Ensure riderPublicKey is included
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
          _currentRide = null; // ✅ Ensure UI updates correctly
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
      final url = Uri.parse(
          "http://localhost:3000/ride-status?rideId=${_currentRide!['rideId']}");
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
    // Fetch the pickup and drop addresses
    String pickupAddress = _currentRide!['pickupName'];
    String dropAddress = _currentRide!['dropName'];

    // Get the pickup and drop LatLng coordinates
    LatLng pickupLatLng = await _getLatLngFromAddress(pickupAddress);
    LatLng dropLatLng = await _getLatLngFromAddress(dropAddress);

    setState(() {
      _currentLocation = pickupLatLng;  // Set driver's location to pickup address
      _hasDriverReached = true;  // Set the flag to true (route disappears)
      _dropLocation = dropLatLng; // Store the drop location for the marker
       _isRideStarted = false; // Ensure ride hasn't started yet
    });

    // Stop the movement timer (if running)
    _movementTimer?.cancel();

    // Send WebSocket message about the driver's arrival
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'event': 'driverReached',
        'rideId': _currentRide!['rideId'],
        'driverId': _driverPublicKey,
      }));
    }

    // Fetch the route from the pickup to the drop location
    await _fetchRouteFromPickupToDrop(pickupLatLng, dropLatLng);

    // Send request to backend to mark driver as "Reached"
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
        _currentRide!['status'] = 'Driver Reached'; // Update ride status
      });
      print("✅ Driver status updated to 'Driver Reached'");
    } else {
      print("❌ Error marking ride as 'Reached': ${response.body}");
    }
  } catch (e) {
    print("❌ Error updating driver location: $e");
  }
}
void _startRide() {
  print("🚗 Checking if ride can start. _isMoving: $_isMoving, _hasDriverReached: $_hasDriverReached");

  // Reset _isMoving and _hasDriverReached to false before starting the ride
  setState(() {
    _isMoving = false; // Reset to allow starting a new movement
    _hasDriverReached = false; // Reset driver reached flag
  });
  print("🚗 Starting the ride...");

  // Start the movement timer
  _movementTimer = Timer.periodic(Duration(seconds: 2), (timer) {
    print("⏱ Timer ticked. Checking the next point...");

    if (_currentRide == null || _routeCoordinates.isEmpty) {
      print("❌ Ride or route coordinates are null/empty.");
      timer.cancel();
      setState(() {
        _isMoving = false;
      });
      return;
    }

    // Get the next coordinate in the route
    LatLng nextPoint = _routeCoordinates[_currentRouteIndex];
    print("📍 Moving towards: $nextPoint");

    // Move towards the next coordinate on the route
    setState(() {
      _currentLocation = LatLng(
        _currentLocation.latitude + (nextPoint.latitude - _currentLocation.latitude) * 1.2,
        _currentLocation.longitude + (nextPoint.longitude - _currentLocation.longitude) * 1.2,
      );
    });

    print("📍 Current Location: $_currentLocation");

    // Send updated location to WebSocket
    _sendLocationToServer(_currentLocation.latitude, _currentLocation.longitude);

    // If the driver reaches the current point, move to the next point
    if (_calculateDistance(
          _currentLocation.latitude, 
          _currentLocation.longitude, 
          nextPoint.latitude, 
          nextPoint.longitude) < 0.01) {
      print("✅ Driver reached the next point.");
      _currentRouteIndex++; // Move to the next point on the route

      // Stop the timer when the driver reaches the end of the route
      if (_currentRouteIndex >= _routeCoordinates.length) {
        print("✅ Driver has reached the destination.");
        timer.cancel();
        setState(() {
          _isMoving = false; // End the movement when the route is completed
        });
        _notifyRiderDriverArrived();  // Notify the rider that the driver has reached the destination
      }
    }
  });
}



Future<void> _fetchRouteFromPickupToDrop(LatLng pickupLatLng, LatLng dropLatLng) async {
  try {
    // Send a request to the backend to fetch the route
    final routeUrl = Uri.parse("http://localhost:3000/get-route");
    final response = await http.post(
      routeUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "origin": {
          "latitude": pickupLatLng.latitude,
          "longitude": pickupLatLng.longitude
        },
        "destination": {
          "latitude": dropLatLng.latitude,
          "longitude": dropLatLng.longitude
        }
      }),
    );
    print("Backend Response Status: ${response.statusCode}");
    print("Backend Response Body: ${response.body}");
    if (response.statusCode == 200) {
      // Successfully received the route data
      final data = jsonDecode(response.body);

      if (data['route'] != null && data['route'].isNotEmpty) {
        final List coordinates = data['route'];
        setState(() {
          // Update the route coordinates
          _routeCoordinates = coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
        });
        print("✅ Route from pickup to drop fetched successfully!");
      } else {
        print("❌ No route data available");
      }
    } else {
      print("❌ Error fetching route from backend: ${response.body}");
    }
  } catch (e) {
    print("❌ Error fetching route from backend: $e");
  }
}


  Future<String> _getTimeToReach(LatLng destination) async {
    try {
      // Construct OSRM API URL for calculating route between current location and destination
      final routeUrl = Uri.parse(
          "https://router.project-osrm.org/route/v1/driving/${_currentLocation.longitude},${_currentLocation.latitude};${destination.longitude},${destination.latitude}?overview=false&steps=true");

      final response = await http.get(routeUrl);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Extracting the duration (in seconds) from the response and converting to minutes
        final durationInSeconds = data['routes'][0]['duration'];
        final durationInMinutes =
            (durationInSeconds / 60).round(); // Convert seconds to minutes
        return "$durationInMinutes min";
      } else {
        return "Unable to calculate time";
      }
    } catch (e) {
      print("Error fetching time to reach: $e");
      return "Error fetching time";
    }
  }
  int _currentRouteIndex = 0;
void _startMovingToPickup() {
  if (_isMoving || _hasDriverReached) return; // Prevent movement if driver has reached

  _isMoving = true;
  _movementTimer = Timer.periodic(Duration(seconds: 2), (timer) {
    if (_currentRide == null || _routeCoordinates.isEmpty) {
      timer.cancel();
      _isMoving = false;
      return;
    }

    // Get the next coordinate in the route
    LatLng nextPoint = _routeCoordinates[_currentRouteIndex];

    // Move towards the next coordinate on the route
    setState(() {
      _currentLocation = LatLng(
        _currentLocation.latitude + (nextPoint.latitude - _currentLocation.latitude) * 1.2,
        _currentLocation.longitude + (nextPoint.longitude - _currentLocation.longitude) * 1.2,
      );
    });

    setState(() {});

    // Send new location update to WebSocket
    _sendLocationToServer(_currentLocation.latitude, _currentLocation.longitude);

    // If the driver reaches the current point, move to the next point
    if (_calculateDistance(
          _currentLocation.latitude, 
          _currentLocation.longitude, 
          nextPoint.latitude, 
          nextPoint.longitude) < 0.01) {
      _currentRouteIndex++; // Move to the next point on the route

      // Stop the timer when the driver reaches the end of the route
      if (_currentRouteIndex >= _routeCoordinates.length) {
        timer.cancel();
        _isMoving = false;
        print("✅ Driver has reached pickup location.");
        _notifyRiderDriverArrived();
      }
    }
  });
}


void _sendLocationToServer(double lat, double lng) {
  if (_channel != null) {
    Map<String, dynamic> locationData = {
      "event": "driverLocationUpdate",
      "driverId": _driverPublicKey,
      "lat": lat,
      "lng": lng
    };
    _channel!.sink.add(jsonEncode(locationData));
    print("📡 Sent location update: $locationData");
  }
}
void _notifyRiderDriverArrived() {
  Map<String, dynamic> arrivalData = {
    "event": "driverReached",
    "driverId": _driverPublicKey,
  };
  _channel!.sink.add(jsonEncode(arrivalData));
  print("🚖 Driver has arrived at the pickup location!");
}
double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double R = 6371; // Earth radius in km
  double dLat = (lat2 - lat1) * (pi / 180);
  double dLon = (lon2 - lon1) * (pi / 180);
  double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) *
          sin(dLon / 2) * sin(dLon / 2);
  double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c; // Distance in km
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Driver Map",
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color.fromARGB(255, 132, 15, 228), Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchAvailableRides,
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
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
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 20),
                              title: Text("Pickup: ${ride['pickupName']}",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text("Drop: ${ride['dropName']}",
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  elevation: 3,
                                  padding: EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 20),
                                ),
                                onPressed: () {
                                  _acceptRide(ride['rideId'], ride['rider']);
                                },
                                child: Text("Accept",
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                              ),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
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
                    style: TextStyle(   fontFamily: 'NotoSansDevanagari',
    fontSize: 18,
    fontWeight: FontWeight.bold, // Ensure weight 700 is used
    color: Colors.black,),
                  ),
                  Text(
                    "Pickup: ${_currentRide!['pickupName']}",
                    style: TextStyle(
                      fontFamily: 'NotoSansDevanagari',
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600, // Stronger emphasis
                     
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

                  // Display Time to Reach
                  if (_fixedPickupLocation != null)
                    FutureBuilder<String>(
                      future: _getTimeToReach(_fixedPickupLocation!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Row(
                            children: [
                              CircularProgressIndicator(
                                  color: Colors.blueAccent),
                              SizedBox(width: 10),
                              Text("Calculating time...",
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.blue)),
                            ],
                          );
                        }
                        if (snapshot.hasData) {
                          return Text(
                            "Time to reach: ${snapshot.data}",
                            style:
                                TextStyle(fontSize: 16, color: Colors.orange),
                          );
                        }
                        return Text("Time to reach: Error");
                      },
                    ),

                  Text(
                      "Fare: Rs. ${( _currentRide!['fare'] != null ) ? double.tryParse(_currentRide!['fare'].toString())?.toStringAsFixed(2) ?? '0.00' : '0.00'}",
                  ),
                  Text(
                      "Distance: ${( _currentRide!['distance'] != null ) ? double.tryParse(_currentRide!['distance'].toString())?.toStringAsFixed(2) ?? '0.00' : '0.00'} km",
                  ),
                  Text(
                      "Duration: ${( _currentRide!['duration'] != null ) ? double.tryParse(_currentRide!['duration'].toString())?.toStringAsFixed(2) ?? '0.00' : '0.00'} min",
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Complete Ride Button
                      ElevatedButton(
                        onPressed: _completeRide,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.green, // Text color
                          padding: EdgeInsets.symmetric(
                              vertical: 12, horizontal: 30),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(15), // Rounded corners
                          ),
                          elevation: 5, // Shadow effect
                        ),
                        child: const Text(
                          "Complete Ride",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),

                      // Cancel Ride Button
                      ElevatedButton(
                        onPressed: _cancelRide,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.red, // Text color
                          padding: EdgeInsets.symmetric(
                              vertical: 12, horizontal: 30),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(15), // Rounded corners
                          ),
                          elevation: 5, // Shadow effect
                        ),
                        child: const Text(
                          "Cancel Ride",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),

                      // Reached Button
                       if (!_hasDriverReached)
                      ElevatedButton(
                        onPressed: _markAsReached,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.blue, // Text color
                          padding: EdgeInsets.symmetric(
                              vertical: 12, horizontal: 30),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(15), // Rounded corners
                          ),
                          elevation: 5, // Shadow effect
                        ),
                        child: const Text(
                          "I Have Reached",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                         // Start Ride Button (Visible after "I Have Reached" is clicked)
    if (_hasDriverReached && !_isRideStarted)
      ElevatedButton(
        onPressed: _startRide,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.blue,
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 5,
        ),
        child: const Text(
          "Start Ride",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
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
                  urlTemplate:
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c'],
                ),
                // Conditionally render the polyline
    if (_hasAcceptedRide && !_hasDriverReached)
      PolylineLayer(
        polylines: [
          Polyline(
            points: _routeCoordinates,  // Use the route coordinates here
            strokeWidth: 4.0,
            color: Colors.blue, // Blue route color
          ),
        ],
      ),
         if (_hasDriverReached)
      PolylineLayer(
        polylines: [
          Polyline(
            points: _routeCoordinates,  // Use the route coordinates from pickup to drop
            strokeWidth: 4.0,
            color: Colors.red, 
             // Route color
          ),
        ],
      ),        // Add polyline layer to show the route

                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation,
                      builder: (ctx) => Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue
                              .withOpacity(0.7), // Semi-transparent circle
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black45,
                                blurRadius: 4,
                                spreadRadius: 1)
                          ],
                        ),
                        child: Icon(Icons.local_taxi,
                            color: Colors.white, size: 30),
                      ),
                    ),
        if (!_hasDriverReached)              // Pickup location (Passenger)
        Marker(
          width: 80.0,
          height: 80.0,
          point: _fixedPickupLocation,  // Pickup location
      builder: (ctx) => Icon(
        Icons.person,  // This is the person icon
        color: const Color.fromARGB(255, 243, 65, 33),  // Customize the color to fit your UI
        size: 40.0,  // Adjust size as needed
      ),
        ),
         if (_hasDriverReached)
          Marker(
            width: 80.0,
            height: 80.0,
            point: _dropLocation,  // Drop location
            builder: (ctx) => Icon(
              Icons.location_on,  // Drop location icon
              color: Colors.red,   // Red for the destination
              size: 40.0,
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

  Future<void> clearLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs
        .clear(); // This will clear all the stored data in shared preferences
    print("Local storage cleared.");
  }
}