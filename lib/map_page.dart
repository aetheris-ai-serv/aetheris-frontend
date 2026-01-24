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
  bool _isRoutePanelOpen = false;
  bool _followUser = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  LatLng _smoothLocation(LatLng newPoint) {
    _locationHistory.add(newPoint);

    if (_locationHistory.length > 5) {
      _locationHistory.removeAt(0);
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
      if (!mounted) return;

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

        if (_followUser) {
          _mapController.move(smoothedPoint, _mapController.camera.zoom);
        }

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
      headers: {'User-Agent': 'demo/1.0 (syed.mikraam@gmail.com)'},
    );

    print("Response Code: ${response.statusCode}");
    print("Response Body: ${response.body}");

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
        errorMessage('Location not found. Please try another search');
      }
    } else {
      errorMessage('Failed to fetch location. Try again later.');
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

          for (var routeData in data['routes']) {
            final geometry = routeData['geometry']['coordinates'] as List;
            List<LatLng> routePoints = geometry
                .map((c) => LatLng(c[1], c[0]))
                .toList();
            allRoutes.add(routePoints);

            distances.add(routeData['distance'] / 1000);
            durations.add(routeData['duration'] / 60);
          }

          setState(() {
            _routes = allRoutes;
            _routeDistances = distances;
            _routeDurations = durations;
          });
          if (allRoutes.isNotEmpty) {
            _fetchJunctionsAlongRoute(allRoutes[0]);
          }

          if (_routes.isNotEmpty) {
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
      _osmSignals = junctions;
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

    final bounds = LatLngBounds.fromPoints(_routes[index]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  @override
  void dispose() {
    _locationSub?.cancel();
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
                // 🎨 3D PERSPECTIVE MAP
                Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // Perspective depth
                    ..rotateX(-0.3), // 3D tilt angle
                  alignment: Alignment.center,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLocation ?? LatLng(0, 0),
                      initialZoom: 15,
                      minZoom: 5,
                      maxZoom: 19,
                      initialRotation:
                          -15.0, // Slight rotation for dynamic view
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture && _followUser) {
                          setState(() {
                            _followUser = false;
                          });
                        }
                      },
                    ),
                    children: [
                      // 🌙 DARK THEME MAP
                      TileLayer(
                        urlTemplate:
                            'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                        subdomains: ['a', 'b', 'c', 'd'],
                        maxZoom: 19,
                        userAgentPackageName: 'com.example.app',
                      ),

                      // 🚦 Junction/Signal Markers
                      if (_osmSignals.isNotEmpty && _destination != null)
                        MarkerLayer(
                          markers: _osmSignals.map((point) {
                            return Marker(
                              point: point,
                              width: 40,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red.withOpacity(0.3),
                                  border: Border.all(
                                    color: Colors.red,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.traffic,
                                  color: Colors.red,
                                  size: 12,
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                      // 🛣️ ROUTE LINES
                      if (_routes.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            for (int i = 0; i < _routes.length; i++)
                              Polyline(
                                points: _routes[i],
                                strokeWidth: i == _selectedRouteIndex
                                    ? 7.0
                                    : 4.0,
                                color: i == _selectedRouteIndex
                                    ? Color(0xFF4D4DFF)
                                    : [
                                        Color(0xFF4D4DFF).withOpacity(0.5),
                                        Color.fromARGB(
                                          255,
                                          123,
                                          0,
                                          230,
                                        ).withOpacity(0.5),
                                        Color.fromARGB(
                                          255,
                                          255,
                                          0,
                                          212,
                                        ).withOpacity(0.5),
                                      ][i],
                                borderColor: Colors.black.withOpacity(0.5),
                                borderStrokeWidth: 1,
                              ),
                          ],
                        ),

                      // 📍 CURRENT LOCATION
                      CurrentLocationLayer(
                        style: LocationMarkerStyle(
                          marker: DefaultLocationMarker(
                            color: Color(0xFF4D4DFF),
                            child: Icon(
                              Icons.navigation,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          markerSize: Size(30, 30),
                          markerDirection: MarkerDirection.heading,
                          headingSectorColor: Color(
                            0xFF4D4DFF,
                          ).withOpacity(0.3),
                          headingSectorRadius: 60,
                        ),
                      ),

                      // 🎯 DESTINATION MARKER
                      if (_destination != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _destination!,
                              width: 60,
                              height: 60,
                              child: Column(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.5),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.location_pin,
                                      size: 30,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // 🔍 SEARCH BAR
                Positioned(
                  top: 50,
                  right: 10,
                  left: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _locationController,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF1a1a1e),
                              hintText: 'Search destination...',
                              hintStyle: TextStyle(
                                color: Color(0xFF4D4DFF).withOpacity(0.6),
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Color(0xFF4D4DFF),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide(
                                  color: Color(0xFF4D4DFF),
                                  width: 2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide(
                                  color: Color(0xFF4D4DFF).withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide(
                                  color: Color(0xFF4D4DFF),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                            ),
                            onSubmitted: (value) {
                              if (value.isNotEmpty) {
                                fetchCoordinatesPoint(value);
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF4D4DFF),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF4D4DFF).withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          height: 56,
                          width: 56,
                          child: IconButton(
                            icon: Icon(Icons.send),
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

                // 📊 ROUTE PANEL
                if (_routes.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      height: _isRoutePanelOpen ? 280 : 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF1a1a1e), Color(0xFF0A0A0E)],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(25),
                        ),
                        border: Border.all(
                          color: Color(0xFF4D4DFF).withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF4D4DFF).withOpacity(0.2),
                            blurRadius: 20,
                            offset: Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Handle
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isRoutePanelOpen = !_isRoutePanelOpen;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF4D4DFF),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Icon(
                                    _isRoutePanelOpen
                                        ? Icons.keyboard_arrow_down
                                        : Icons.keyboard_arrow_up,
                                    color: Color(0xFF4D4DFF),
                                    size: 28,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Routes list
                          if (_isRoutePanelOpen)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.alt_route,
                                          color: Color(0xFF4D4DFF),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "Choose Your Route",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: _routes.length,
                                        itemBuilder: (context, i) {
                                          bool isSelected =
                                              i == _selectedRouteIndex;
                                          return Container(
                                            margin: EdgeInsets.only(bottom: 8),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Color(
                                                      0xFF4D4DFF,
                                                    ).withOpacity(0.2)
                                                  : Color(0xFF1a1a1e),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSelected
                                                    ? Color(0xFF4D4DFF)
                                                    : Colors.transparent,
                                                width: 2,
                                              ),
                                            ),
                                            child: ListTile(
                                              leading: Container(
                                                padding: EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: [
                                                    Color(0xFF4D4DFF),
                                                    Color.fromARGB(
                                                      255,
                                                      123,
                                                      0,
                                                      230,
                                                    ),
                                                    Color.fromARGB(
                                                      255,
                                                      255,
                                                      0,
                                                      212,
                                                    ),
                                                  ][i],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.directions_car,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                              title: Text(
                                                "Route ${i + 1}",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              subtitle: Text(
                                                "${_routeDistances[i].toStringAsFixed(1)} km • "
                                                "${_routeDurations[i].toStringAsFixed(0)} min",
                                                style: TextStyle(
                                                  color: Color(0xFF4D4DFF),
                                                ),
                                              ),
                                              trailing: isSelected
                                                  ? Icon(
                                                      Icons.check_circle,
                                                      color: Color(0xFF4D4DFF),
                                                    )
                                                  : null,
                                              onTap: () {
                                                _followUser = false;
                                                _highlightRoute(i);
                                                _mapController.fitCamera(
                                                  CameraFit.bounds(
                                                    bounds:
                                                        LatLngBounds.fromPoints(
                                                          _routes[i],
                                                        ),
                                                    padding:
                                                        const EdgeInsets.all(
                                                          60,
                                                        ),
                                                  ),
                                                );
                                                setState(() {
                                                  _isRoutePanelOpen = false;
                                                });
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0xFF4D4DFF).withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ],
        ),
        child: FloatingActionButton(
          elevation: 0,
          onPressed: () {
            _followUser = true;
            _userCurrentLocation();
          },
          backgroundColor: const Color(0xFF4D4DFF),
          child: const Icon(Icons.my_location, size: 28, color: Colors.white),
        ),
      ),
    );
  }
}
