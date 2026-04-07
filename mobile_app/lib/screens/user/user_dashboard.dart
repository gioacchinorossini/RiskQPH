import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';
import 'family_management_screen.dart';
import '../common/hazard_map_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'edit_profile_screen.dart';
import '../common/reported_incidents_screen.dart';
import '../common/profile_tab_sliver.dart';
import '../common/notifications_tab_sliver.dart';
import '../../widgets/safety_overlay.dart';
import '../../widgets/dashboard_info_card.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../providers/notification_provider.dart';
import '../../services/notification_service.dart';
import 'dart:io';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;
  Timer? _scrollThrottleTimer;
  bool _hasBeenCollapsed = false;
  final MapController _previewMapController = MapController();
  LatLng? _previewLocation;

  // Disaster Mode State
  Map<String, dynamic>? _activeDisaster;
  bool _isSafeReported = false;
  bool _isAlertMinimized = false;
  HttpClient? _sseClient;
  HttpClient? _residentsSseClient;
  List<dynamic> _residents = [];
  bool _hasFetchedResidents = false;
  bool _isLoadingFamily = false;
  Set<String> _familyUserIds = {};
  List<Map<String, dynamic>> _userReports = [];
  static final Set<String> _notifiedIncidents = {};
  LatLng? _hqLocation;
  List<dynamic> _evacuationCenters = [];

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
      final notificationProvider = Provider.of<NotificationProvider>(
        context,
        listen: false,
      );
      notificationProvider.addDummyData();
      notificationProvider.addListener(_onNotificationUpdate);
      notificationProvider.connect();
      _checkNotificationPermissions();
      _determinePreviewPosition();
      _fetchHqLocation();
      _fetchFamilyMembers();
      _fetchReports();
      _fetchResidents();
      _fetchEvacuationCenters();
      _checkDisaster();
      _startDisasterStream();
    });
  }

  Future<void> _checkNotificationPermissions() async {
    final granted = await NotificationService.checkPermissions();
    if (!granted && mounted) {
      _showPermissionDialog();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _sseClient?.close(force: true);
    _residentsSseClient?.close(force: true);
    _scrollThrottleTimer?.cancel();
    // Use a try-catch to safely remove listener during disposal
    try {
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).removeListener(_onNotificationUpdate);
    } catch (_) {}
    super.dispose();
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
        // User requested 500km (500,000 meters)
        withinRange = distance < 500000;
      }

      // Past 1 day filter
      final bool isTooOld = DateTime.now().difference(n.time).inDays >= 1;

      if (withinRange && !isTooOld) {
        _showHazardAlertWindow(n, distance);
        NotificationService.showNotification(
          id: n.id.hashCode,
          title: n.title,
          body: n.desc,
        );
        // Refresh the local hazard list so the map and feeds update live
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
                    'NEARBY HAZARD ALERT',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'PROXIMITY WARNING',
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
                          ? 'Hazard $distanceStr away. Move with caution.'
                          : 'Hazardous incident logged in your territory.',
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
                  _selectedIndex = 1;
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
          'STAY ALERT & SECURE',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_active_outlined,
              size: 64,
              color: Color(0xFFB71C1C),
            ),
            SizedBox(height: 16),
            Text(
              'Your safety depends on real-time awareness. Enable notifications to receive immediate alerts when hazardous incidents are reported near your current location.',
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
              backgroundColor: const Color(0xFFB71C1C),
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

  Future<void> _fetchFamilyMembers() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _isLoadingFamily = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/family?headId=${user.id}'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> members = data['members'] as List;
        setState(() {
          _familyUserIds = members
              .where((m) => m['userId'] != null)
              .map((m) => m['userId'].toString())
              .toSet();
          _isLoadingFamily = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching family: $e');
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

  void _startDisasterStream() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null || user.barangay == null) return;

    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/disaster/events?barangay=${user.barangay}',
    );

    _sseClient?.close(force: true);
    _sseClient = HttpClient();

    Future.microtask(() async {
      try {
        final request = await _sseClient!.getUrl(url);
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
                  try {
                    final data = jsonDecode(line.substring(6));
                    if (mounted) {
                      setState(() {
                        if (data['isActive'] == true) {
                          _activeDisaster = data['disaster'];
                          if (!_hasFetchedResidents) {
                            _fetchResidents();
                          }
                          _startResidentsStream();
                          _isSafeReported = false;
                        } else {
                          _activeDisaster = null;
                          _residents = [];
                          _hasFetchedResidents = false;
                          _residentsSseClient?.close(force: true);
                          _isSafeReported = false;
                        }
                      });
                    }
                  } catch (e) {
                    debugPrint('Error parsing SSE data: $e');
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

  Future<void> _fetchReports() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/reports'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _userReports = data.where((r) => r['isResolved'] == false).map((r) {
            final lat = double.parse(r['latitude'].toString());
            final lng = double.parse(r['longitude'].toString());
            return {
              'id': r['id'].toString(),
              'type': r['type'],
              'desc': r['description'],
              'pos': LatLng(lat, lng),
              'latitude': lat,
              'longitude': lng,
              'isResolved': r['isResolved'],
              'createdAt': r['createdAt'],
            };
          }).toList();
        });
        _checkIncidentProximity();
      }
    } catch (_) {}
  }

  void _checkIncidentProximity() {
    if (_previewLocation == null || _userReports.isEmpty) return;

    final notificationProvider = Provider.of<NotificationProvider>(
      context,
      listen: false,
    );

    for (var report in _userReports) {
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

      if (isWithinRange && !isTooOld &&
          !_notifiedIncidents.contains(report['id'].toString())) {
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
            id: report['id'].toString(),
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

        _notifiedIncidents.add(report['id'].toString());

        // Also trigger a system push notification so it shows even outside the app
        NotificationService.showNotification(
          id: report['id'].toString().hashCode,
          title: 'Nearby $type Alert',
          body: 'Hazard reported ${distance.toInt()}m away. Move with caution.',
        );

        // Only show the intrusive SnackBar if the incident was reported within the last 5 minutes
        final bool isFresh =
            DateTime.now().difference(reportedTime).inMinutes <= 5;

        // Also show a SnackBar for localized real-time alert (only if fresh)
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
        final List<dynamic> formatted = data['residents'];
        if (mounted) {
          setState(() {
            _residents = formatted;
            _hasFetchedResidents = true;

            final currentUser = Provider.of<AuthProvider>(
              context,
              listen: false,
            ).currentUser;
            if (currentUser != null) {
              final me = formatted
                  .where((r) => r['id'].toString() == currentUser.id.toString())
                  .firstOrNull;
              if (me != null && me['isSafe'] == true) {
                _isSafeReported = true;
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching residents: $e');
    }
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

                      if (residentData['id'].toString() == user.id.toString()) {
                        if (residentData['isSafe'] == true) {
                          _isSafeReported = true;
                        }
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
          '${ApiConfig.baseUrl}/api/disaster?barangay=${user.barangay}&userId=${user.id}',
        ),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['disaster'] != null) {
          if (mounted) {
            setState(() {
              _activeDisaster = data['disaster'];
              _isSafeReported = data['disaster']['isSafe'] == true;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _activeDisaster = null;
              _isSafeReported = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking disaster: $e');
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

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final bool isVerified = user?.barangayMemberStatus == 'verified';
    final bool isActive =
        _activeDisaster != null && user?.role == UserRole.resident;

    // Unverified theme takes priority: Yellow
    final primaryColor = !isVerified
        ? Colors.amber.shade700
        : (isActive
              ? (_isSafeReported ? Colors.green : Colors.red)
              : AppTheme.primaryColor);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildMainContent(user, primaryColor),
          if (_activeDisaster != null &&
              !_isSafeReported &&
              user?.role == UserRole.resident &&
              isVerified) ...[
            if (!_isAlertMinimized)
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.7)),
              ),
            Positioned(
              top: _isAlertMinimized ? null : 0,
              bottom: _isAlertMinimized ? 80 : 0,
              left: 0,
              right: 0,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isAlertMinimized ? 16 : 32,
                  ),
                  child: SafetyOverlay(
                    userId: user!.id,
                    disasterId: _activeDisaster!['id'],
                    disasterType: _activeDisaster!['type'] ?? 'Emergency',
                    isMinimized: _isAlertMinimized,
                    onToggleMinimized: () {
                      setState(() => _isAlertMinimized = !_isAlertMinimized);
                    },
                    onMarkedSafe: () {
                      setState(() => _isSafeReported = true);
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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
    final double sliverAppBarHeight = screenHeight * 1.0;
    final bool isVerified = user?.barangayMemberStatus == 'verified';

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
    } else if (is600PLUS) {
      maxQrSize = (sliverAppBarHeight * 0.40).clamp(10, 50);
    } else if (is400PLUS) {
      maxQrSize = (sliverAppBarHeight * 0.40).clamp(150, 250);
    } else if (is300PLUS) {
      maxQrSize = (sliverAppBarHeight * 0.30).clamp(180, 200);
    } else {
      maxQrSize = (sliverAppBarHeight * 0.40).clamp(150, 250);
    }

    double qrSize;
    double finalCollapsedSize;
    if (is700PLUS) {
      if (screenHeight > 700) {
        finalCollapsedSize = maxQrSize * 0.6;
      } else if (screenHeight > 500) {
        finalCollapsedSize = maxQrSize * 0.3;
      } else {
        finalCollapsedSize = maxQrSize * 0.5;
      }
    } else if (is500PLUS) {
      finalCollapsedSize = maxQrSize * 0.4;
    } else if (is400PLUS) {
      if (screenHeight > 730) {
        finalCollapsedSize = maxQrSize * 0.4;
      } else if (screenHeight > 700) {
        finalCollapsedSize = maxQrSize * 0.3;
      } else if (screenHeight > 600) {
        finalCollapsedSize = maxQrSize * 0.3;
      } else if (screenHeight > 500) {
        finalCollapsedSize = maxQrSize * 0.3;
      } else {
        finalCollapsedSize = maxQrSize * 0.4;
      }
    } else if (is300PLUS) {
      finalCollapsedSize = maxQrSize * 0.4;
    } else {
      finalCollapsedSize = maxQrSize * 0.4;
    }

    if (_hasBeenCollapsed) {
      qrSize = finalCollapsedSize;
    } else {
      if (is600PLUS) {
        qrSize =
            maxQrSize -
            (_scrollOffset * 0.4).clamp(0, maxQrSize - finalCollapsedSize);
      } else if (is500PLUS) {
        qrSize =
            maxQrSize -
            (_scrollOffset * 0.35).clamp(0, maxQrSize - finalCollapsedSize);
      } else if (is300PLUS) {
        qrSize =
            maxQrSize -
            (_scrollOffset * 0.3).clamp(0, maxQrSize - finalCollapsedSize);
      } else if (is700PLUS) {
        qrSize =
            maxQrSize -
            (_scrollOffset * 0.25).clamp(0, maxQrSize - finalCollapsedSize);
      } else {
        qrSize =
            maxQrSize -
            (_scrollOffset * 0.3).clamp(0, maxQrSize - finalCollapsedSize);
      }
    }

    double startingTopPosition;
    if (is700PLUS) {
      if (screenHeight > 1200) {
        startingTopPosition = (screenHeight * 0.50).clamp(200, 400);
      } else if (screenHeight > 400) {
        startingTopPosition = (screenHeight * 0.50).clamp(200, 200);
      } else {
        startingTopPosition = (screenHeight * 0.50).clamp(50, 50);
      }
    } else if (is500PLUS) {
      if (screenHeight > 700) {
        startingTopPosition = (screenHeight * 0.20).clamp(150, 150);
      } else {
        startingTopPosition = (screenHeight * 0.50).clamp(150, 300);
      }
    } else if (is400PLUS) {
      startingTopPosition = (screenHeight * 0.50).clamp(200, 250);
    } else if (is300PLUS) {
      if (screenHeight > 700) {
        startingTopPosition = (screenHeight * 0.20).clamp(150, 150);
      } else if (screenHeight > 600) {
        startingTopPosition = (screenHeight * 0.20).clamp(150, 150);
      } else if (screenHeight > 500) {
        startingTopPosition = (screenHeight * 0.50).clamp(150, 300);
      } else {
        startingTopPosition = (screenHeight * 0.50).clamp(150, 300);
      }
    } else {
      startingTopPosition = (screenHeight * 0.50).clamp(100, 150);
    }

    final double collapsedHeight = screenHeight * 0.15;
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
    final double finalLeftPosition;
    if (is600PLUS) {
      finalLeftPosition = 80.0;
    } else if (is500PLUS) {
      finalLeftPosition = 60.0;
    } else {
      finalLeftPosition = 40.0;
    }

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
          'RiskQPH',
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
              _fetchReports();
              _checkDisaster();
              _fetchFamilyMembers();
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: isVerified
                  ? const AlwaysScrollableScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: _hasBeenCollapsed
                      ? screenHeight * 0.15
                      : screenHeight * 1.0,
                  collapsedHeight: screenHeight * 0.15,
                  pinned: true,
                  floating: false,
                  backgroundColor: primaryColor,
                  shape: const ContinuousRectangleBorder(
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
                if (_selectedIndex == 0) _buildEventsSliver(primaryColor),
                if (_selectedIndex == 1) const NotificationsTabSliver(),
                if (_selectedIndex == 2)
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
                        'Welcome',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (qrSize * 0.10).clamp(16, 40),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: qrSize * 0.02),
                      Text(
                        !isVerified
                            ? 'YOUR ACCOUNT IS UNVERIFIED. Please wait for the barangay head to verify your membership.'
                            : 'Your personal QR code is ready for situational awareness. Simply present this code to rescue personnel.',
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
                            child: _buildResidentQRCode(
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
                                user?.name ?? 'Profile Name',
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
                                user?.barangay != null
                                    ? 'Brgy. ${user!.barangay}'
                                    : 'N/A',
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
                      child: _buildResidentQRCode(
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
                    user?.name ?? 'User Name',
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
                    user?.barangay != null ? 'Brgy. ${user!.barangay}' : 'N/A',
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
          if (_scrollOffset < 10 && !_hasBeenCollapsed && isVerified) ...[
            Positioned(
              top: sliverAppBarHeight - (qrSize * 1.2),
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _scrollOffset < 10 ? 1.0 : 0.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          'Swipe up to explore',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
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
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _hasBeenCollapsed = false;
                    });
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
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
          ],
        ],
      ),
      bottomNavigationBar: (_scrollOffset > 50 || _hasBeenCollapsed)
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              selectedItemColor: primaryColor,
              onTap: (index) => setState(() => _selectedIndex = index),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications_none),
                  label: 'Notifications',
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

  Widget _buildEventsSliver(Color primaryColor) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final bool isVerified = user?.barangayMemberStatus == 'verified';
    final bool isActive = _activeDisaster != null;
    final List<dynamic> verifiedResidents = _residents
        .where(
          (r) =>
              (r['barangayMemberStatus'] == 'verified' ||
              r['barangayMemberStatus'] == null),
        )
        .toList();
    final int missingCount = verifiedResidents
        .where((r) => r['isSafe'] == false)
        .length;

    final double screenWidth = MediaQuery.of(context).size.width;
    final double itemWidth = (screenWidth - 32) / 4;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Container(
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReportedIncidentsScreen(),
                      ),
                    ).then((_) => _fetchReports());
                  },
                ),
                _buildQuickActionItem(
                  width: itemWidth,
                  icon: Icons.edit_note,
                  label: 'Edit Profile',
                  color: Colors.blue,
                  onTap: !isVerified
                      ? () {}
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditProfileScreen(),
                          ),
                        ),
                ),
                _buildQuickActionItem(
                  width: itemWidth,
                  icon: Icons.family_restroom_outlined,
                  label: 'Add Family',
                  color: Colors.indigo,
                  onTap: !isVerified
                      ? () {}
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const FamilyManagementScreen(),
                          ),
                        ),
                ),
                _buildQuickActionItem(
                  width: itemWidth,
                  icon: Icons.person_outline,
                  label: 'Profile',
                  color: Colors.teal,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isActive
                  ? (_isSafeReported
                        ? Colors.green.shade50
                        : Colors.red.shade50)
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? (_isSafeReported
                          ? Colors.green.shade200
                          : Colors.red.shade200)
                    : Colors.green.shade200,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      isActive
                          ? (_isSafeReported
                                ? Icons.check_circle
                                : Icons.warning_amber_rounded)
                          : Icons.shield_outlined,
                      color: isActive
                          ? (_isSafeReported ? Colors.green : Colors.red)
                          : Colors.green,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isActive
                              ? (_isSafeReported
                                    ? 'STATUS: SAFE'
                                    : 'EMERGENCY ACTIVE')
                              : 'DISASTER ALERT: OFF',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? (_isSafeReported ? Colors.green : Colors.red)
                                : Colors.green,
                          ),
                        ),
                        Text(
                          isActive
                              ? (_isSafeReported
                                    ? 'You have checked in as safe.'
                                    : '$missingCount residents missing.')
                              : 'All residents safe.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive
                                ? (_isSafeReported
                                      ? Colors.green[700]
                                      : Colors.red[700])
                                : Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1.5,
                    child: _buildHazardMapPreview(primaryColor),
                  ),
                ),
                if (isActive && _residents.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_isSafeReported ? Colors.green : Colors.red)
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      (_activeDisaster!['description'] != null &&
                              _activeDisaster!['description']
                                  .toString()
                                  .trim()
                                  .isNotEmpty)
                          ? _activeDisaster!['description']
                          : 'Disaster ongoing. Please stay safe and follow official instructions.',
                      style: TextStyle(
                        color: (_isSafeReported
                            ? Colors.green[900]
                            : Colors.red[900]),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isActive && _residents.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Missing People',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
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
                        const Text(
                          'Total residents currently missing or in need of assistance.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: verifiedResidents.isEmpty
                                ? 0
                                : (missingCount / verifiedResidents.length),
                            backgroundColor: Colors.red.withOpacity(0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.red,
                            ),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$missingCount / ${verifiedResidents.length}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          DashboardInfoCard(
            isDisabled: !isVerified,
            icon: Icons.people_outline,
            title: 'Registered Residents',
            value: '${verifiedResidents.length}',
            subtext:
                'In Brgy. ${Provider.of<AuthProvider>(context).currentUser?.barangay ?? "N/A"}',
            iconColor: Colors.blue,
          ),
          DashboardInfoCard(
            isDisabled: !isVerified,
            icon: Icons.emergency_outlined,
            title: 'Active Evacuation Centers',
            value: '${_evacuationCenters.length}',
            subtext: _evacuationCenters.isEmpty
                ? 'No centers active'
                : 'Current sanctuary locations.',
            iconColor: Colors.green,
            onTap: () {
              // Maybe navigate to a dedicated screen or the map
            },
          ),
          const SizedBox(height: 100),
        ]),
      ),
    );
  }

  Widget _buildHazardMapPreview(Color primaryColor) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const HazardMapScreen())),
      child: AbsorbPointer(
        child: FlutterMap(
          mapController: _previewMapController,
          options: const MapOptions(
            initialCenter: LatLng(14.5995, 120.9842),
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName:
                  'RiskQPH/1.0 (ph.gov.riskqph.mobile; contact: admin@riskqph.ph)',
            ),
            MarkerLayer(
              markers: [
                if (_previewLocation != null)
                  Marker(
                    point: _previewLocation!,
                    width: 45,
                    height: 45,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent, width: 2),
                      ),
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blueAccent,
                        size: 30,
                      ),
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
                ..._residents
                    .where(
                      (r) =>
                          r['latitude'] != null &&
                          r['longitude'] != null &&
                          (r['barangayMemberStatus'] == 'verified' ||
                              r['barangayMemberStatus'] == null),
                    )
                    .map((r) {
                      final bool isActive = _activeDisaster != null;
                      final bool isSafeNow = (r['isSafe'] == true);
                      final bool hasSOS = (r['hasResponded'] == true);
                      final Color markerColor = !isActive
                          ? AppTheme.primaryColor
                          : (isSafeNow
                                ? Colors.green
                                : (hasSOS ? Colors.red : Colors.grey));

                      return Marker(
                        point: LatLng(
                          (r['latitude'] as num).toDouble(),
                          (r['longitude'] as num).toDouble(),
                        ),
                        width: 15,
                        height: 15,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: markerColor, width: 1),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 2,
                                color: markerColor.withOpacity(0.3),
                              ),
                            ],
                          ),
                          child: Icon(
                            (isActive && isSafeNow)
                                ? Icons.check_circle
                                : Icons.person_pin_circle,
                            color: markerColor,
                            size: 8,
                          ),
                        ),
                      );
                    }),
                ..._userReports.map((r) {
                  final color = _disasterColors[r['type']] ?? Colors.red;
                  return Marker(
                    point: r['pos'] as LatLng,
                    width: 25,
                    height: 25,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(blurRadius: 4, color: Colors.black26),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResidentQRCode(User? user, double size, Color color) {
    if (user == null) return Container();
    final bool isVerified = user.barangayMemberStatus == 'verified';

    if (!isVerified) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade200, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_person_rounded,
              color: Colors.amber.shade700,
              size: size * 0.4,
            ),
            const SizedBox(height: 8),
            Text(
              'PENDING',
              style: TextStyle(
                color: Colors.amber.shade900,
                fontSize: (size * 0.08).clamp(10, 14),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );
    }

    final qrPayload = jsonEncode({'studentId': user.id});
    final qrData = base64Encode(utf8.encode(qrPayload));
    return QrImageView(
      data: qrData,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      foregroundColor: color,
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required double width,
  }) {
    final bool isVerified =
        Provider.of<AuthProvider>(
          context,
          listen: false,
        ).currentUser?.barangayMemberStatus ==
        'verified';
    final Color displayColor = isVerified ? color : Colors.grey;
 
    return InkWell(
      onTap: isVerified ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: displayColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: displayColor, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isVerified ? Colors.grey[800] : Colors.grey[400],
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

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await Provider.of<AuthProvider>(context, listen: false).logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }
}

class _MissingListScreen extends StatefulWidget {
  final String barangay;
  final String disasterId;

  const _MissingListScreen({required this.barangay, required this.disasterId});

  @override
  State<_MissingListScreen> createState() => _MissingListScreenState();
}

class _MissingListScreenState extends State<_MissingListScreen> {
  List<dynamic> _residents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchResidents();
  }

  Future<void> _fetchResidents() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/barangay/residents?barangay=${widget.barangay}&disasterId=${widget.disasterId}',
        ),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _residents = data['residents'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching residents: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final missing = _residents.where((r) => r['isSafe'] == false).toList();
    final safe = _residents.where((r) => r['isSafe'] == true).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resident Safety Status'),
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(text: 'MISSING (${missing.length})'),
                      Tab(text: 'SAFE (${safe.length})'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildList(missing, isMissing: true),
                        _buildList(safe, isMissing: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildList(List<dynamic> list, {required bool isMissing}) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isMissing ? 'No missing residents' : 'No residents marked safe yet',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final r = list[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isMissing
                ? Colors.red.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
            child: Icon(
              isMissing ? Icons.person_off : Icons.check_circle,
              color: isMissing ? Colors.red : Colors.green,
            ),
          ),
          title: Text('${r['firstName']} ${r['lastName']}'),
          subtitle: isMissing
              ? const Text(
                  'Last seen: Unknown',
                  style: TextStyle(color: Colors.red),
                )
              : Text(
                  'Marked safe: ${r['safetyStatus'][0]['updatedAt'] != null ? DateFormat('hh:mm a').format(DateTime.parse(r['safetyStatus'][0]['updatedAt']).toLocal()) : 'N/A'}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        );
      },
    );
  }
}
