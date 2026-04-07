import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/user.dart';
import '../common/hazard_map_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/api_config.dart';
import '../../utils/theme.dart';
import '../../widgets/view_on_map_button.dart';
import '../user/edit_profile_screen.dart';
import '../common/profile_tab_sliver.dart';
import '../barangay_head/reported_incidents_management_screen.dart';
import '../common/notifications_tab_sliver.dart';
import '../../widgets/dashboard_info_card.dart';
import '../user/family_management_screen.dart';
import '../barangay_head/evacuation_qr_scanner_screen.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../../services/notification_service.dart';
import 'dart:io';

class ResponderDashboard extends StatefulWidget {
  const ResponderDashboard({super.key});

  @override
  State<ResponderDashboard> createState() => _ResponderDashboardState();
}

class _ResponderDashboardState extends State<ResponderDashboard> {
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;
  Timer? _scrollThrottleTimer;
  bool _hasBeenCollapsed = false;
  final MapController _previewMapController = MapController();
  LatLng? _previewLocation;
  LatLng? _hqLocation;
  List<Map<String, dynamic>> _userReports = [];
  static final Set<String> _notifiedIncidents = {};

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

  // Disaster Mode State
  Map<String, dynamic>? _activeDisaster;
  List<dynamic> _residents = [];
  HttpClient? _disasterSseClient;
  HttpClient? _residentsSseClient;
  List<dynamic> _evacuationCenters = [];
  List<dynamic> _recentScans = [];
  bool _loadingScans = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollThrottleTimer?.isActive ?? false) return;
      _scrollThrottleTimer = Timer(const Duration(milliseconds: 16), () {
        if (mounted) {
          setState(() {
            _scrollOffset = _scrollController.offset;
            final double collapseThreshold =
                MediaQuery.of(context).size.height * 1;
            if (_scrollOffset >= collapseThreshold && !_hasBeenCollapsed) {
              _hasBeenCollapsed = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                }
              });
            }
          });
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isConnected) {
        await eventProvider.loadEvents();
      } else {
        await eventProvider.loadEventsFromCache();
      }
      eventProvider.startConnectivityMonitoring();
      Provider.of<AttendanceProvider>(context, listen: false).loadAttendances();
      final notificationProvider = Provider.of<NotificationProvider>(
        context,
        listen: false,
      );
      notificationProvider.addDummyData();
      notificationProvider.addListener(_onNotificationUpdate);
      notificationProvider.connect();
      _checkNotificationPermissions();
      _determinePreviewPosition();
      _fetchReports(); // Fetch incident reports for map preview
      _checkDisaster(); // Initial check
      _fetchHqLocation(); // Initial check
      _fetchResidents(); // Initial check
      _fetchEvacuationCenters();
      _fetchScans();
      _startDisasterStream();
    });
  }

  Future<void> _fetchReports() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/reports'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _userReports = data.where((r) => r['isResolved'] == false).map((r) {
            return {
              'type': r['type'],
              'desc': r['description'],
              'pos': LatLng(
                double.parse(r['latitude'].toString()),
                double.parse(r['longitude'].toString()),
              ),
              'isResolved': r['isResolved'],
              'latitude': double.parse(r['latitude'].toString()),
              'longitude': double.parse(r['longitude'].toString()),
              'createdAt': r['createdAt'],
            };
          }).toList();
        });
        _checkIncidentProximity();
      }
    } catch (e) {
      debugPrint('Error fetching reports for preview: $e');
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
            // center to HQ if no user location yet
            if (_previewLocation == null) {
              _previewMapController.move(_hqLocation!, 15);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching HQ location: $e');
    }
  }

  void _startDisasterStream() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null || user.barangay == null) return;

    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/disaster/events?barangay=${user.barangay}',
    );

    _disasterSseClient?.close(force: true);
    _disasterSseClient = HttpClient();

    Future.microtask(() async {
      try {
        final request = await _disasterSseClient!.getUrl(url);
        request.headers.set('Accept', 'text/event-stream');
        request.headers.set('Cache-Control', 'no-cache');
        request.headers.set('ngrok-skip-browser-warning', 'true');

        final response = await request.close();
        response
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (line.trim().isEmpty) return;
                if (line.startsWith('data: ')) {
                  final data = jsonDecode(line.substring(6));
                  if (mounted) {
                    setState(() {
                      if (data['isActive'] == true) {
                        _activeDisaster = data['disaster'];
                        _startResidentsStream();
                      } else {
                        _activeDisaster = null;
                        _residents = [];
                        _residentsSseClient?.close(force: true);
                      }
                    });
                  }
                }
              },
              onDone: () {
                if (mounted)
                  Future.delayed(
                    const Duration(seconds: 5),
                    _startDisasterStream,
                  );
              },
            );
      } catch (e) {
        if (mounted)
          Future.delayed(const Duration(seconds: 10), _startDisasterStream);
      }
    });
  }

  void _startResidentsStream() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (_activeDisaster == null || user?.barangay == null) return;

    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/barangay/residents/events?barangay=${user!.barangay}',
    );

    _residentsSseClient?.close(force: true);
    _residentsSseClient = HttpClient();

    Future.microtask(() async {
      try {
        final request = await _residentsSseClient!.getUrl(url);
        request.headers.set('Accept', 'text/event-stream');
        request.headers.set('Cache-Control', 'no-cache');
        request.headers.set('ngrok-skip-browser-warning', 'true');

        final response = await request.close();
        response
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (line.trim().isEmpty) return;
                if (line.startsWith('data: ')) {
                  final residentData = jsonDecode(line.substring(6));
                  if (mounted) {
                    setState(() {
                      final index = _residents.indexWhere(
                        (r) => r['id'] == residentData['id'],
                      );
                      if (index != -1) {
                        _residents[index] = residentData;
                      } else {
                        _residents.add(residentData);
                      }
                    });
                  }
                }
              },
              onDone: () {
                if (mounted && _activeDisaster != null) {
                  Future.delayed(
                    const Duration(seconds: 5),
                    _startResidentsStream,
                  );
                }
              },
            );
      } catch (e) {
        if (mounted && _activeDisaster != null) {
          Future.delayed(const Duration(seconds: 10), _startResidentsStream);
        }
      }
    });
  }

  Future<void> _checkDisaster() async {
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
          if (data['disaster'] != null) {
            _fetchResidents();
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking disaster: $e');
    }
  }

  Future<void> _fetchResidents() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user?.barangay == null) return;
    try {
      final String baseUrl =
          '${ApiConfig.baseUrl}/api/barangay/residents?barangay=${user!.barangay}';
      final String url = _activeDisaster != null
          ? '$baseUrl&disasterId=${_activeDisaster!['id']}'
          : baseUrl;
      final response = await http.get(
        Uri.parse(url),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _residents = data['residents'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching residents: $e');
    }
  }

  Future<void> _fetchEvacuationCenters() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user?.barangay == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/evacuation-center?barangay=${user!.barangay}',
        ),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _evacuationCenters = data['centers'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching centers: $e');
    }
  }

  Future<void> _fetchScans() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user?.barangay == null) return;

    try {
      setState(() => _loadingScans = true);
      final centersRes = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/evacuation-center?barangay=${Uri.encodeQueryComponent(user!.barangay!)}',
        ),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (centersRes.statusCode != 200) {
        setState(() => _loadingScans = false);
        return;
      }
      final centersData = jsonDecode(centersRes.body);
      final List<dynamic> centers = centersData['centers'] ?? [];

      List<dynamic> allScans = [];
      for (var center in centers) {
        final regRes = await http.get(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/evacuation-center/residents?evacuationCenterId=${center['id']}',
          ),
          headers: {'ngrok-skip-browser-warning': 'true'},
        );
        if (regRes.statusCode == 200) {
          final regData = jsonDecode(regRes.body);
          final List<dynamic> scans = regData['evacuees'] ?? [];
          for (var s in scans) {
            s['centerName'] = center['name'];
          }
          allScans.addAll(scans);
        }
      }

      allScans.sort((a, b) {
        final ad = DateTime.parse(a['createdAt'] ?? DateTime.now().toString());
        final bd = DateTime.parse(b['createdAt'] ?? DateTime.now().toString());
        return bd.compareTo(ad);
      });

      if (mounted) {
        setState(() {
          _recentScans = allScans;
          _loadingScans = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching scans: $e');
      if (mounted) setState(() => _loadingScans = false);
    }
  }

  Future<void> _determinePreviewPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        Position pos = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _previewLocation = LatLng(pos.latitude, pos.longitude);
          });
          _previewMapController.move(_previewLocation!, 16);
        }
      }
    } catch (_) {}
  }

  Future<void> _handleLogout() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _checkNotificationPermissions() async {
    final granted = await NotificationService.checkPermissions();
    if (!granted && mounted) {
      _showPermissionDialog();
    }
  }

  void _onNotificationUpdate() {
    if (!mounted) return;
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    if (provider.latestIncoming != null) {
      final n = provider.latestIncoming!;
      double distance = 0;
      bool withinRange = true;

      // Apply territory-wide geospatial filtering (500km threshold) and age filter (under 1 day)
      if (n.latitude != null &&
          n.longitude != null &&
          _previewLocation != null) {
        distance = Geolocator.distanceBetween(
          _previewLocation!.latitude,
          _previewLocation!.longitude,
          n.latitude!,
          n.longitude!,
        );
        withinRange = distance < 500000;
      }

      // Past 1 day filter
      final bool isTooOld = DateTime.now().difference(n.time).inDays >= 1;

      if (withinRange && !isTooOld) {
        // Explicitly only show the intrusive popup window if it's within 5km radius
        if (distance < 5000) {
          _showHazardAlertWindow(n, distance);
        }

        NotificationService.showNotification(
          id: n.id.hashCode,
          title: n.title,
          body: n.desc,
        );
        _fetchReports();
      }
      provider.clearLatest();
    }
  }

  void _showHazardAlertWindow(AppNotification n, double distance) {
    String distanceStr = '';
    if (distance > 0) {
      distanceStr = distance > 1000
          ? '${(distance / 1000).toStringAsFixed(1)}km'
          : '${distance.toInt()}m';
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: n.color.withOpacity(0.3), width: 1.5),
        ),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        title: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            color: n.color.withOpacity(0.12),
            border: Border(
              bottom: BorderSide(color: n.color.withOpacity(0.2), width: 1),
            ),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Icon(n.icon, color: n.color, size: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'EMERGENCY ALERT',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'HAZARD WARNING',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: n.color,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              n.title.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: n.color,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
            if (n.desc.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                n.desc,
                style: const TextStyle(
                  color: Colors.black87,
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: n.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: n.color.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: n.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      distance > 0
                          ? 'Hazard $distanceStr away. Response needed.'
                          : 'New hazardous incident logged in your territory.',
                      style: TextStyle(
                        color: n.color.withOpacity(0.9),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: n.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _selectedIndex = 0; // Center map or dashboard
                });
              },
              child: const Text(
                'VIEW DETAILS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'DISMISS ALERT',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'STAY ALERT & READY',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_active_outlined,
              size: 64,
              color: Color(0xFF006064),
            ),
            SizedBox(height: 16),
            Text(
              'As a responder, immediate awareness is critical. Enable notifications to receive instant hazard alerts and extraction requests in your area.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5, fontSize: 13),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.only(bottom: 16, right: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'LATER',
              style: TextStyle(
                color: Colors.grey[400],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006064),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await NotificationService.requestPermissions();
            },
            child: const Text(
              'ENABLE NOW',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _checkIncidentProximity() {
    if (_previewLocation == null || _userReports.isEmpty) return;

    final notificationProvider = Provider.of<NotificationProvider>(
      context,
      listen: false,
    );

    for (var report in _userReports) {
      if (report['latitude'] == null || report['longitude'] == null) continue;

      final double distance = Geolocator.distanceBetween(
        _previewLocation!.latitude,
        _previewLocation!.longitude,
        report['latitude'],
        report['longitude'],
      );

      // Notify if within 500km (geospatial threshold) and not too old (1 day) and not already notified
      final bool isWithinRange = distance < 500000;

      DateTime reportedTime = DateTime.now();
      try {
        if (report['createdAt'] != null) {
          reportedTime = DateTime.parse(report['createdAt']);
        }
      } catch (_) {}

      final bool isTooOld = DateTime.now().difference(reportedTime).inDays >= 1;

      if (isWithinRange &&
          !isTooOld &&
          !_notifiedIncidents.contains(report['id']?.toString() ?? '')) {
        final String type = report['type'] ?? 'Incident';
        final Color incidentColor = _disasterColors[type] ?? Colors.red;

        DateTime reportedTime = DateTime.now();
        try {
          if (report['createdAt'] != null) {
            reportedTime = DateTime.parse(report['createdAt']);
          }
        } catch (_) {}

        notificationProvider.addNotification(
          AppNotification(
            id: report['id']?.toString() ?? DateTime.now().toString(),
            type: 'Nearby Warning',
            category: AppNotificationType.Proximity,
            title: 'Nearby $type Alert',
            desc:
                'An incident was reported approximately ${distance.toInt()}m from your current location. Move with extreme caution.',
            time: reportedTime,
            icon: _disasterIcons[type] ?? Icons.warning_amber_rounded,
            color: incidentColor,
          ),
        );

        if (report['id'] != null) {
          _notifiedIncidents.add(report['id'].toString());
        }

        NotificationService.showNotification(
          id: (report['id']?.toString() ?? '').hashCode,
          title: 'Nearby $type Alert',
          body: 'Hazard reported ${distance.toInt()}m away. Response needed.',
        );

        final bool isFresh =
            DateTime.now().difference(reportedTime).inMinutes <= 5;

        if (isFresh && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _disasterIcons[type] ?? Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nearby $type! (${distance.toInt()}m)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: incidentColor,
              behavior: SnackBarBehavior.floating,
              shape: const StadiumBorder(),
              margin: const EdgeInsets.fromLTRB(48, 0, 48, 100),
              elevation: 4,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _disasterSseClient?.close(force: true);
    _residentsSseClient?.close(force: true);
    // Use a try-catch to safely remove listener during disposal
    try {
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).removeListener(_onNotificationUpdate);
    } catch (_) {}
    _scrollController.dispose();
    _scrollThrottleTimer?.cancel();
    _previewMapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    // Theme color for Responder: TEAL
    final Color primaryDashboardColor = _activeDisaster != null
        ? Colors.red
        : const Color(0xFF006064);

    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildMainContent(user, primaryDashboardColor),
    );
  }

  Widget _buildMainContent(User? user, Color primaryColor) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    final bool is600PLUS = screenWidth > 600;
    final bool is500PLUS = screenWidth > 500;
    final bool is400PLUS = screenWidth > 400;
    final bool is300PLUS = screenWidth > 300;
    final bool is700PLUS = screenWidth > 700;

    final double sliverAppBarHeight = MediaQuery.of(context).size.height * 1.0;

    double maxQrSize;
    if (is700PLUS) {
      if (screenHeight > 800) {
        maxQrSize = (sliverAppBarHeight * 0.40).clamp(200, 250);
      } else if (screenHeight > 400) {
        maxQrSize = (sliverAppBarHeight * 0.40).clamp(180, 200);
      } else {
        maxQrSize = (sliverAppBarHeight * 0.25).clamp(150, 200);
      }
    } else if (is500PLUS) {
      maxQrSize = (sliverAppBarHeight * 0.25).clamp(200, 300);
    } else if (is400PLUS) {
      maxQrSize = (sliverAppBarHeight * 0.40).clamp(150, 250);
    } else if (is300PLUS) {
      maxQrSize = (sliverAppBarHeight * 0.30).clamp(180, 200);
    } else {
      maxQrSize = (sliverAppBarHeight * 0.40).clamp(150, 250);
    }

    double qrSize;
    double finalCollapsedSize = maxQrSize * 0.4;

    if (_hasBeenCollapsed) {
      qrSize = finalCollapsedSize;
    } else {
      qrSize =
          maxQrSize -
          (_scrollOffset * 0.3).clamp(0, maxQrSize - finalCollapsedSize);
    }

    double startingTopPosition = (screenHeight * 0.50).clamp(200, 250);
    final double collapsedHeight = MediaQuery.of(context).size.height * 0.15;
    final double maxUpwardMovement =
        startingTopPosition - (collapsedHeight * 0.1);

    double qrTopPosition;
    if (_hasBeenCollapsed) {
      qrTopPosition = collapsedHeight * 0.1;
    } else {
      qrTopPosition =
          startingTopPosition -
          (_scrollOffset * 0.3).clamp(0, maxUpwardMovement);
    }

    final double maxScrollForLeftTransition = 300.0;
    final double centeredExpandedLeft = (screenWidth - qrSize) / 2;
    final double finalLeftPosition = is600PLUS ? 80.0 : 40.0;

    double qrHorizontalPosition;
    if (_hasBeenCollapsed) {
      qrHorizontalPosition = finalLeftPosition;
    } else if (_scrollOffset <= maxScrollForLeftTransition) {
      double t = _scrollOffset / maxScrollForLeftTransition;
      qrHorizontalPosition =
          centeredExpandedLeft * (1 - t) + finalLeftPosition * t;
    } else {
      qrHorizontalPosition = finalLeftPosition;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'RESPONDER UNIT',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              _checkDisaster();
              final eventProvider = Provider.of<EventProvider>(
                context,
                listen: false,
              );
              await eventProvider.loadEvents();
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: _hasBeenCollapsed
                      ? MediaQuery.of(context).size.height * 0.15
                      : MediaQuery.of(context).size.height * 1.0,
                  collapsedHeight: MediaQuery.of(context).size.height * 0.15,
                  pinned: true,
                  floating: false,
                  backgroundColor: primaryColor,
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(100),
                      bottomRight: Radius.circular(100),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                ),
                SliverToBoxAdapter(
                  child: Container(height: 0, color: Colors.transparent),
                ),
                if (_selectedIndex == 0) _buildAdminMainSliver(primaryColor),
                if (_selectedIndex == 1) _buildAttendanceHistorySliver(),
                if (_selectedIndex == 2) const NotificationsTabSliver(),
                if (_selectedIndex == 3)
                  ProfileTabSliver(
                    user: user,
                    onLogout: _handleLogout,
                    actionColor: primaryColor,
                  ),
              ],
            ),
          ),

          if (_scrollOffset <= 200 && !_hasBeenCollapsed) ...[
            Positioned(
              top: qrTopPosition - (qrSize * 0.5),
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: (1 - (_scrollOffset / 200)).clamp(0, 1),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: qrSize * 0.2),
                  child: Column(
                    children: [
                      Text(
                        'UNIT ONLINE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (qrSize * 0.10).clamp(16, 40),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: qrSize * 0.02),
                      Text(
                        'Emergency response terminal active.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: (qrSize * 0.06).clamp(12, 28),
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          Positioned(
            top: qrTopPosition,
            left: qrHorizontalPosition,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: qrSize,
              width: (_scrollOffset > 200 || _hasBeenCollapsed)
                  ? screenWidth - (is600PLUS ? 160 : 80)
                  : qrSize,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: (_scrollOffset > 200 || _hasBeenCollapsed)
                  ? Row(
                      children: [
                        SizedBox(
                          width: qrSize,
                          child: Center(
                            child: _buildAdminQRCode(
                              user,
                              qrSize * 0.9,
                              primaryColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Responder Name',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: is600PLUS ? 20 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Public Safety Responder',
                                style: TextStyle(
                                  color: primaryColor.withOpacity(0.8),
                                  fontSize: is600PLUS ? 16 : 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: _buildAdminQRCode(
                        user,
                        qrSize * 0.9,
                        primaryColor,
                      ),
                    ),
            ),
          ),

          if (_scrollOffset <= 200 && !_hasBeenCollapsed) ...[
            Positioned(
              top:
                  (qrTopPosition +
                          qrSize +
                          20 -
                          (_scrollOffset * 0.3).clamp(0, 40))
                      .clamp(
                        collapsedHeight * 0.1,
                        startingTopPosition + qrSize + 20,
                      ),
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: (1 - (_scrollOffset / 200)).clamp(0, 1),
                child: Center(
                  child: Text(
                    user?.name ?? 'Responder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: is600PLUS ? 36 : 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            Positioned(
              top:
                  (qrTopPosition +
                          qrSize +
                          60 -
                          (_scrollOffset * 0.3).clamp(0, 40))
                      .clamp(
                        collapsedHeight * 0.3,
                        startingTopPosition + qrSize + 60,
                      ),
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: (1 - (_scrollOffset / 200)).clamp(0, 1),
                child: Center(
                  child: Text(
                    'Emergency Responder Unit',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: is600PLUS ? 24 : 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],

          if (_scrollOffset < 10 && !_hasBeenCollapsed) ...[
            Positioned(
              top: sliverAppBarHeight - (qrSize * 1),
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _scrollOffset < 10 ? 1.0 : 0.0,
                  child: Column(
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: qrSize * 0.08,
                          vertical: qrSize * 0.03,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.9),
                              Colors.white.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          'SWIPE UP TO MANAGE',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: (qrSize * 0.07).clamp(10, 20),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Incident reports and response logs',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: (qrSize * 0.06).clamp(8, 16),
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          if (_hasBeenCollapsed) ...[
            Positioned(
              top: collapsedHeight - 40,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() => _hasBeenCollapsed = false);
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: (_scrollOffset > 50 || _hasBeenCollapsed)
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: primaryColor,
              unselectedItemColor: Colors.grey,
              onTap: (index) => setState(() => _selectedIndex = index),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications_none),
                  label: 'Alerts',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildAdminQRCode(User? user, double size, Color color) {
    if (user == null) return Container();
    final qrPayload = jsonEncode({'responderId': user.id, 'role': 'responder'});
    final qrData = base64Encode(utf8.encode(qrPayload));
    return QrImageView(
      data: qrData,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      foregroundColor: color,
    );
  }

  Widget _buildAdminMainSliver(Color primaryColor) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        final isActive = _activeDisaster != null;
        final missingCount = _residents
            .where((r) => r['isSafe'] == false)
            .length;

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildQuickActionsGrid(primaryColor),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isActive ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive
                        ? Colors.red.shade200
                        : Colors.green.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          isActive
                              ? Icons.warning_amber_rounded
                              : Icons.shield_outlined,
                          color: isActive ? Colors.red : Colors.green,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isActive
                                    ? 'EMERGENCY ACTIVE'
                                    : 'SYSTEM STATUS: SAFE',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.red : Colors.green,
                                ),
                              ),
                              Text(
                                isActive
                                    ? '$missingCount residents missing.'
                                    : 'All residents safe.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isActive
                                      ? Colors.red[700]
                                      : Colors.green[700],
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildHazardMapPreview(primaryColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (isActive && _residents.any((r) => r['isSafe'] == false)) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_search,
                          color: Colors.red,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Missing People',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$missingCount',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _residents.isEmpty
                                    ? 0
                                    : (missingCount / _residents.length),
                                backgroundColor: Colors.red.withOpacity(0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.red,
                                ),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Out of ${_residents.length} total residents',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[300]),
                    ],
                  ),
                ),
              ],

              if (isActive && _residents.any((r) => r['isSafe'] == false)) ...[
                const SizedBox(height: 24),
                _buildRescueRequestsList(),
              ],

              DashboardInfoCard(
                icon: Icons.people_outline,
                title: 'Registered Residents',
                value: '${_residents.length}',
                subtext:
                    'In Brgy. ${Provider.of<AuthProvider>(context).currentUser?.barangay ?? "N/A"}',
                iconColor: Colors.blue,
              ),
              DashboardInfoCard(
                icon: Icons.emergency_outlined,
                title: 'Active Evacuation Centers',
                value: '${_evacuationCenters.length}',
                subtext: _evacuationCenters.isEmpty
                    ? 'No centers active'
                    : 'Current sanctuary locations.',
                iconColor: Colors.green,
                onTap: () {
                  // Maybe navigate to a dedicated screen
                },
              ),
              const SizedBox(height: 100),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsGrid(Color primaryColor) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double itemWidth = (screenWidth - 32) / 4;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 0,
        runSpacing: 16,
        children: [
          _buildQuickActionItem(
            width: itemWidth,
            icon: Icons.report_gmailerrorred_outlined,
            label: 'Incidents',
            color: Colors.red,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReportedIncidentsManagementScreen(),
              ),
            ),
          ),
          _buildQuickActionItem(
            width: itemWidth,
            icon: Icons.family_restroom_outlined,
            label: 'Add Family',
            color: Colors.indigo,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FamilyManagementScreen(),
              ),
            ),
          ),
          _buildQuickActionItem(
            width: itemWidth,
            icon: Icons.qr_code_scanner,
            label: 'Scan QR',
            color: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EvacuationQrScannerScreen(),
              ),
            ),
          ),
          _buildQuickActionItem(
            width: itemWidth,
            icon: Icons.edit_note,
            label: 'Edit Profile',
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditProfileScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRescueRequestsList() {
    final rescueRequests = _residents
        .where((r) => r['isSafe'] == false)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Rescue Request List',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${rescueRequests.length} ALERT',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: rescueRequests.length,
            itemBuilder: (context, index) {
              final resident = rescueRequests[index];
              final String name =
                  '${resident['firstName'] ?? ""} ${resident['lastName'] ?? ""}'
                      .trim();

              // Handle timestamp
              String timeStr = 'N/A';
              try {
                if (resident['updatedAt'] != null) {
                  final dt = DateTime.parse(resident['updatedAt']).toLocal();
                  timeStr = DateFormat('HH:mm:ss').format(dt);
                }
              } catch (_) {}

              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 16, bottom: 8, top: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.red.shade50],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.red.withOpacity(0.1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name.isEmpty ? 'Unknown' : name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'GPS: $timeStr',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      resident['hasResponded'] == true
                          ? 'REQUESTED RESCUE'
                          : 'NOT RESPONDING',
                      style: TextStyle(
                        color: resident['hasResponded'] == true
                            ? Colors.red.shade900
                            : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ViewOnMapButton(
                      residents: _residents,
                      locationData: resident,
                      isPrimary: true,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required double width,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHazardMapPreview(Color primaryColor) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HazardMapScreen(
            residentsToRescue: _residents.cast<Map<String, dynamic>>(),
          ),
        ),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              AbsorbPointer(
                child: FlutterMap(
                  mapController: _previewMapController,
                  options: const MapOptions(
                    initialCenter: LatLng(14.5995, 120.9842),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                    MarkerLayer(
                      markers: [
                        if (_previewLocation != null)
                          Marker(
                            point: _previewLocation!,
                            width: 30,
                            height: 30,
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                        if (_hqLocation != null)
                          Marker(
                            point: _hqLocation!,
                            width: 30,
                            height: 30,
                            child: const Icon(
                              Icons.account_balance,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),

                        // Residents and Responders (Tactical Filter for Responders)
                        ...(() {
                          final bool isActive = _activeDisaster != null;
                          return _residents
                              .where((r) {
                                if (r['latitude'] == null ||
                                    r['longitude'] == null)
                                  return false;

                                final String role =
                                    r['role']?.toString().toLowerCase() ?? '';
                                final bool isResponder = role.contains(
                                  'responder',
                                );

                                // Responders always see other responders.
                                if (isResponder) return true;

                                // If disaster mode is OFF, responders SHOULD NOT see residents.
                                if (!isActive) return false;

                                // During disaster, responders ONLY see unsafe or SOS residents on this map.
                                final bool isSafeNow = (r['isSafe'] == true);
                                if (isSafeNow) return false;

                                return true;
                              })
                              .map((r) {
                                final String role =
                                    r['role']?.toString().toLowerCase() ?? '';
                                final bool isResponder = role.contains(
                                  'responder',
                                );
                                final bool isSafeNow = (r['isSafe'] == true);
                                final bool hasSOS = (r['hasResponded'] == true);

                                Color markerColor = !isActive
                                    ? (AppTheme.primaryColor)
                                    : (isResponder
                                          ? Colors.blue
                                          : (isSafeNow
                                                ? Colors.green
                                                : (hasSOS
                                                      ? Colors.red
                                                      : (Colors.grey))));

                                if (isResponder) markerColor = Colors.blue;

                                return Marker(
                                  point: LatLng(
                                    (r['latitude'] as num).toDouble(),
                                    (r['longitude'] as num).toDouble(),
                                  ),
                                  width: isResponder ? 20 : 15,
                                  height: isResponder ? 20 : 15,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: markerColor,
                                        width: isResponder ? 2 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          blurRadius: 2,
                                          color: markerColor.withOpacity(0.3),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isResponder
                                          ? Icons.security_rounded
                                          : ((isActive && isSafeNow)
                                                ? Icons.check_circle
                                                : Icons.person_pin_circle),
                                      color: markerColor,
                                      size: isResponder ? 12 : 8,
                                    ),
                                  ),
                                );
                              });
                        })(),

                        // Incident Reports
                        ..._userReports.map((r) {
                          final color =
                              _disasterColors[r['type']] ?? Colors.red;
                          return Marker(
                            point: r['pos'] as LatLng,
                            width: 25,
                            height: 25,
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
                              child: Icon(
                                _disasterIcons[r['type']] ?? Icons.report,
                                color: color,
                                size: 12,
                              ),
                            ),
                          );
                        }),

                        ..._residents.map((r) {
                          final isSafe = r['isSafe'] == true;
                          if (r['latitude'] == null || r['longitude'] == null)
                            return const Marker(
                              point: LatLng(0, 0),
                              child: SizedBox.shrink(),
                            );
                          final color = isSafe
                              ? Colors.green
                              : (r['hasResponded'] == true
                                    ? Colors.red
                                    : Colors.redAccent);

                          return Marker(
                            point: LatLng(r['latitude'], r['longitude']),
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSafe
                                    ? Colors.green
                                    : (r['hasResponded'] == true
                                          ? Colors.red
                                          : Colors.white),
                                shape: BoxShape.circle,
                                border: Border.all(color: color, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 4,
                                    color: color.withOpacity(0.3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isSafe
                                    ? Icons.check
                                    : (r['hasResponded'] == true
                                          ? Icons.sos
                                          : Icons.warning),
                                color: (isSafe || r['hasResponded'] == true)
                                    ? Colors.white
                                    : Colors.red,
                                size: 14,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceHistorySliver() {
    if (_loadingScans && _recentScans.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(80.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_recentScans.isEmpty) {
      return SliverToBoxAdapter(
        child: RefreshIndicator(
          onRefresh: _fetchScans,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(80.0),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_scanner,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text(
                      'No recent unit scans found.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _fetchScans,
                      child: const Text('Refresh Logs'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final scan = _recentScans[index];
            final String name =
                '${scan['firstName'] ?? ""} ${scan['lastName'] ?? ""}'.trim();
            final DateTime date =
                DateTime.parse(scan['createdAt'] ?? DateTime.now().toString());
            final String timeStr = DateFormat('MMM dd, hh:mm a').format(date);
            const tealColor = Color(0xFF006064);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tealColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_pin_circle_outlined,
                      color: tealColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Registered at: ${scan['centerName'] ?? "Evacuation Center"}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
          childCount: _recentScans.length,
        ),
      ),
    );
  }
}
