import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../config/api_config.dart';

class HazardMapScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? residentsToRescue;
  const HazardMapScreen({super.key, this.residentsToRescue});

  @override
  State<HazardMapScreen> createState() => _HazardMapScreenState();
}

class _HazardMapScreenState extends State<HazardMapScreen> {
  final MapController _mapController = MapController();
  final ImagePicker _picker = ImagePicker();
  LatLng? _userLocation;
  LatLng _mapCenter = const LatLng(14.5995, 120.9842);
  double _mapZoom = 15.0;
  List<Map<String, dynamic>> _userReports = [];
  bool _isLoading = false;

  final String _baseUrl = ApiConfig.baseUrl;

  final Map<String, IconData> _disasterIcons = {
    'Flooding': Icons.water,
    'Earthquake': Icons.terrain,
    'Fire': Icons.local_fire_department,
    'Typhoon': Icons.cyclone,
    'Landslide': Icons.hiking,
  };

  final Map<String, Color> _disasterColors = {
    'Flooding': Colors.blue,
    'Earthquake': Colors.orange,
    'Fire': Colors.red,
    'Typhoon': Colors.cyan,
    'Landslide': Colors.green,
  };

  bool _isReportsPanelOpen = false;
  bool _isLayersPanelOpen = false;
  bool _showBarangayBoundaries = true;
  List<Polygon> _barangayPolygons = [];

  final List<Map<String, dynamic>> _hazards = [
    {
      'pos': const LatLng(14.5995, 120.9842),
      'title': 'Manila Region',
      'desc': 'Critical Flooding potential in NCR.',
      'color': Colors.red,
      'level': 'Critical',
    },
    {
      'pos': const LatLng(10.3157, 123.8854),
      'title': 'Cebu City',
      'desc': 'Moderate Storm Surge warning.',
      'color': Colors.orange,
      'level': 'Moderate',
    },
    {
      'pos': const LatLng(7.0736, 125.6128),
      'title': 'Davao Region',
      'desc': 'Minor Seismic Activity recorded.',
      'color': Colors.blue,
      'level': 'Minor',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadMapState();
    _fetchReports();
    _determinePosition();
    _loadBarangayBoundaries();
  }

  Future<void> _loadBarangayBoundaries() async {
    // Mocking sample barangay data for Manila for demonstration
    // In a real app, this would fetch from a GeoJSON or API
    final List<Map<String, dynamic>> samples = [
      {
        'name': 'Barangay 649 (Baseco)',
        'points': [
          const LatLng(14.5930, 120.9600),
          const LatLng(14.5960, 120.9600),
          const LatLng(14.5960, 120.9650),
          const LatLng(14.5930, 120.9650),
        ],
        'risk': 0.9, // High risk
      },
      {
        'name': 'Barangay 20 (Parola)',
        'points': [
          const LatLng(14.6040, 120.9580),
          const LatLng(14.6080, 120.9580),
          const LatLng(14.6080, 120.9630),
          const LatLng(14.6040, 120.9630),
        ],
        'risk': 0.7, // Moderate risk
      },
      {
        'name': 'Barangay 128 (Smokey Mountain)',
        'points': [
          const LatLng(14.6280, 120.9610),
          const LatLng(14.6320, 120.9610),
          const LatLng(14.6320, 120.9660),
          const LatLng(14.6280, 120.9660),
        ],
        'risk': 0.8, // High risk
      },
      {
        'name': 'Intramuros',
        'points': [
          const LatLng(14.5880, 120.9730),
          const LatLng(14.5940, 120.9730),
          const LatLng(14.5940, 120.9780),
          const LatLng(14.5880, 120.9780),
        ],
        'risk': 0.2, // Low risk
      },
    ];

    setState(() {
      _barangayPolygons = samples.map((s) {
        final double risk = s['risk'] as double;
        final Color color = risk > 0.8 
          ? Colors.red 
          : risk > 0.5 
            ? Colors.orange 
            : Colors.green;
        
        return Polygon(
          points: s['points'] as List<LatLng>,
          color: color.withOpacity(0.3),
          borderColor: color,
          borderStrokeWidth: 2,
        );
      }).toList();
    });
  }

  Future<void> _loadMapState() async {
    final prefs = await SharedPreferences.getInstance();
    final lastLat = prefs.getDouble('last_lat');
    final lastLng = prefs.getDouble('last_lng');
    final lastZoom = prefs.getDouble('last_zoom');
    
    if (lastLat != null && lastLng != null && lastZoom != null) {
      setState(() {
        _mapCenter = LatLng(lastLat, lastLng);
        _mapZoom = lastZoom;
      });
      _mapController.move(_mapCenter, _mapZoom);
    }
  }

  Future<void> _saveMapState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_lat', _mapController.camera.center.latitude);
    await prefs.setDouble('last_lng', _mapController.camera.center.longitude);
    await prefs.setDouble('last_zoom', _mapController.camera.zoom);
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/reports'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _userReports = data.map((r) => {
            'id': r['id'],
            'pos': LatLng(r['latitude'], r['longitude']),
            'type': r['type'] ?? 'Unknown',
            'title': r['type'] ?? 'Report',
            'desc': r['description'] ?? 'No description provided.',
            'imageUrl': r['imageUrl'] != null ? '$_baseUrl${r['imageUrl']}' : null,
            'reporterName': r['reporterName'] ?? 'Anonymous',
            'userId': r['userId'],
            'upvotes': r['upvotes'] ?? 0,
            'downvotes': r['downvotes'] ?? 0,
            'isResolved': r['isResolved'] ?? false,
            'isFalseInfo': r['isFalseInfo'] ?? false,
            'level': 'User Report', // Critical for modal logic
            'color': Colors.red, // Default color for user reports
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching reports: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied.')));
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied.')));
      return;
    } 

    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(_userLocation!, 18);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Hazard Map'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _determinePosition,
            tooltip: 'Find My Location',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: _mapZoom,
              onTap: (tapPosition, point) => _showReportDisasterModal(point),
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) _saveMapState();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'RiskQPH/1.0 (ph.gov.riskqph.mobile; contact: admin@riskqph.ph)',
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () {},
                  ),
                ],
              ),
              if (_showBarangayBoundaries)
                PolygonLayer(
                  polygons: _barangayPolygons,
                ),
              CircleLayer(
                circles: [
                  ..._hazards.map((h) => CircleMarker(
                    point: h['pos'],
                    radius: 50000,
                    useRadiusInMeter: true,
                    color: (h['color'] as Color).withOpacity(0.3),
                    borderColor: h['color'],
                    borderStrokeWidth: 2,
                  )),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blueAccent,
                        size: 40,
                      ),
                    ),
                  ..._userReports.where((r) => r['isResolved'] == false).map((r) {
                    final color = _disasterColors[r['type']] ?? Colors.red;
                    return Marker(
                      point: r['pos'] as LatLng,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showHazardDetail({
                          ...r,
                          'title': r['title'] ?? r['type'] ?? 'Report',
                          'desc': r['desc'] ?? 'No description',
                          'color': color,
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
                            border: Border.all(color: color, width: 2),
                          ),
                          child: Center(
                            child: Icon(
                              _disasterIcons[r['type']] ?? Icons.report,
                              color: color,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  ..._hazards.map((h) => Marker(
                    point: h['pos'],
                    width: 80,
                    height: 80,
                    child: GestureDetector(
                      onTap: () => _showHazardDetail(h),
                      child: Column(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: h['color'],
                            size: 40,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                            ),
                            child: Text(
                              h['level'],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: h['color'],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
                  if (widget.residentsToRescue != null)
                    ...widget.residentsToRescue!.where((r) => r['latitude'] != null && r['longitude'] != null).map((r) {
                      final name = '${r['firstName'] ?? ""} ${r['lastName'] ?? ""}'.trim();
                      final isSafe = r['isSafe'] == true;
                      String timeStr = 'N/A';
                      try {
                        if (r['updatedAt'] != null) {
                          final dt = DateTime.parse(r['updatedAt']);
                          timeStr = DateFormat('HH:mm:ss').format(dt);
                        }
                      } catch (_) {}
                      
                      final color = isSafe ? Colors.green : (r['hasResponded'] == true ? Colors.red : Colors.redAccent);

                      return Marker(
                        point: LatLng(r['latitude'], r['longitude']),
                        width: 80,
                        height: 90,
                        child: GestureDetector(
                          onTap: () => isSafe ? _showResidentSafeDetail(r, name, timeStr) : _showResidentRescueDetail(r, name, timeStr),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isSafe ? Colors.green : (r['hasResponded'] == true ? Colors.red : Colors.white), 
                                  shape: BoxShape.circle, 
                                  border: Border.all(color: color, width: 2), 
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 10, 
                                      color: color.withOpacity(0.5),
                                      spreadRadius: (r['hasResponded'] == true || isSafe) ? 2 : 0,
                                    )
                                  ]
                                ),
                                child: Icon(
                                  isSafe ? Icons.check : (r['hasResponded'] == true ? Icons.sos : Icons.warning), 
                                  color: (isSafe || r['hasResponded'] == true) ? Colors.white : Colors.red, 
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(color: color.withOpacity(0.9), borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                  isSafe ? 'SAFE: $name' : (r['hasResponded'] == true ? 'SOS: $name' : (name.isEmpty ? 'SOS' : name)), 
                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis
                                ),
                              ),
                              Text(timeStr, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold, backgroundColor: Colors.white70)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ],
          ),
          
          // Floating Recent Reports Panel
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  onPressed: () => setState(() => _isReportsPanelOpen = !_isReportsPanelOpen),
                  backgroundColor: _isReportsPanelOpen ? Colors.red : AppTheme.primaryColor,
                  child: Icon(_isReportsPanelOpen ? Icons.close : Icons.history),
                ),
                if (_isReportsPanelOpen)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
                    ),
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: AppTheme.primaryColor,
                          width: double.infinity,
                          child: const Text(
                            'Recent Reports',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        if (_userReports.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No reports yet', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          )
                        else
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _userReports.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final r = _userReports[index];
                                final color = _disasterColors[r['type']] ?? Colors.grey;
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    _disasterIcons[r['type']] ?? Icons.report,
                                    color: color,
                                    size: 18,
                                  ),
                                  title: Text(
                                    r['type'],
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    r['desc'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  onTap: () {
                                    // Preserve current zoom, but ensure it's at least 15
                                    final currentZoom = _mapController.camera.zoom;
                                    _mapController.move(r['pos'], currentZoom < 15 ? 15 : currentZoom);
                                    setState(() => _isReportsPanelOpen = false);
                                    _showHazardDetail({
                                      ...r,
                                      'title': r['title'] ?? r['type'] ?? 'Report',
                                      'desc': r['desc'] ?? 'No description',
                                      'color': color,
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Floating Layers Panel
          Positioned(
            top: 16,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FloatingActionButton.small(
                  onPressed: () => setState(() => _isLayersPanelOpen = !_isLayersPanelOpen),
                  backgroundColor: _isLayersPanelOpen ? Colors.grey[800] : Colors.white,
                  child: Icon(
                    _isLayersPanelOpen ? Icons.close : Icons.layers,
                    color: _isLayersPanelOpen ? Colors.white : AppTheme.primaryColor,
                  ),
                ),
                if (_isLayersPanelOpen)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 220,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          width: double.infinity,
                          child: const Text(
                            'Map Layers',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        SwitchListTile(
                          dense: true,
                          title: const Text('Barangay Boundaries', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          subtitle: const Text('Risk vicinity color coding', style: TextStyle(fontSize: 10)),
                          value: _showBarangayBoundaries,
                          activeColor: AppTheme.primaryColor,
                          onChanged: (val) => setState(() => _showBarangayBoundaries = val),
                        ),
                        // You can add more layers here e.g. Traffic, Shelters etc
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'map_report_add',
        onPressed: _determinePosition,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  void _showResidentSafeDetail(Map<String, dynamic> resident, String name, String timeStr) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
              const SizedBox(height: 16),
              Text('CONFIRMED SAFE', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(leading: const Icon(Icons.access_time), title: const Text('Marked Safe At'), subtitle: Text(timeStr)),
              ListTile(leading: const Icon(Icons.location_on), title: const Text('Coordinates'), subtitle: Text('${resident['latitude']}, ${resident['longitude']}')),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text('CLOSE')),
            ],
          ),
        );
      },
    );
  }

  void _showResidentRescueDetail(Map<String, dynamic> resident, String name, String timeStr) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('RESCUE REQUEST', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(leading: const Icon(Icons.access_time), title: const Text('Last GPS Available'), subtitle: Text(timeStr)),
              ListTile(leading: const Icon(Icons.location_on), title: const Text('Coordinates'), subtitle: Text('${resident['latitude']}, ${resident['longitude']}')),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('DISMISS')),
            ],
          ),
        );
      },
    );
  }

  void _showHazardDetail(Map<String, dynamic> hazard) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final bool isUserReport = hazard['level'] == 'User Report';
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final String? currentUserId = authProvider.currentUser?.id;
        final String? reportUserId = hazard['userId']?.toString();
        
        final bool isOwnReport = reportUserId != null && reportUserId == currentUserId;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hazard['title'],
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          if (isUserReport)
                            Text(
                              'Reported by ${hazard['reporterName']}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (hazard['isResolved'] == true 
                            ? Colors.green 
                            : (hazard['color'] as Color)).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: hazard['isResolved'] == true ? Colors.green : hazard['color']),
                        ),
                        child: Text(
                          hazard['isResolved'] == true ? 'RESOLVED' : hazard['level'],
                          style: TextStyle(
                            color: hazard['isResolved'] == true ? Colors.green : hazard['color'],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (hazard['imageUrl'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          hazard['imageUrl'],
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 100,
                            color: Colors.grey[200],
                            child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                          ),
                        ),
                      ),
                    ),
                  Text(
                    hazard['desc'],
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  if (isUserReport) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IgnorePointer(
                          ignoring: isOwnReport,
                          child: ActionChip(
                            avatar: const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                            label: Text('Agree (${hazard['upvotes']})'),
                            backgroundColor: Colors.green.withOpacity(0.05),
                            onPressed: () => _handleReportAction(hazard['id'], 'upvote'),
                          ),
                        ),
                        const Spacer(),
                        IgnorePointer(
                          ignoring: isOwnReport,
                          child: TextButton.icon(
                            onPressed: () => _handleReportAction(hazard['id'], 'flag'),
                            icon: const Icon(Icons.flag_outlined, size: 16, color: Colors.orange),
                            label: const Text('Flag', style: TextStyle(color: Colors.orange, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (hazard['isResolved'] != true)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _handleReportAction(hazard['id'], 'resolve'),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Mark as Resolved'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVoteChip({required IconData icon, required String label, required Color color, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({required IconData icon, required String label, required VoidCallback onPressed}) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: Colors.grey[600]),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: onPressed,
      backgroundColor: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Future<void> _handleReportAction(String id, String action) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/reports/$id'),
        body: json.encode({'action': action}),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        Navigator.pop(context); // Close current detail modal
        _fetchReports(); // Refresh data
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report ${action}d successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error action: $e');
    }
  }

  void _showReportDisasterModal(LatLng point) {
    String? selectedType;
    final TextEditingController descController = TextEditingController();
    XFile? pickedImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Report Disaster',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Text(
                    'Coordinates: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Disaster Type',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _disasterIcons.keys
                        .map((String value) => DropdownMenuItem(
                              value: value,
                              child: Row(
                                children: [
                                  Icon(_disasterIcons[value], size: 18, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text(value),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (val) => selectedType = val,
                    hint: const Text('Select disaster type'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Describe the situation...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Evidence (Phote)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if (pickedImage != null)
                    Stack(
                      children: [
                        Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: FileImage(File(pickedImage!.path)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: GestureDetector(
                            onTap: () => setModalState(() => pickedImage = null),
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              radius: 12,
                              child: Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    InkWell(
                      onTap: () async {
                        final image = await _picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          setModalState(() => pickedImage = image);
                        }
                      },
                      child: Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, color: Colors.grey[600]),
                            const SizedBox(height: 4),
                            Text('Attach Picture', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (selectedType == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a disaster type')),
                          );
                          return;
                        }
                        _submitReport(point, selectedType!, descController.text, pickedImage);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Submit Emergency Report', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitReport(LatLng point, String type, String desc, XFile? image) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final String? userId = authProvider.currentUser?.id;

      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/reports'));
      
      request.fields['type'] = type;
      request.fields['description'] = desc;
      request.fields['latitude'] = point.latitude.toString();
      request.fields['longitude'] = point.longitude.toString();
      if (userId != null) {
        request.fields['userId'] = userId;
      }
      
      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          image.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context); // Close modal
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report published to all users!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _fetchReports(); // Refresh markers
      } else {
        throw Exception('Failed to submit report');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
