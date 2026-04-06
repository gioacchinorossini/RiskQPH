import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
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
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../config/api_config.dart';
import '../../widgets/member_status_icon.dart';

class HazardMapScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? residentsToRescue;
  final LatLng? initialFocus;
  const HazardMapScreen({super.key, this.residentsToRescue, this.initialFocus});

  @override
  State<HazardMapScreen> createState() => _HazardMapScreenState();
}

class _HazardMapScreenState extends State<HazardMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final AnimationController _residentMarkerBobController;
  final ImagePicker _picker = ImagePicker();
  LatLng? _userLocation;
  LatLng _mapCenter = const LatLng(14.5995, 120.9842);
  double _mapZoom = 15.0;
  List<Map<String, dynamic>> _userReports = [];
  List<Map<String, dynamic>> _filteredResidents = [];
  Set<String> _familyUserIds = {};
  List<Map<String, dynamic>> _familyMembersList = [];
  bool _isFamilyPanelOpen = false;
  bool _isEmergencyPanelOpen = false;
  bool _isLoading = false;
  LatLng? _hqLocation;
  Map<String, dynamic>? _activeDisaster;
  List<dynamic> _evacuationCenters = [];

  final String _baseUrl = ApiConfig.baseUrl;

  final Map<String, IconData> _disasterIcons = {
    'Flooding': Icons.water,
    'Fire': Icons.local_fire_department,
    'Collapsed buildings': Icons.home_work,
    'Landslide / soil erosion': Icons.landscape,
    'Volcanic activity': Icons.volcano,
    'Power outage': Icons.power_off,
    'Water supply disruption': Icons.water_damage,
    'Signal failure (cell network down)': Icons.cell_tower,
    'Road blockage / impassable routes': Icons.traffic,
    'Other (custom entry)': Icons.more_horiz,
  };

  final Map<String, Color> _disasterColors = {
    'Flooding': Colors.blue,
    'Fire': Colors.red,
    'Collapsed buildings': Colors.brown,
    'Landslide / soil erosion': Colors.orange,
    'Volcanic activity': Colors.deepOrange,
    'Power outage': Colors.amber,
    'Water supply disruption': Colors.lightBlue,
    'Signal failure (cell network down)': Colors.grey,
    'Road blockage / impassable routes': Colors.deepPurple,
    'Other (custom entry)': Colors.blueGrey,
  };

  bool _isActionGroupExpanded = false;
  bool _isReportsPanelOpen = false;
  bool _isLayersPanelOpen = false;
  bool _isReportMode = false;
  bool _showBarangayBoundaries = true;
  bool _showIncidentReports = true;
  bool _showResidents = true;
  bool _showBarangayHall = true;
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

  http.Client? _sseClient;
  bool _isMeSafeLocally = false;

  @override
  void initState() {
    super.initState();
    _residentMarkerBobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _fetchReports();
    _loadBarangayBoundaries();
    _fetchHqLocation();

    if (widget.initialFocus != null) {
      _mapCenter = widget.initialFocus!;
      _mapZoom = 18.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(widget.initialFocus!, 18.0);
        }
      });
    } else {
      _loadMapState().then((_) {
        if (widget.initialFocus == null) {
          _determinePosition();
        }
      });
    }

    // Fetch residents and family if needed
    _checkDisasterStatus().then((_) {
      _fetchFamilyAndResidents();
      _startResidentsStream();
    });
    _fetchEvacuationCenters();
  }

  @override
  void dispose() {
    _residentMarkerBobController.dispose();
    _sseClient?.close();
    super.dispose();
  }

  /// Subtle motion so people pins read as “live”; phase varies per [motionKey].
  Widget _bobbingResidentMarkerChild({
    required String motionKey,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: _residentMarkerBobController,
      builder: (context, w) {
        final seed = motionKey.hashCode & 0xffff;
        final phase = seed / 0xffff * math.pi * 2;
        final t = _residentMarkerBobController.value;
        final dy = 3.2 * math.sin(t * math.pi * 2 + phase);
        final dx = 1.4 * math.cos(t * math.pi * 2 * 0.9 + phase * 0.7);
        return Transform.translate(offset: Offset(dx, dy), child: w);
      },
      child: child,
    );
  }

  void _showEvacuationCenterInfo(Map<String, dynamic> ec) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ec['name'].toString().toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text('TYPE: EVACUATION CENTER', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CURRENT OCCUPANCY:'),
                Text('${ec['_count']?['evacuees'] ?? 0} / ${ec['capacity'] ?? "∞"}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('DISMISS'),
            ),
          ],
        ),
      ),
    );
  }

  void _startResidentsStream() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null || user.barangay == null) return;

    _sseClient?.close();
    _sseClient = http.Client();

    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/api/barangay/residents/events?barangay=${user.barangay}',
      );
      final request = http.Request('GET', url);
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      request.headers['ngrok-skip-browser-warning'] = 'true';

      final response = await _sseClient!.send(request);

      response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line.startsWith('data: ')) {
                try {
                  final residentData = jsonDecode(line.substring(6));
                  if (mounted) {
                    setState(() {
                      // Update specific resident in the filtered list
                      bool found = false;
                      for (int i = 0; i < _filteredResidents.length; i++) {
                        if (_filteredResidents[i]['id'].toString() ==
                            residentData['id'].toString()) {
                          _filteredResidents[i] = Map<String, dynamic>.from(
                            residentData,
                          );
                          found = true;
                          break;
                        }
                      }

                      // If not found in filtered (e.g. resident was filtered out but now is needed)
                      if (!found) {
                        final String rRole =
                            residentData['role']?.toString().toLowerCase() ??
                            '';
                        final String rId = residentData['id'].toString();
                        if ((user.role != UserRole.resident ||
                            rRole.contains('responder') ||
                            _familyUserIds.contains(rId)) &&
                            (residentData['barangayMemberStatus'] == 'verified' || residentData['barangayMemberStatus'] == null)) {
                          _filteredResidents.add(
                            Map<String, dynamic>.from(residentData),
                          );
                        }
                      }
                    });
                  }
                } catch (e) {
                  debugPrint('Error parsing resident SSE: $e');
                }
              }
            },
            onError: (e) {
              debugPrint('Stream error: $e');
              Future.delayed(const Duration(seconds: 5), () {
                if (mounted) _startResidentsStream();
              });
            },
            onDone: () {
              debugPrint('Stream closed');
              Future.delayed(const Duration(seconds: 5), () {
                if (mounted) _startResidentsStream();
              });
            },
          );
    } catch (e) {
      debugPrint('SSE Error: $e');
    }
  }

  Future<void> _checkDisasterStatus() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null || user.barangay == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/disaster?barangay=${user.barangay}',
        ),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _activeDisaster = data['disaster'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking disaster for map: $e');
    }
  }

  Future<void> _fetchFamilyAndResidents() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null || user.barangay == null) return;

    try {
      // 1. Fetch family members if user is a resident
      if (user.role == UserRole.resident) {
        final familyResp = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/family?headId=${user.id}'),
          headers: {'ngrok-skip-browser-warning': 'true'},
        );
        if (familyResp.statusCode == 200) {
          final data = jsonDecode(familyResp.body);
          final List<dynamic> members = data['members'] ?? [];
          setState(() {
            _familyMembersList = members.cast<Map<String, dynamic>>();
            _familyUserIds = members
                .where((m) => m['userId'] != null)
                .map((m) => m['userId'].toString())
                .toSet();
          });
        }
      }

      // 2. Fetch residents for the map
      final resResp = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/barangay/residents?barangay=${user.barangay}${_activeDisaster != null ? '&disasterId=${_activeDisaster!['id']}' : ''}',
        ),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (resResp.statusCode == 200) {
        final data = jsonDecode(resResp.body);
        final List<dynamic> all = data['residents'] ?? [];

        setState(() {
          if (user.role == UserRole.resident) {
            // Filter: Only responders, family members, AND the current user
            _filteredResidents = all
                .where((r) {
                  final String rId = r['id'].toString();
                  final String rRole = r['role'].toString().toLowerCase();
                  return rRole.contains('responder') ||
                      _familyUserIds.contains(rId) ||
                      rId == user.id.toString();
                })
                .map((r) => Map<String, dynamic>.from(r))
                .toList();
          } else {
            // Officials see everyone verified
            _filteredResidents = all
                .where((r) => r['barangayMemberStatus'] == 'verified' || r['barangayMemberStatus'] == null)
                .map((r) => Map<String, dynamic>.from(r))
                .toList();
          }

          // CENTRAL SYNC: Always update the instant-access local flag based on fresh data
          final me = _filteredResidents
              .where((r) => r['id'].toString() == user.id.toString())
              .firstOrNull;
          if (me != null && me['isSafe'] == true) {
            _isMeSafeLocally = true;
          } else {
            _isMeSafeLocally = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching family/residents: $e');
    }
  }

  Future<void> _fetchHqLocation() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null || user.barangay == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/barangay/location?name=${user.barangay}',
        ),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['profile'] != null && mounted) {
          final lat = data['profile']['hqLatitude'];
          final lng = data['profile']['hqLongitude'];
          if (lat != null && lng != null) {
            setState(() {
              _hqLocation = LatLng(lat as double, lng as double);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching HQ location: $e');
    }
  }

  String _getRelationshipForResident(String? userId) {
    if (userId == null) return 'Resident';
    final fam = _familyMembersList.where((m) => m['userId']?.toString() == userId).firstOrNull;
    return fam?['relationship'] ?? 'Resident';
  }

  Future<void> _fetchEvacuationCenters() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null || user.barangay == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/evacuation-center?barangay=${user.barangay}'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _evacuationCenters = data['centers'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching ECs for map: $e');
    }
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

  Future<void> _refreshMapData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      await Future.wait([
        _checkDisasterStatus(),
        _fetchReports(),
        _fetchFamilyAndResidents(),
        _fetchHqLocation(),
        _fetchEvacuationCenters(),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Map data refreshed'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error refreshing map: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchReports({bool setLoad = true}) async {
    if (setLoad && mounted) setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/reports'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _userReports = data
              .map(
                (r) => {
                  'id': r['id'],
                  'pos': LatLng(r['latitude'], r['longitude']),
                  'type': r['type'] ?? 'Unknown',
                  'title': r['type'] ?? 'Report',
                  'desc': r['description'] ?? 'No description provided.',
                  'imageUrl': r['imageUrl'] != null
                      ? '$_baseUrl${r['imageUrl']}'
                      : null,
                  'reporterName': r['reporterName'] ?? 'Anonymous',
                  'userId': r['userId'],
                  'upvotes': r['upvotes'] ?? 0,
                  'downvotes': r['downvotes'] ?? 0,
                  'isResolved': r['isResolved'] ?? false,
                  'isFalseInfo': r['isFalseInfo'] ?? false,
                  'level': 'User Report', // Critical for modal logic
                  'color': Colors.red, // Default color for user reports
                },
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching reports: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsSafe() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null || _activeDisaster == null) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/safety'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'userId': user.id,
          'disasterId': _activeDisaster!['id'],
          'isSafe': true,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _isMeSafeLocally = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status updated: You are SAFE!')),
          );
        }
        // Locally update user in _filteredResidents if present
        if (mounted) {
          setState(() {
            for (int i = 0; i < _filteredResidents.length; i++) {
              if (_filteredResidents[i]['id'].toString() ==
                  user.id.toString()) {
                _filteredResidents[i]['isSafe'] = true;
                break;
              }
            }
          });
        }
      } else {
        throw Exception('Check-in failed.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied.'),
          ),
        );
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

  Future<void> _updateLocationToFamily() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      Position position = await Geolocator.getCurrentPosition();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/profile'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'id': user.id,
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location updated for family!')),
          );
        }
      } else {
        throw Exception('Failed to update.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Set<String> ecIdsLinkedToFamily = _evacuationCenterIdsLinkedToFamily();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Hazard Map'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMapData,
            tooltip: 'Refresh Data',
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
              onTap: (tapPosition, point) {
                if (_isReportMode) {
                  _showReportDisasterModal(point);
                }
              },
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) _saveMapState();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'RiskQPH/1.0 (ph.gov.riskqph.mobile; contact: admin@riskqph.ph)',
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
                PolygonLayer(polygons: _barangayPolygons),
              CircleLayer(
                circles: [
                  ..._hazards.map(
                    (h) => CircleMarker(
                      point: h['pos'],
                      radius: 50000,
                      useRadiusInMeter: true,
                      color: (h['color'] as Color).withOpacity(0.3),
                      borderColor: h['color'],
                      borderStrokeWidth: 2,
                    ),
                  ),
                ],
              ),
              PolylineLayer(polylines: _familyEvacuationPolylines()),
              MarkerLayer(
                markers: [
                  // Evacuation Center Markers
                  ..._evacuationCenters.map((ec) {
                    IconData ecIcon = Icons.account_balance;
                    switch (ec['type']) {
                      case 'Building': ecIcon = Icons.domain; break;
                      case 'Home': ecIcon = Icons.home; break;
                      case 'Medical': ecIcon = Icons.monitor_heart; break;
                      case 'School': ecIcon = Icons.school; break;
                      case 'Church': ecIcon = Icons.church; break;
                      case 'Activity': ecIcon = Icons.query_stats; break;
                      default: ecIcon = Icons.account_balance;
                    }

                    final bool ecLinked =
                        ecIdsLinkedToFamily.contains(ec['id'].toString());

                    return Marker(
                      point: LatLng(ec['latitude'], ec['longitude']),
                      width: 80,
                      height: 80,
                      child: GestureDetector(
                        onTap: () {
                           _showEvacuationCenterInfo(ec);
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ecLinked
                                      ? Colors.teal
                                      : Colors.grey.shade400,
                                  width: ecLinked ? 4 : 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: ecLinked ? 14 : 8,
                                    color: ecLinked
                                        ? Colors.teal.withOpacity(0.45)
                                        : Colors.black.withOpacity(0.1),
                                  ),
                                ],
                              ),
                              child: Icon(
                                ecIcon,
                                color: ecLinked
                                    ? Colors.teal.shade700
                                    : Colors.grey.shade700,
                                size: ecLinked ? 26 : 24,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ec['name'].toString().toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (_hqLocation != null && _showBarangayHall)
                    Marker(
                      point: _hqLocation!,
                      width: 80,
                      height: 80,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 10,
                                  color: Colors.black26,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.account_balance,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'BARANGAY HALL',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_showIncidentReports)
                    ..._userReports.where((r) => r['isResolved'] == false).map((
                      r,
                    ) {
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
                          child: Opacity(
                            opacity: 0.6,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 4,
                                    color: Colors.black26,
                                  ),
                                ],
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
                        ),
                      );
                    }).toList(),
                  ..._hazards
                      .map(
                        (h) => Marker(
                          point: h['pos'],
                          width: 80,
                          height: 80,
                          child: GestureDetector(
                            onTap: () => _showHazardDetail(h),
                            child: Opacity(
                              opacity: 0.6,
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: h['color'],
                                    size: 40,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: const [
                                        BoxShadow(
                                          blurRadius: 4,
                                          color: Colors.black26,
                                        ),
                                      ],
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
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 120,
                      height: 80,
                      child: Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          final user = auth.currentUser;
                          final bool isSafe = _isMeSafeLocally || _filteredResidents.any(
                            (r) =>
                                r['id'].toString() == user?.id.toString() &&
                                r['isSafe'] == true,
                          );
                          final bool isEmergencyActive =
                              _activeDisaster != null;
                          final String name = (user?.firstName ?? 'You')
                              .toUpperCase();



                          return _bobbingResidentMarkerChild(
                            motionKey:
                                user?.id?.toString() ?? 'current_user_marker',
                            child: Column(
                              children: [
                                MemberStatusBubble(
                                  isSafe: isSafe,
                                  isEmergencyActive: isEmergencyActive,
                                  isOnline: true,
                                  label: isEmergencyActive ? null : name,
                                  fallbackColor: AppTheme.primaryColor,
                                ),
                                const SizedBox(height: 4),
                                MemberMarker(
                                  relationship: 'You',
                                  isSafe: isSafe,
                                  isEmergencyActive: isEmergencyActive,
                                  isOnline: true,
                                  size: 24,
                                  activeColor: AppTheme.primaryColor,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (_showResidents)
                    ...(() {
                      final auth = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );
                      final String? uid = auth.currentUser?.id.toString();
                      final Map<String, int> localCollisionMap = {};
                      return (widget.residentsToRescue ?? _filteredResidents)
                          .where((r) {
                            if (r['latitude'] == null || r['longitude'] == null) return false;
                            
                            final String rRole = r['role']?.toString().toLowerCase() ?? '';
                            final bool rIsResponder = rRole.contains('responder');
                            final bool rIsSafe = (r['isSafe'] == true);
                            
                            // If current user is a responder
                            if (auth.currentUser?.role == UserRole.responder) {
                              // 1. Responders always see other responders.
                              if (rIsResponder) return true;
                              
                              // 2. If disaster mode is OFF, responders SHOULD NOT see residents (except family).
                              final bool isFamilyMember = r['id'] != null && _familyUserIds.contains(r['id'].toString());
                              if (_activeDisaster == null && !isFamilyMember) return false;
                              
                              // 3. During disaster, responders ONLY see unsafe/"SOS" residents (unless family).
                              if (_activeDisaster != null && rIsSafe && !isFamilyMember) return false;
                            }
                            
                            return true;
                          })
                          .where(
                            (r) =>
                                uid == null ||
                                r['id'].toString() != uid ||
                                _userLocation == null,
                          )
                          .map((r) {
                            final name =
                                '${r['firstName'] ?? ""} ${r['lastName'] ?? ""}'
                                    .trim()
                                    .toUpperCase();
                            final bool disasterOn = _activeDisaster != null;
                            String timeStr = 'N/A';
                            try {
                              if (r['updatedAt'] != null) {
                                final dt = DateTime.parse(
                                  r['updatedAt'],
                                ).toLocal();
                                timeStr = DateFormat('HH:mm').format(dt);
                              }
                            } catch (_) {}

                            final double lat = (r['latitude'] as num)
                                .toDouble();
                            final double lng = (r['longitude'] as num)
                                .toDouble();
                            final String posKey =
                                '${lat.toStringAsFixed(6)}_${lng.toStringAsFixed(6)}';

                            final int collisionIdx =
                                localCollisionMap[posKey] ?? 0;
                            localCollisionMap[posKey] = collisionIdx + 1;

                            final bool isEmergencyActive = disasterOn;
                            final bool isSafeNow = (r['isSafe'] == true);
                            final bool hasSOS = (r['hasResponded'] == true);

                            final bool isFamily =
                                r['id'] != null &&
                                _familyUserIds.contains(r['id'].toString());

                            final String relationship = _getRelationshipForResident(r['id']?.toString());

                            final String rRole = r['role']?.toString().toLowerCase() ?? '';
                            final bool rIsResponder = rRole.contains('responder');

                            final Color markerColor = MemberStatusIcon.getStatusColor(
                                isSafe: isSafeNow,
                                hasSOS: hasSOS,
                                isEmergencyActive: isEmergencyActive,
                                isOnline: true,
                                isResponder: rIsResponder,
                                fallbackColor: AppTheme.primaryColor,
                            );


                            final double jitter = collisionIdx * 0.000018;
                            final LatLng finalPos = LatLng(
                              lat + jitter,
                              lng + jitter,
                            );

                            final String? ecRegId =
                                r['evacuationCenterId']?.toString();
                            final bool famEvacLinked =
                                isFamily &&
                                ecRegId != null &&
                                ecRegId.isNotEmpty;

                            final String motionKey =
                                r['id']?.toString() ?? posKey;

                            return Marker(
                              point: finalPos,
                              width: 100,
                              height: 100,
                              child: _bobbingResidentMarkerChild(
                                motionKey: motionKey,
                                child: GestureDetector(
                                  onTap: () {
                                    if (isFamily) {
                                      _showFamilyMemberBottomSheet(
                                        {
                                          'firstName': r['firstName'],
                                          'lastName': r['lastName'],
                                          'relationship': relationship,
                                        },
                                        Map<String, dynamic>.from(r),
                                      );
                                    } else if (isSafeNow) {
                                      _showResidentSafeDetail(
                                        r,
                                        name,
                                        timeStr,
                                      );
                                    } else {
                                      _showResidentRescueDetail(
                                        r,
                                        name,
                                        timeStr,
                                      );
                                    }
                                  },
                                  child: Column(
                                    children: [
                                      MemberStatusBubble(
                                        isSafe: isSafeNow,
                                        hasSOS: hasSOS,
                                        isEmergencyActive: isEmergencyActive,
                                        isOnline: true,
                                        isResponder: rIsResponder,
                                        label: isEmergencyActive ? (rIsResponder ? 'RESPONDER' : null) : 'ONLINE',
                                        fallbackColor: markerColor,
                                      ),
                                      const SizedBox(height: 4),
                                      MemberMarker(
                                        relationship: rIsResponder ? 'responder' : (isFamily ? relationship : null),
                                        isSafe: isSafeNow,
                                        hasSOS: hasSOS,
                                        isEmergencyActive: isEmergencyActive,
                                        isOnline: true,
                                        isResponder: rIsResponder,
                                        isHighlighted: famEvacLinked,
                                        size: 24,
                                        activeColor: markerColor,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        name.toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          backgroundColor: Colors.white.withOpacity(0.6),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList();
                    })(),
                ],
              ),
            ],
          ),

          // Compact Floating Emergency Panel
          if (_activeDisaster != null)
            Positioned(
              bottom: 110,
              left: 20,
              right: 20,
              child: Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  final currentUser = auth.currentUser;
                  final bool isMeSafe =
                      _isMeSafeLocally ||
                      _filteredResidents.any(
                        (r) =>
                            r['id'].toString() == currentUser?.id.toString() &&
                            r['isSafe'] == true,
                      );

                  if (!_isEmergencyPanelOpen) {
                    // Collapsed View (Pulsing Button-like)
                    return Center(
                      child: GestureDetector(
                        onTap: () => setState(() => _isEmergencyPanelOpen = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isMeSafe ? Colors.green.withOpacity(0.9) : Colors.red,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: (isMeSafe ? Colors.green : Colors.red).withOpacity(0.4),
                                blurRadius: 10,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isMeSafe ? Icons.verified_user : Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isMeSafe ? 'YOU ARE SAFE' : 'TAP TO UPDATE SAFETY',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Expanded View
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isMeSafe
                          ? Colors.grey[50]!.withOpacity(0.9)
                          : Colors.white.withOpacity(0.98),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: isMeSafe
                            ? Colors.grey[300]!
                            : (isMeSafe ? Colors.green : Colors.red).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isMeSafe ? Icons.check_circle_rounded : Icons.warning_rounded,
                                  color: isMeSafe ? Colors.green : Colors.red,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _activeDisaster!['type']?.toUpperCase() ?? 'EMERGENCY',
                                      style: TextStyle(
                                        color: isMeSafe ? Colors.green[800] : Colors.red[800],
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    const Text(
                                      'LIFE SAFETY CHECK-IN',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                              onPressed: () => setState(() => _isEmergencyPanelOpen = false),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _activeDisaster!['description'] ?? 'Please confirm your safety status to assist responders.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 48,
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isMeSafe ? null : () async {
                              await _markAsSafe();
                              setState(() => _isEmergencyPanelOpen = false); 
                            },
                            icon: Icon(
                              isMeSafe ? Icons.verified_user_rounded : Icons.check_circle_outline,
                              size: 20,
                            ),
                            label: Text(
                              isMeSafe ? 'STATUS: SAFE' : 'MARK MYSELF AS SAFE',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isMeSafe ? Colors.green.withOpacity(0.1) : Colors.green,
                              foregroundColor: isMeSafe ? Colors.green : Colors.white,
                              elevation: isMeSafe ? 0 : 4,
                              shape: const StadiumBorder(), 
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          
          // OFFICIAL OVERLAY: Safe vs Pending Count

          // Unified Action Menu (Top Left - Horizontal)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10, width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'menu_toggle',
                    onPressed: () => setState(() {
                      _isActionGroupExpanded = !_isActionGroupExpanded;
                      if (!_isActionGroupExpanded) {
                        _isFamilyPanelOpen = false;
                        _isReportsPanelOpen = false;
                        _isLayersPanelOpen = false;
                      }
                    }),
                    backgroundColor: _isActionGroupExpanded
                        ? AppTheme.primaryColor
                        : Colors.white,
                    elevation: 0,
                    child: Icon(
                      _isActionGroupExpanded
                          ? Icons.close
                          : Icons.arrow_forward_ios,
                      color: _isActionGroupExpanded
                          ? Colors.white
                          : AppTheme.primaryColor,
                      size: 18,
                    ),
                  ),
                  if (_isActionGroupExpanded) ...[
                    const SizedBox(width: 8),
                    // 1. Settings
                    FloatingActionButton.small(
                      heroTag: 'menu_settings',
                      onPressed: () => setState(() {
                        _isLayersPanelOpen = !_isLayersPanelOpen;
                        if (_isLayersPanelOpen) {
                          _isFamilyPanelOpen = false;
                          _isReportsPanelOpen = false;
                        }
                      }),
                      backgroundColor: _isLayersPanelOpen
                          ? Colors.grey[800]
                          : Colors.white,
                      elevation: 0,
                      child: Icon(
                        Icons.settings,
                        color: _isLayersPanelOpen
                            ? Colors.white
                            : AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 2. History
                    FloatingActionButton.small(
                      heroTag: 'menu_history',
                      onPressed: () => setState(() {
                        _isReportsPanelOpen = !_isReportsPanelOpen;
                        if (_isReportsPanelOpen) {
                          _isFamilyPanelOpen = false;
                          _isLayersPanelOpen = false;
                        }
                      }),
                      backgroundColor: _isReportsPanelOpen
                          ? Colors.red
                          : Colors.white,
                      elevation: 0,
                      child: Icon(
                        Icons.history,
                        color: _isReportsPanelOpen
                            ? Colors.white
                            : AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 3. Family
                    FloatingActionButton.small(
                      heroTag: 'menu_family',
                      onPressed: () => setState(() {
                        _isFamilyPanelOpen = !_isFamilyPanelOpen;
                        if (_isFamilyPanelOpen) {
                          _isReportsPanelOpen = false;
                          _isLayersPanelOpen = false;
                        }
                      }),
                      backgroundColor: _isFamilyPanelOpen
                          ? Colors.green
                          : Colors.white,
                      elevation: 0,
                      child: Icon(
                        Icons.family_restroom,
                        color: _isFamilyPanelOpen
                            ? Colors.white
                            : AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 4. Share Location
                    FloatingActionButton.small(
                      heroTag: 'menu_share',
                      onPressed: _updateLocationToFamily,
                      backgroundColor: Colors.white,
                      elevation: 0,
                      child: Icon(
                        Icons.share_location,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),

          // Floating Overlay Panels (High-Clarity Translucent)
          if (_isFamilyPanelOpen)
            Positioned(
              top: 70,
              left: 16,
              child: Container(
                width: 300,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12, width: 1),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 20,
                      color: Colors.black26,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                constraints: const BoxConstraints(maxHeight: 350),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                      ),
                      width: double.infinity,
                      child: const Text(
                        'Family Tracker',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (_familyMembersList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No family members linked',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _familyMembersList.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final m = _familyMembersList[index];
                            final bool hasLocation = m['userId'] != null;
                            final String? uid = m['userId']?.toString();
                            Map<String, dynamic> residentMatch = {};
                            if (uid != null) {
                              for (final r in _filteredResidents) {
                                if (r['id'].toString() == uid) {
                                  residentMatch = r;
                                  break;
                                }
                              }
                            }
                            final String? ecName =
                                residentMatch['evacuationCenterName']
                                    ?.toString();
                            final bool atEvac =
                                ecName != null && ecName.isNotEmpty;
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: const Icon(
                                Icons.person,
                                color: Colors.green,
                                size: 18,
                              ),
                              title: Text(
                                '${m['firstName']} ${m['lastName']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                atEvac
                                    ? '${m['relationship'] ?? 'Member'}\nEvacuation center: $ecName'
                                    : (m['relationship'] ?? 'Member'),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: atEvac
                                      ? Colors.teal.shade800
                                      : null,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: hasLocation
                                  ? const Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.green,
                                    )
                                  : null,
                              onTap: () {
                                final resident = _filteredResidents.firstWhere(
                                  (r) =>
                                      r['id'].toString() ==
                                      m['userId']?.toString(),
                                  orElse: () => {},
                                );
                                if (resident.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No map profile for this member yet.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (resident['latitude'] == null ||
                                    resident['longitude'] == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'This member has no coordinates on the map.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                _showFamilyMemberBottomSheet(
                                  Map<String, dynamic>.from(m),
                                  Map<String, dynamic>.from(resident),
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

          if (_isReportsPanelOpen)
            Positioned(
              top: 70,
              left: 16,
              child: Container(
                width: 300,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12, width: 1),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 20,
                      color: Colors.black26,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                constraints: const BoxConstraints(maxHeight: 350),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                      ),
                      width: double.infinity,
                      child: const Text(
                        'Recent Reports',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (_userReports.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No recent incident reports',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
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
                            final color =
                                _disasterColors[r['type']] ?? Colors.grey;
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: Icon(
                                _disasterIcons[r['type']] ?? Icons.report,
                                color: color,
                                size: 18,
                              ),
                              title: Text(
                                r['type'],
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                r['desc'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                              onTap: () {
                                _mapController.move(r['pos'], 15);
                                setState(() => _isReportsPanelOpen = false);
                                _showHazardDetail({
                                  ...r,
                                  'title': r['type'],
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
            ),

          if (_isLayersPanelOpen)
            Positioned(
              top: 70,
              left: 16,
              child: Container(
                width: 240,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12, width: 1),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 20,
                      color: Colors.black26,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                      ),
                      width: double.infinity,
                      child: const Text(
                        'Map Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: const Text(
                        'Incident Icons',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      secondary: Icon(
                        Icons.warning,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      value: _showIncidentReports,
                      onChanged: (val) =>
                          setState(() => _showIncidentReports = val),
                    ),
                    SwitchListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: const Text(
                        'Barangay Hall',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      secondary: Icon(
                        Icons.account_balance,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      value: _showBarangayHall,
                      onChanged: (val) =>
                          setState(() => _showBarangayHall = val),
                    ),
                    SwitchListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: const Text(
                        'Resident Markers',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      secondary: Icon(
                        Icons.people,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      value: _showResidents,
                      onChanged: (val) => setState(() => _showResidents = val),
                    ),
                    SwitchListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: const Text(
                        'Area Boundaries',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      secondary: Icon(
                        Icons.map,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      value: _showBarangayBoundaries,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (val) =>
                          setState(() => _showBarangayBoundaries = val),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          
          // UNIFIED TACTICAL HUD (Bottom Right)
          Positioned(
            bottom: 16,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Official Metrics (Only for Commanders during disaster)
                if (_activeDisaster != null)
                  Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      final role = auth.currentUser?.role;
                      if (role != UserRole.barangay_head && role != UserRole.responder) {
                        return const SizedBox.shrink();
                      }

                      final int totalSafe = _filteredResidents.where((r) => r['isSafe'] == true).length;
                      final int totalSOS = _filteredResidents.where((r) => r['isSafe'] != true && r['hasResponded'] == true).length;
                      final int totalPending = _filteredResidents.where((r) => r['isSafe'] != true && r['hasResponded'] != true).length;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: Border.all(color: Colors.black.withOpacity(0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                const Text('SITUATION OVERVIEW', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildStatItem('SAFE', totalSafe, Colors.green),
                                const SizedBox(width: 12),
                                _buildStatItem('PENDING', totalPending, Colors.orange),
                                const SizedBox(width: 12),
                                _buildStatItem('SOS', totalSOS, Colors.red),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 2. Report Mode Button (Separated from top menu)
                    FloatingActionButton.small(
                      heroTag: 'map_report_unified',
                      onPressed: () {
                        setState(() => _isReportMode = !_isReportMode);
                        if (_isReportMode) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Report Mode Active: Tap map to report incident'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      backgroundColor: _isReportMode ? Colors.red : Colors.white,
                      elevation: 4,
                      shape: CircleBorder(
                        side: BorderSide(
                          color: _isReportMode ? Colors.white : AppTheme.primaryColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _isReportMode ? Icons.edit_location : Icons.edit_location_outlined,
                        color: _isReportMode ? Colors.white : AppTheme.primaryColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 3. My Location (GPS) Button
                    FloatingActionButton.small(
                      heroTag: 'map_gps_unified',
                      onPressed: _determinePosition,
                      backgroundColor: Colors.white,
                      elevation: 4,
                      child: Icon(Icons.my_location, color: AppTheme.primaryColor, size: 18),
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

  /// Same ordering/filtering as resident markers on the map (for jitter alignment).
  List<Map<String, dynamic>> _residentsDrawnOnMap() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final String? uid = auth.currentUser?.id.toString();
    return (widget.residentsToRescue ?? _filteredResidents)
        .where(
          (r) => r['latitude'] != null && r['longitude'] != null,
        )
        .where(
          (r) =>
              uid == null ||
              r['id'].toString() != uid ||
              _userLocation == null,
        )
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  LatLng? _jitteredMapPointForResident(Map<String, dynamic> target) {
    final list = _residentsDrawnOnMap();
    final Map<String, int> localCollisionMap = {};
    for (final r in list) {
      final double lat = (r['latitude'] as num).toDouble();
      final double lng = (r['longitude'] as num).toDouble();
      final String posKey =
          '${lat.toStringAsFixed(6)}_${lng.toStringAsFixed(6)}';
      final int collisionIdx = localCollisionMap[posKey] ?? 0;
      localCollisionMap[posKey] = collisionIdx + 1;
      if (r['id'].toString() == target['id']?.toString()) {
        final double jitter = collisionIdx * 0.000018;
        return LatLng(lat + jitter, lng + jitter);
      }
    }
    return null;
  }

  /// Evacuation centers that have at least one linked family member registered.
  Set<String> _evacuationCenterIdsLinkedToFamily() {
    final ids = <String>{};
    for (final r in _residentsDrawnOnMap()) {
      if (r['id'] == null ||
          !_familyUserIds.contains(r['id'].toString())) {
        continue;
      }
      final ecId = r['evacuationCenterId']?.toString();
      if (ecId == null || ecId.isEmpty) continue;
      ids.add(ecId);
    }
    return ids;
  }

  List<Polyline> _familyEvacuationPolylines() {
    final out = <Polyline>[];
    for (final r in _residentsDrawnOnMap()) {
      if (r['id'] == null ||
          !_familyUserIds.contains(r['id'].toString())) {
        continue;
      }
      final ecId = r['evacuationCenterId']?.toString();
      if (ecId == null || ecId.isEmpty) continue;
      final person = _jitteredMapPointForResident(r);
      if (person == null) continue;
      LatLng? ecPoint;
      for (final ec in _evacuationCenters) {
        final m = ec as Map<String, dynamic>;
        if (m['id'].toString() == ecId &&
            m['latitude'] != null &&
            m['longitude'] != null) {
          ecPoint = LatLng(
            (m['latitude'] as num).toDouble(),
            (m['longitude'] as num).toDouble(),
          );
          break;
        }
      }
      if (ecPoint == null) continue;
      out.add(
        Polyline(
          points: [person, ecPoint],
          color: Colors.teal,
          strokeWidth: 4,
          borderStrokeWidth: 2,
          borderColor: Colors.white,
        ),
      );
    }
    return out;
  }

  String _formatResidentFullUpdatedAt(Map<String, dynamic> resident) {
    try {
      if (resident['updatedAt'] != null) {
        final dt = DateTime.parse(
          resident['updatedAt'].toString(),
        ).toLocal();
        return DateFormat('MMM d, y • HH:mm').format(dt);
      }
    } catch (_) {}
    return 'N/A';
  }

  void _showFamilyMemberBottomSheet(
    Map<String, dynamic> memberRow,
    Map<String, dynamic> resident,
  ) {
    final String name =
        '${memberRow['firstName'] ?? resident['firstName'] ?? ''} ${memberRow['lastName'] ?? resident['lastName'] ?? ''}'
            .trim();
    final String rel = memberRow['relationship']?.toString() ?? 'Member';
    final String? ecName = resident['evacuationCenterName']?.toString();
    final bool registered = ecName != null && ecName.isNotEmpty;
    final String lastUp = _formatResidentFullUpdatedAt(resident);
    final String coords =
        resident['latitude'] != null && resident['longitude'] != null
        ? '${resident['latitude']}, ${resident['longitude']}'
        : 'Not available';

    setState(() => _isFamilyPanelOpen = false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lat = resident['latitude'];
      final lng = resident['longitude'];
      if (lat == null || lng == null) return;
      final fitPoints = <LatLng>[];
      final jittered = _jitteredMapPointForResident(resident);
      if (jittered != null) fitPoints.add(jittered);
      final ecId = resident['evacuationCenterId']?.toString();
      if (ecId != null && ecId.isNotEmpty) {
        for (final ec in _evacuationCenters) {
          final m = ec as Map<String, dynamic>;
          if (m['id'].toString() == ecId &&
              m['latitude'] != null &&
              m['longitude'] != null) {
            fitPoints.add(
              LatLng(
                (m['latitude'] as num).toDouble(),
                (m['longitude'] as num).toDouble(),
              ),
            );
            break;
          }
        }
      }
      if (fitPoints.length >= 2) {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: fitPoints,
            padding: const EdgeInsets.fromLTRB(40, 100, 40, 320),
            maxZoom: 17,
          ),
        );
      } else if (fitPoints.isNotEmpty) {
        _mapController.move(fitPoints.first, 17);
      } else {
        _mapController.move(
          LatLng((lat as num).toDouble(), (lng as num).toDouble()),
          17,
        );
      }
    });

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    name.isEmpty ? 'Family member' : name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(rel),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    registered ? Icons.shield : Icons.shield_outlined,
                    color: registered ? Colors.teal : Colors.grey,
                  ),
                  title: Text(
                    registered
                        ? 'Registered at evacuation center'
                        : 'Evacuation center',
                  ),
                  subtitle: Text(
                    registered
                        ? ecName
                        : 'Not currently registered at an evacuation center.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Last updated'),
                  subtitle: Text(lastUp),
                ),
                ListTile(
                  leading: const Icon(Icons.location_on),
                  title: const Text('Coordinates'),
                  subtitle: SelectableText(coords),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('CLOSE'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showResidentSafeDetail(
    Map<String, dynamic> resident,
    String name,
    String timeStr,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final bool isEmergency = _activeDisaster != null;
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isEmergency) ...[
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'CONFIRMED SAFE',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
              ] else ...[
                const Icon(
                  Icons.account_circle,
                  color: Color(0xFF1565C0),
                  size: 48,
                ),
                const SizedBox(height: 16),
              ],
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(isEmergency ? 'Marked Safe At' : 'Last Updated'),
                subtitle: Text(timeStr),
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Coordinates'),
                subtitle: Text(
                  '${resident['latitude']}, ${resident['longitude']}',
                ),
              ),
              if (isEmergency) const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEmergency
                      ? Colors.green
                      : const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                ),
                child: const Text('CLOSE'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showResidentRescueDetail(
    Map<String, dynamic> resident,
    String name,
    String timeStr,
  ) {
    final bool isEmergency = _activeDisaster != null;
    final bool isFamily = _familyUserIds.contains(resident['id']?.toString());
    final bool hasResponded = resident['hasResponded'] == true;

    // Normal style vs Emergency style
    final String statusTitle = !isEmergency
        ? ''
        : (hasResponded
              ? 'RESCUE REQUEST'
              : (isFamily ? 'FAMILY: PENDING STATUS' : 'PENDING SAFETY CHECK'));
    final Color statusColor = !isEmergency
        ? const Color(0xFF1565C0)
        : (hasResponded
              ? Colors.red
              : (isFamily ? Colors.orange : Colors.grey));

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isEmergency) ...[
                Icon(
                  hasResponded
                      ? Icons.warning_amber_rounded
                      : (isFamily
                            ? Icons.family_restroom
                            : Icons.person_search),
                  color: statusColor,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  statusTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
              ] else ...[
                const Icon(
                  Icons.account_circle,
                  color: Color(0xFF1565C0),
                  size: 48,
                ),
                const SizedBox(height: 16),
              ],
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(
                  isEmergency ? 'Last GPS Available' : 'Last Updated',
                ),
                subtitle: Text(timeStr),
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Coordinates'),
                subtitle: Text(
                  '${resident['latitude']}, ${resident['longitude']}',
                ),
              ),
              if (isFamily && isEmergency && !hasResponded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'This family member has not yet updated their safety status.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(isEmergency ? 'DISMISS' : 'CLOSE'),
              ),
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

        final bool isOwnReport =
            reportUserId != null && reportUserId == currentUserId;

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
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isUserReport)
                            Text(
                              'Reported by ${hazard['reporterName']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (hazard['isResolved'] == true
                                      ? Colors.green
                                      : (hazard['color'] as Color))
                                  .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hazard['isResolved'] == true
                                ? Colors.green
                                : hazard['color'],
                          ),
                        ),
                        child: Text(
                          hazard['isResolved'] == true
                              ? 'RESOLVED'
                              : hazard['level'],
                          style: TextStyle(
                            color: hazard['isResolved'] == true
                                ? Colors.green
                                : hazard['color'],
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
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 100,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                ),
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
                    const SizedBox(height: 20),
                    
                    // SITUATIONAL ACTIONS COLUMN
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Resolve Action (Visible ONLY to owner or official (Head/Responder))
                        if (hazard['isResolved'] != true && (isOwnReport || authProvider.currentUser?.role != UserRole.resident)) ...[
                          ElevatedButton.icon(
                            onPressed: () => _handleReportAction(hazard['id'], 'resolve'),
                            icon: const Icon(Icons.verified, size: 18),
                            label: const Text('MARK AS RESOLVED', 
                              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                         // 2. Agree/Upvote Action (Themed uniform button)
                        IgnorePointer(
                          ignoring: isOwnReport,
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _handleReportAction(hazard['id'], 'upvote'),
                              icon: Icon(Icons.thumb_up_alt_rounded, 
                                size: 18, 
                                color: isOwnReport ? Colors.grey : Colors.green),
                              label: Text(
                                'AGREE TO THIS REPORT (${hazard['upvotes']})',
                                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isOwnReport ? Colors.grey[100] : Colors.green.withOpacity(0.08),
                                foregroundColor: isOwnReport ? Colors.grey : Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: (isOwnReport ? Colors.grey : Colors.green).withOpacity(0.2)),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 4. Report False Info (Uniform style)
                        if (!isOwnReport && authProvider.currentUser?.role == UserRole.resident) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _handleReportAction(hazard['id'], 'flag'),
                              icon: const Icon(Icons.flag_rounded, size: 18),
                              label: const Text('REPORT AS FALSE INFORMATION', 
                                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.withOpacity(0.08),
                                foregroundColor: Colors.orange[800],
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: Colors.orange.withOpacity(0.2)),
                                ),
                              ),
                            ),
                          ),
                        ],

                        // 3. Delete Action (Restricted to owner or official)
                        if (isOwnReport || authProvider.currentUser?.role != UserRole.resident) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _handleReportAction(hazard['id'], 'delete'),
                              icon: const Icon(Icons.delete_forever_rounded, size: 18),
                              label: const Text('REMOVE INCIDENT REPORT', 
                                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.withOpacity(0.08),
                                foregroundColor: Colors.red[800],
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: Colors.red.withOpacity(0.2)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('CLOSE PANEL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.black.withOpacity(0.1)),
                        ),
                      ),
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

  Widget _buildVoteChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
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
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
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
      late http.Response response;
      
      if (action == 'delete') {
        response = await http.delete(
          Uri.parse('$_baseUrl/api/reports/$id'),
          headers: {
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
        );
      } else {
        response = await http.patch(
          Uri.parse('$_baseUrl/api/reports/$id'),
          body: json.encode({'action': action}),
          headers: {
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
        );
      }

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context); // Close current detail modal
          _fetchReports(); // Refresh data
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Report ${action == "delete" ? "removed" : action + "d"} successfully'),
              backgroundColor: action == 'delete' ? Colors.red : Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error report action: $e');
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
                        'Report Incident',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
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
                    'Incident Type',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.8,
                          ),
                      itemCount: _disasterIcons.length,
                      itemBuilder: (context, index) {
                        final type = _disasterIcons.keys.elementAt(index);
                        final icon = _disasterIcons[type]!;
                        final color = _disasterColors[type]!;
                        final isSelected = selectedType == type;

                        return GestureDetector(
                          onTap: () => setModalState(() => selectedType = type),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: isSelected
                                    ? color
                                    : Colors.grey[200],
                                child: Icon(
                                  icon,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[600],
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                type,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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
                            onTap: () =>
                                setModalState(() => pickedImage = null),
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              radius: 12,
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    InkWell(
                      onTap: () async {
                        final image = await _picker.pickImage(
                          source: ImageSource.gallery,
                        );
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
                          border: Border.all(
                            color: Colors.grey[300]!,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Attach Picture',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
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
                            const SnackBar(
                              content: Text('Please select a disaster type'),
                            ),
                          );
                          return;
                        }
                        _submitReport(
                          point,
                          selectedType!,
                          descController.text,
                          pickedImage,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Submit Emergency Report',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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

  Future<void> _submitReport(
    LatLng point,
    String type,
    String desc,
    XFile? image,
  ) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final String? userId = authProvider.currentUser?.id;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/reports'),
      );

      request.fields['type'] = type;
      request.fields['description'] = desc;
      request.fields['latitude'] = point.latitude.toString();
      request.fields['longitude'] = point.longitude.toString();
      if (userId != null) {
        request.fields['userId'] = userId;
      }

      if (image != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            image.path,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 7,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
