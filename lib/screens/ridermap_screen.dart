import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/local_storage.dart'; // For loading public key and user type
import 'dart:async';


class RiderMapScreen extends StatefulWidget {
  const RiderMapScreen({Key? key}) : super(key: key);

  @override
  _RiderMapScreenState createState() => _RiderMapScreenState();
}

class _RiderMapScreenState extends State<RiderMapScreen> {
  final MapController _mapController = MapController();
  // Bounding box for Kathmandu Valley
    double? _fare;
  double? _distance;
  double? _duration;
  Map<String, dynamic>? _currentRide; // ✅ Declare currentRide
String? _previousRideStatus = ""; // ✅ Initialize with an empty string
String? _currentRideId; // ✅ Store the latest ride ID
String? _previousRideId;
LatLng? _destinationLocation;
bool _isDestinationFocused = false; // Add this flag

String? _rideStatus; // Stores the ride status
LatLng? _driverLocation = LatLng(27.695558080429666, 85.2973644247388); // Manually set


  // ✅ Store last known ride status


final LatLngBounds _kathmanduBounds = LatLngBounds(
  LatLng(27.55, 85.15), // Southwest boundary
  LatLng(27.85, 85.55), // Northeast boundary
);

  LatLng _currentLocation = LatLng(27.689732409781158, 85.29001686524454); // Default Kathmandu location
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  List<String> _destinationSuggestions = [];
  List<String> _pickupSuggestions = [];
  List<LatLng> _routeCoordinates = [];
  String? _riderPublicKey; // Rider's public key
  final String backendUrl = "http://localhost:3000/"; // Backend URL

  @override
  void initState() {
    super.initState();
    _loadPublicKey(); // Load the rider's public key dynamically
    _getCurrentLocation();
      // ✅ Check ride status every 10 seconds
  Timer.periodic(Duration(seconds: 10), (timer) {
    if (mounted) {
      _fetchRideStatus(context);
    }
  });
  }

  /// Load the rider's public key from local storage
  Future<void> _loadPublicKey() async {
    final data = await getPublicKeyAndUserType();
    if (data['userType'] == 'Rider') {
      setState(() {
        _riderPublicKey = data['publicKey'];
      });
    } else {
      // Redirect to DriverMapScreen if user is a driver
      Navigator.of(context).pushReplacementNamed('/driver-map');
    }
  }

  /// Fetch the rider's current location and set it as the pickup location.
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLocation = LatLng(position.latitude, position.longitude);

      // Reverse geocode to get pickup address
      final url = Uri.parse(
          "https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _pickupController.text = data['display_name'] ?? "Unknown location";
        });
      }

      _mapController.move(_currentLocation, 14.0); // Move map to current location
    } catch (e) {
      print("Error fetching location: $e");
    }
  }
  

  /// Fetch destination suggestions based on user input.
void _searchSuggestions(String query) async {
  if (query.isEmpty) {
    setState(() {
      // Clear suggestions if query is empty
      _destinationSuggestions = [];
      _pickupSuggestions = [];
    });
    return;
  }

  try {
    String url = "https://nominatim.openstreetmap.org/search?q=$query,Kathmandu,Nepal&format=json&addressdetails=1&limit=5";
    
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);

      setState(() {
        // Update suggestions based on the focused field
        if (_isDestinationFocused) {
          _destinationSuggestions = data.map((item) => item['display_name'] as String).toList();
        } else {
          _pickupSuggestions = data.map((item) => item['display_name'] as String).toList();
        }
      });
    }
  } catch (e) {
    print("Error fetching suggestions: $e");
  }
}




  /// Fetch the route from the pickup to the destination.
Future<void> _fetchRoute(String destination) async {
  try {
    final geocodeUrl = Uri.parse(
        "https://nominatim.openstreetmap.org/search?q=$destination&format=json&limit=1");
    final geocodeResponse = await http.get(geocodeUrl);

    if (geocodeResponse.statusCode == 200) {
      final List geocodeData = jsonDecode(geocodeResponse.body);
      if (geocodeData.isEmpty) throw Exception("Destination not found");

      final destLat = double.parse(geocodeData[0]['lat']);
      final destLon = double.parse(geocodeData[0]['lon']);

      setState(() {
        _destinationLocation = LatLng(destLat, destLon); // ✅ Store draggable marker position
      });

      final routeUrl = Uri.parse(
          "https://router.project-osrm.org/route/v1/driving/${_currentLocation.longitude},${_currentLocation.latitude};${destLon},${destLat}?overview=full&geometries=geojson");
      final routeResponse = await http.get(routeUrl);

      if (routeResponse.statusCode == 200) {
        final data = jsonDecode(routeResponse.body);
        final List coordinates = data['routes'][0]['geometry']['coordinates'];
        setState(() {
          _routeCoordinates =
              coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
        });
      }
    }
  } catch (e) {
    print("Error fetching route: $e");
  }
}


  /// Create a new ride.
 Future<void> _createRide(
  LatLng pickup,
  LatLng drop,
  DateTime startTime,
  DateTime endTime
) async {
  if (_riderPublicKey == null) {
    print("Rider public key is not loaded.");
    return;
  }

  setState(() {
    _currentRide = null;
  });

  try {
    final url = Uri.parse("${backendUrl}create-ride");
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "riderPublicKey": _riderPublicKey,
        "pickup": {"lat": pickup.latitude, "lng": pickup.longitude},
        "drop": {"lat": drop.latitude, "lng": drop.longitude},
        "startTime": startTime.toIso8601String(),
        "endTime": endTime.toIso8601String(),
      }),
    );

    print("Response status: ${response.statusCode}");
    print("Response body: ${response.body}");

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      setState(() {
        _currentRide = data['ride'];
        _fare = double.tryParse(data['ride']['fare'].toString()) ?? 0.0;
        _distance = double.tryParse(data['ride']['distance'].toString()) ?? 0.0;
        _duration = double.tryParse(data['duration'].toString()) ?? 0.0;
      });

      print("✅ Ride Created! Fare: $_fare, Distance: $_distance km, Duration: $_duration min");

    } else if (response.statusCode == 400) {
      // ✅ Show popup if the ride is rejected due to short distance
      if (data.containsKey("message") && data["message"] == "Ride request rejected. Distance must be at least 1 km.") {
        _showRideRejectedPopup(data["message"], data["distance"]);
      }
    } else {
      print("❌ Failed to create ride: ${response.body}");
    }

  } catch (e) {
    print("❌ Error creating ride: $e");
  }
}



void _showRideRejectedPopup(String message, String distance) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 28), // ✅ Replaces missing emoji
            SizedBox(width: 8),
            Text(
              "Ride Rejected",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, // ✅ Align text properly
          children: [
            Text(
              message,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            SizedBox(height: 8),
            Text(
              "Requested Distance: $distance",
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "OK",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
        ],
      );
    },
  );
}




Future<void> _fetchRideStatus(BuildContext context) async {
  if (_riderPublicKey == null) return;

  try {
    final url = Uri.parse("${backendUrl}ride-status?riderPublicKey=$_riderPublicKey");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String newStatus = data['status'];
      String newRideId = data['rideId'];

      setState(() {
        _rideStatus = data["status"];
              if (_rideStatus == "Accepted") {
        _driverLocation = LatLng(27.695558080429666, 85.2973644247388);
      } else {
        _driverLocation = null; // Hide driver location when not accepted
      }
        if (newRideId != _currentRideId) {
          _currentRideId = newRideId;
        }
        
        if (newStatus == "Completed" || newStatus == "Cancelled") {
          _currentRide = null;
        } else {
          _currentRide = data;
        }
                // Show popup when the ride status is 'Driver Reached'
        if (newStatus == "Driver Reached" && _previousRideStatus != "Driver Reached") {
          _showDriverReachedPopup(context); // Show popup
        }
        
      });
        
      print("✅ Ride status updated: $newStatus for Ride ID: $newRideId");

      // ✅ **Show popup if status changes to "Accepted"**
      if (newStatus == "Accepted" && _previousRideStatus != "Accepted") {
        if (mounted) {
          _showRideAcceptedPopup(context); // Call popup function
        }
      }

      // ✅ Show snackbar for ride completion/cancellation
      if ((_previousRideStatus != newStatus || _previousRideId != newRideId) && _currentRideId == newRideId) {
        _previousRideStatus = newStatus;
        _previousRideId = newRideId;

        if (newStatus == "Completed") {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("🎉 Ride $newRideId has been completed!"),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              )
            );
          }
        }

        if (newStatus == "Cancelled") {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red,
                content: Text("🚨 Ride $newRideId has been cancelled!"),
              )
            );
          }
        }
      }
    } else {
      print("❌ Error fetching ride status: ${response.body}");
    }
  } catch (e) {
    print("❌ Exception fetching ride status: $e");
  }
}

void _showRideAcceptedPopup(BuildContext context) { // ✅ Accept context
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Ride Accepted!"),
        content: const Text("A driver has accepted your ride request. Get ready!"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      );
    },
  );
}
Future<void> _logout() async {
  try {
    await clearLocalStorage(); // ✅ Clears stored public key and user type

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login'); // ✅ Redirect to login screen
    }

    print("✅ Successfully logged out.");
  } catch (e) {
    print("❌ Error during logout: $e");
  }
}

Future<void> _cancelRide() async {
  if (_currentRide == null) return;

  try {
    final url = Uri.parse("${backendUrl}cancel-ride");
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "rideId": _currentRide!["rideId"],
        "riderPublicKey": _riderPublicKey,
      }),
    );

    if (response.statusCode == 200) {
      print("✅ Ride cancelled successfully.");
      
      setState(() {
        _currentRide = null; // ✅ Reset ride data to remove 'Completed' status
      });
    } else {
      print("❌ Failed to cancel ride: ${response.body}");
    }
  } catch (e) {
    print("❌ Error canceling ride: $e");
  }
}

Future<void> _fetchRouteFromLatLng(LatLng destination) async {
  try {
    final routeUrl = Uri.parse(
        "https://router.project-osrm.org/route/v1/driving/${_currentLocation.longitude},${_currentLocation.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson");
    final routeResponse = await http.get(routeUrl);

    if (routeResponse.statusCode == 200) {
      final data = jsonDecode(routeResponse.body);
      final List coordinates = data['routes'][0]['geometry']['coordinates'];

      setState(() {
        _routeCoordinates = coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
        _destinationLocation = destination; // ✅ Update destination
      });

      // Reverse Geocode to get Address for UI update
      final reverseGeocodeUrl = Uri.parse(
          "https://nominatim.openstreetmap.org/reverse?lat=${destination.latitude}&lon=${destination.longitude}&format=json");
      final reverseResponse = await http.get(reverseGeocodeUrl);

      if (reverseResponse.statusCode == 200) {
        final reverseData = jsonDecode(reverseResponse.body);
        setState(() {
          _destinationController.text = reverseData['display_name'] ?? "Unknown location";
        });
      }
    }
  } catch (e) {
    print("Error fetching route: $e");
  }
}

void _refreshMap() async {
  setState(() {
    _routeCoordinates = [];  // Clear the route coordinates
    _destinationLocation = null;  // Clear the destination marker
    _pickupController.clear();  // Clear the pickup location
    _destinationController.clear();  // Clear the destination input
    _isDestinationFocused = false;  // Reset the flag to false when refreshing
  });

  // Reload the current location and reset any other data
  await _getCurrentLocation();  // Get the current location again
  print("Map refreshed!");
}


// Function to fetch the coordinates of a location and update the marker
Future<void> _updatePickupLocation(String query) async {
  if (query.isEmpty) {
    return;
  }

  try {
    final url = Uri.parse("https://nominatim.openstreetmap.org/search?q=$query,Kathmandu,Nepal&format=json&addressdetails=1&limit=1");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);

      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);
        
        // Update the location of the blue marker
        setState(() {
          _currentLocation = LatLng(lat, lon);
        });

        // Move the map to the new pickup location
        _mapController.move(_currentLocation, 14.0);
      }
    }
  } catch (e) {
    print("Error fetching location: $e");
  }
}
void _showDriverReachedPopup(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Driver Has Reached!"),
        content: const Text("The driver has arrived at your location. Please meet them."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      );
    },
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
  appBar: AppBar(
  title: Text("Rider Map", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
  centerTitle: true,
  backgroundColor: Colors.transparent,  // Makes the AppBar background transparent
  elevation: 0,  // Removes the shadow
  flexibleSpace: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.blueAccent.shade700, Colors.blue.shade600],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
/*  actions: [
    IconButton(
      icon: Icon(Icons.refresh),
      onPressed: _refreshMap, // ✅ Refresh map manually
    ),
    IconButton(
      icon: Icon(Icons.logout),
      onPressed: _logout, // ✅ Logout button
    ),
  ],*/
),


    body: Column(
      children: [
        if (_currentRide != null && _currentRide!["status"] != "Completed")
        Padding(
  padding: const EdgeInsets.all(8.0),
  child: Card(
    elevation: 8,  // Added shadow for a more prominent look
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),  // Rounded corners for the card
    ),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,  // Aligns the text to the start
        children: [
          Text(
            "🚖 Ride Status: ${_currentRide!["status"]}",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          SizedBox(height: 10),  // Increased space between status and next text
          Text(
            "Driver: ${_currentRide!["driver"] ?? "Waiting for driver..."}",
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          Text(
            "Ride ID: ${_currentRide!["rideId"]}",
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 20),  // Space before the button
          if (_currentRide!["status"] != "Cancelled" && _currentRide!["status"] != "Completed")
            ElevatedButton(
              onPressed: () async {
                await _cancelRide();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,  // Red button for cancel
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),  // Custom padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),  // Rounded corners for the button
                ),
                elevation: 5,  // Add shadow for the button
              ),
              child: Text(
                "Cancel Ride",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
        ],
      ),
    ),
  ),
),


      Padding(
  padding: const EdgeInsets.all(8.0),
  child: Column(
    children: [
      TextField(
        controller: _pickupController,
      
        onChanged: (query) {
          _searchSuggestions(query);
          _updatePickupLocation(query);  // Update location based on input
        },
        decoration: InputDecoration(
          labelText: "Pickup Location",
          labelStyle: TextStyle(color: Colors.blue.shade700),  // Text color for label
          prefixIcon: Icon(Icons.location_on, color: Colors.blue),  // Pickup icon
          filled: true,
          fillColor: Colors.blue.shade50,  // Light background color for text field
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),  // Rounded corners
            borderSide: BorderSide(color: Colors.blue.shade700, width: 1),  // Border color
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),  // Padding for a more spacious look
        ),
      ),
      
      
      const SizedBox(height: 12),  // Increased space between fields

      
      TextField(
        controller: _destinationController,
        onChanged: (query) => _searchSuggestions(query),
        onTap: () {
          setState(() {
            _isDestinationFocused = true; // Set flag to true when the text field is tapped
          });
        },
        decoration: InputDecoration(
          labelText: "Enter Destination",
          labelStyle: TextStyle(color: Colors.blue.shade700),  // Text color for label
          prefixIcon: Icon(Icons.place, color: Colors.red),  // Destination icon
          filled: true,
          fillColor: Colors.blue.shade50,  // Light background color for text field
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),  // Rounded corners
            borderSide: BorderSide(color: Colors.blue.shade700, width: 1),  // Border color
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),  // Padding for a more spacious look
        ),
      ),
    ],
  ),
),


       if (_fare != null && _distance != null && _duration != null)
  Padding(
    padding: const EdgeInsets.all(8.0),
    child: Card(
      elevation: 8,  // Increased elevation for more prominent shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),  // Rounded corners
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,  // Align text to the left
          children: [
            // Display Fare
            Text(
              "Fare: Rs ${_fare!.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,  // Green color for Fare
              ),
            ),
            SizedBox(height: 8),  // Increased space between fare and other fields

            // Display Distance
            Text(
              "Distance: ${_distance!.toStringAsFixed(2)} km",
              style: TextStyle(
                fontSize: 18,
                color: Colors.black87,  // Dark color for Distance
              ),
            ),
            SizedBox(height: 8),  // Increased space between distance and duration

            // Display Duration
            Text(
              "Duration: ${_duration!.toStringAsFixed(2)} min",
              style: TextStyle(
                fontSize: 18,
                color: Colors.blue.shade700,  // Blue color for Duration
              ),
            ),
          ],
        ),
      ),
    ),
  ),
// Show Pickup Suggestions when available
if (!_isDestinationFocused && _pickupSuggestions.isNotEmpty)
  Expanded(
    child: ListView.builder(
      itemCount: _pickupSuggestions.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(_pickupSuggestions[index]),
          onTap: () {
            _pickupController.text = _pickupSuggestions[index];
            setState(() {
              _pickupSuggestions = [];
            });
          },
        );
      },
    ),
  ),

// Show Destination Suggestions when available
if (_isDestinationFocused && _destinationSuggestions.isNotEmpty)
  Expanded(
    child: ListView.builder(
      itemCount: _destinationSuggestions.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(_destinationSuggestions[index]),
          onTap: () {
            _destinationController.text = _destinationSuggestions[index];
            setState(() {
              _destinationSuggestions = [];
            });
          },
        );
      },
    ),
  ),



        Expanded(
          flex: 2,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentLocation,
              zoom: 14.0,
              maxBounds: _kathmanduBounds,
              interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.pinchZoom, // Prevent extreme zooming
              onTap: (tapPosition, point) {
                if (_isDestinationFocused) {  // Only allow marker placement when destination is focused
                  setState(() {
                    _destinationLocation = point; // Move marker on tap
                  });
                  print("Marker moved to: $point");
                  _fetchRouteFromLatLng(point);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),
      MarkerLayer( // Updated: Correct placement inside MarkerLayer
        markers: [if (_rideStatus == "Accepted" && _driverLocation != null)
          Marker(
            point: _driverLocation!,
            builder: (ctx) => Icon(Icons.directions_car, color: Colors.green, size: 30),
          ),
          
          // 📌 Blue Pickup Marker
          Marker(
            point: _currentLocation,
            width: 50,
            height: 50,
            builder: (ctx) => const Icon(
              Icons.location_pin,
              color: Colors.blue,
              size: 40,
            ),
          ),
          // 📌
    // 📌 Draggable Destination (Red) Marker
          if (_destinationLocation != null) // Only add destination marker if set
            Marker(
              point: _destinationLocation!,
              width: 50,
              height: 50,
              builder: (ctx) => GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _destinationLocation = LatLng(
                      _destinationLocation!.latitude - details.localPosition.dy * 0.0001,
                      _destinationLocation!.longitude + details.localPosition.dx * 0.0001,
                    );
                  });
                },
                onPanEnd: (details) async {
                  await _fetchRouteFromLatLng(_destinationLocation!);
                },
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red, // Red marker color
                  size: 40,
                ),
              ),
            ),
  ],
),

              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routeCoordinates,
                    strokeWidth: 4.0,
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () async {
              await _createRide(
                _currentLocation,
                _destinationLocation!,
                DateTime.now(),
                DateTime.now().add(const Duration(minutes: 30)),
              );
            },
            child: const Text("Create Ride"),
          ),
        ),
      ],
    ),
     floatingActionButton: Column(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    FloatingActionButton(
      heroTag: "refresh",
      backgroundColor: Colors.green,
      child: Icon(Icons.refresh),
      onPressed: _refreshMap,
      tooltip: "Refresh Location",
    ),
    SizedBox(height: 10),
    FloatingActionButton(
      heroTag: "logout",
      backgroundColor: Colors.red,
      child: Icon(Icons.logout),
      onPressed: () {
        _logout(); // Log out user
      },
      tooltip: "Logout",
    ),
  ],
),

  );
}

Future<void> clearLocalStorage() async {
  // Add code to clear local storage
  print("Local storage cleared.");
}
}