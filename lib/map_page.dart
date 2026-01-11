import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

StreamSubscription<LocationData>? _locationSub;

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapControllerImpl();
  final Location _location = Location();
  final TextEditingController _locationController = TextEditingController();
  LatLng? _currentLocation;
  LatLng? _destination;
  bool isloading = true;
  List<List<LatLng>> _routes = [];
  List<double> _routeDistances = [];
  List<double> _routeDurations = [];
  List<LatLng> _locationHistory = [];
  int _selectedRouteIndex = 0;
  List<LatLng> _osmSignals = [];
  DateTime _lastRouteRequest = DateTime.now();

  @override
  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  LatLng _smoothLocation(LatLng newPoint) {
    _locationHistory.add(newPoint);

    if (_locationHistory.length > 5) {
      _locationHistory.removeAt(0); // keep only 5
    }

    double avgLat =
        _locationHistory.map((p) => p.latitude).reduce((a, b) => a + b) /
        _locationHistory.length;

    double avgLng =
        _locationHistory.map((p) => p.longitude).reduce((a, b) => a + b) /
        _locationHistory.length;

    return LatLng(avgLat, avgLng);
  }

  Future<bool> _initializeLocation() async {
    if (!await _checktheRequestPermissions()) return false;
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }

    final initialData = await _location.getLocation();
    if (initialData.latitude != null && initialData.longitude != null) {
      setState(() {
        _currentLocation = LatLng(
          initialData.latitude!,
          initialData.longitude!,
        );
        isloading = false;
      });
    }
    await fetchOverpassData();
    _locationSub = _location.onLocationChanged.listen((
      LocationData locationData,
    ) {
      if (!mounted) return; // 🔥 CRITICAL

      if (locationData.latitude != null && locationData.longitude != null) {
        LatLng rawPoint = LatLng(
          locationData.latitude!,
          locationData.longitude!,
        );

        LatLng smoothedPoint = _smoothLocation(rawPoint);

        setState(() {
          _currentLocation = smoothedPoint;
          isloading = false;
        });

        _mapController.move(smoothedPoint, 15.0);

        if (_destination != null) {
          final now = DateTime.now();
          if (now.difference(_lastRouteRequest).inSeconds > 10) {
            _lastRouteRequest = now;
            _fetchRoute();
          }
        }
      }
    });

    return true;
  }

  Future<void> fetchOverpassData() async {
    if (_currentLocation == null) {
      print("❌ Current location not available yet");
      return;
    }

    // Example: fetch all junctions around your current location (200m radius)
    final query =
        """
          [out:json];
          way["highway"](around:200,${_currentLocation!.latitude},${_currentLocation!.longitude});
          (._;>;);
          out;
        """;

    final url = Uri.parse("https://overpass-api.de/api/interpreter");

    try {
      final response = await http.post(url, body: {"data": query});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Map<int, int> nodeCount = {};
        Map<int, LatLng> nodeCoords = {};

        for (var element in data["elements"]) {
          if (element["type"] == "way") {
            for (var node in element["nodes"]) {
              nodeCount[node] = (nodeCount[node] ?? 0) + 1;
            }
          } else if (element["type"] == "node") {
            nodeCoords[element["id"]] = LatLng(element["lat"], element["lon"]);
          }
        }

        // pick junctions = nodes that belong to 2+ ways
        List<LatLng> junctionPoints = [];
        for (var entry in nodeCount.entries) {
          if (entry.value > 1 && nodeCoords.containsKey(entry.key)) {
            junctionPoints.add(nodeCoords[entry.key]!);
          }
        }
        if (!mounted) return;
        setState(() {
          _osmSignals = junctionPoints;
        });

        print("✅ Junctions found: ${junctionPoints.length}");
      } else {
        print("Error fetching OSM data");
      }
    } catch (e) {
      print("💥 Overpass fetch failed: $e");
    }
  }

  Future<void> fetchCoordinatesPoint(String location) async {
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search?q=$location&format=json&limit=1",
    );

    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'demo/1.0 (syed.mikraam@gmail.com)', // required
      },
    );
    //error handling
    //
    //
    print("Response Code: ${response.statusCode}");
    print("Response Body: ${response.body}");
    //
    //
    //
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);
        setState(() {
          _destination = LatLng(lat, lon);
        });
        await _fetchRoute();
      } else {
        errorMessage('Location not found.Please try another search');
      }
    } else {
      errorMessage('Failed to fetch location.Try again later.');
    }
  }

  Future<void> _fetchRoute() async {
    print("⚡ _fetchRoute CALLED");

    if (_currentLocation == null || _destination == null) {
      print(
        "❌ Missing start or destination → current=$_currentLocation dest=$_destination",
      );
      return;
    }

    final url =
        "https://router.project-osrm.org/route/v1/driving/${_currentLocation!.longitude},${_currentLocation!.latitude};${_destination!.longitude},${_destination!.latitude}?overview=full&geometries=geojson&alternatives=true";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          List<List<LatLng>> allRoutes = [];
          List<double> distances = [];
          List<double> durations = [];

          // Process each route
          for (var routeData in data['routes']) {
            final geometry = routeData['geometry']['coordinates'] as List;
            List<LatLng> routePoints = geometry
                .map((c) => LatLng(c[1], c[0]))
                .toList();
            allRoutes.add(routePoints);

            // Extract distance and duration for each route
            distances.add(routeData['distance'] / 1000); // Convert meters to km
            durations.add(
              routeData['duration'] / 60,
            ); // Convert seconds to minutes
          }

          setState(() {
            _routes = allRoutes;
            _routeDistances = distances;
            _routeDurations = durations;
          });
          if (allRoutes.isNotEmpty) {
            _fetchJunctionsAlongRoute(allRoutes[0]);
          }
          // Zoom to route
          if (_routes.isNotEmpty) {
            // Combine all route points to calculate bounds
            List<LatLng> allPoints = [];
            for (var route in _routes) {
              allPoints.addAll(route);
            }

            final bounds = LatLngBounds.fromPoints(allPoints);
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(50),
              ),
            );
          }
        } else {
          print("⚠️ No route found in OSRM response");
        }
      } else {
        print("❌ Failed to fetch route: ${response.statusCode}");
      }
    } catch (e) {
      print("💥 Error fetching route: $e");
    }
  }

  Future<void> _fetchJunctionsAlongRoute(List<LatLng> route) async {
    List<LatLng> junctions = [];

    for (int i = 0; i < route.length; i += 20) {
      // every ~20th point
      final lat = route[i].latitude;
      final lng = route[i].longitude;

      final query =
          """
    [out:json];
    way["highway"](around:50,$lat,$lng);
    (._;>;);
    out;
    """;

      final url = Uri.parse(
        'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        for (var element in data['elements']) {
          if (element['type'] == 'node') {
            junctions.add(LatLng(element['lat'], element['lon']));
          }
        }
      }
    }

    setState(() {
      _osmSignals = junctions; // keep them in a list
    });
  }

  Future<bool> _checktheRequestPermissions() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return false;
      }
    }

    return true;
  }

  Future<void> _userCurrentLocation() async {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Current Location is not available")),
      );
    }
  }

  void errorMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _highlightRoute(int index) {
    setState(() {
      _selectedRouteIndex = index;
    });

    // Zoom to the selected route
    final bounds = LatLngBounds.fromPoints(_routes[index]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  @override
  void dispose() {
    _locationSub?.cancel(); // 🔥 THIS FIXES THE CRASH
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SizedBox(height: MediaQuery.of(context).size.width * 0.1),
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(0, 0),
                    initialZoom: 2,
                    minZoom: 0,
                    maxZoom: 100,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      maxZoom: 19,
                    ),
                    if (_osmSignals.isNotEmpty && _destination != null)
                      MarkerLayer(
                        markers: _osmSignals.map((point) {
                          return Marker(
                            point: point,
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.circle, // 🚦 traffic light icon
                              color: Colors.red,
                              size: 8,
                            ),
                          );
                        }).toList(),
                      ),

                    if (_routes.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          for (int i = 0; i < _routes.length; i++)
                            Polyline(
                              points: _routes[i],
                              strokeWidth: i == _selectedRouteIndex ? 6.0 : 4.0,
                              color: [
                                Color(0xFF4D4DFF), // neon blue
                                Color(0xFF00E676), // neon green
                                Color(0xFFFF9100), // neon orange
                              ][i], // Different colors for each route
                            ),
                        ],
                      ),
                    CurrentLocationLayer(
                      style: LocationMarkerStyle(
                        marker: DefaultLocationMarker(),
                        markerSize: Size(20, 20),
                        markerDirection: MarkerDirection.heading,
                      ),
                    ),
                    if (_destination != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _destination!,
                            width: 50,
                            height: 50,
                            child: Icon(
                              Icons.location_pin,
                              size: 40,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  left: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        SizedBox(height: 150),
                        Expanded(
                          child: TextField(
                            controller: _locationController,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF0A0A0E),
                              hintText: 'Enter a location',
                              hintStyle: TextStyle(color: Color(0xFF4D4DFF)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF4D4DFF),
                            shape: BoxShape.circle,
                          ),
                          height: 50,
                          width: 50,
                          child: IconButton(
                            icon: Icon(Icons.search),
                            color: Colors.white,
                            onPressed: () {
                              final location = _locationController.text.trim();
                              if (location.isNotEmpty) {
                                fetchCoordinatesPoint(location);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _routes.isNotEmpty
                      ? Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121212),

                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Select Route",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              // Display route options with distance/duration
                              for (int i = 0; i < _routes.length; i++)
                                ListTile(
                                  leading: Icon(
                                    Icons.directions,
                                    color: [
                                      Colors.blue,
                                      Colors.green,
                                      Colors.orange,
                                    ][i],
                                  ),
                                  title: Text("Route ${i + 1}"),
                                  subtitle: Text(
                                    "${_routeDistances[i].toStringAsFixed(1)} km • ${_routeDurations[i].toStringAsFixed(0)} min",
                                  ),
                                  textColor: Colors.white,
                                  onTap: () {
                                    // Highlight selected route
                                    _highlightRoute(i);
                                  },
                                ),
                            ],
                          ),
                        )
                      : SizedBox.shrink(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        elevation: 0,
        onPressed: _userCurrentLocation,
        backgroundColor: const Color(0xFF4D4DFF),
        child: const Icon(Icons.my_location, size: 30, color: Colors.white),
      ),
    );
  }
}
