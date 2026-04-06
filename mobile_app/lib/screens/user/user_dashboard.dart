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
            return {
              'type': r['type'],
              'desc': r['description'],
              'pos': LatLng(
                double.parse(r['latitude'].toString()),
                double.parse(r['longitude'].toString()),
              ),
              'isResolved': r['isResolved'],
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching reports for preview: $e');
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

  @override
  void dispose() {
    _sseClient?.close(force: true);
    _residentsSseClient?.close(force: true);
    _scrollController.dispose();
    _scrollThrottleTimer?.cancel();
    super.dispose();
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
    final primaryColor =
        (_activeDisaster != null &&
            !_isSafeReported &&
            user?.role == UserRole.resident)
        ? Colors.red
        : AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildMainContent(user, primaryColor),
          if (_activeDisaster != null &&
              !_isSafeReported &&
              user?.role == UserRole.resident) ...[
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
              physics: const AlwaysScrollableScrollPhysics(),
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
                        'Your personal QR code is ready for situational awareness. Simply present this code to rescue personnel.',
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
                            child: _buildOfflineQRCode(user, qrSize * 0.9),
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
                  : Center(child: _buildOfflineQRCode(user, qrSize * 0.9)),
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
          if (_scrollOffset < 10 && !_hasBeenCollapsed) ...[
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

  Widget _buildEventsSliver(Color primaryColor) {
    final bool isActive = _activeDisaster != null;
    final int missingCount = _residents
        .where((r) => r['isSafe'] == false)
        .length;

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
              alignment: WrapAlignment.spaceEvenly,
              spacing: 12,
              runSpacing: 16,
              children: [
                _buildQuickActionItem(
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
                  icon: Icons.edit_note,
                  label: 'Edit Profile',
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfileScreen(),
                    ),
                  ),
                ),
                _buildQuickActionItem(
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
              color: isActive ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? Colors.red.shade200 : Colors.green.shade200,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isActive ? 'EMERGENCY ACTIVE' : 'DISASTER ALERT:OFF',
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
                      color: Colors.red.withOpacity(0.08),
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
                        color: Colors.red[900],
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
          if (_residents.isNotEmpty) ...[
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
                            value: _residents.isEmpty
                                ? 0
                                : (missingCount / _residents.length),
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
                            '$missingCount / ${_residents.length}',
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
                      (r) => r['latitude'] != null && r['longitude'] != null,
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

  Widget _buildOfflineQRCode(User? user, double size) {
    if (user == null) return Container();
    final qrPayload = jsonEncode({'studentId': user.id});
    final qrData = base64Encode(utf8.encode(qrPayload));
    return QrImageView(
      data: qrData,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.primaryColor,
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 65,
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
