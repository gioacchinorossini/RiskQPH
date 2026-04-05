import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/user.dart';
import '../../models/event.dart';
import '../common/hazard_map_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../user/edit_profile_screen.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../widgets/view_on_map_button.dart';

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

  // Disaster Mode State
  Map<String, dynamic>? _activeDisaster;
  List<dynamic> _residents = [];
  HttpClient? _disasterSseClient;
  HttpClient? _residentsSseClient;

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
      _determinePreviewPosition();
      _checkDisaster(); // Initial check
      _fetchHqLocation(); // Initial check
      _startDisasterStream();
    });
  }

  Future<void> _fetchHqLocation() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null || user.barangay == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/barangay/location?name=${user.barangay}'),
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

    final url = Uri.parse('${ApiConfig.baseUrl}/api/disaster/events?barangay=${user.barangay}');
    
    _disasterSseClient?.close(force: true);
    _disasterSseClient = HttpClient();
    
    Future.microtask(() async {
      try {
        final request = await _disasterSseClient!.getUrl(url);
        request.headers.set('Accept', 'text/event-stream');
        request.headers.set('Cache-Control', 'no-cache');
        request.headers.set('ngrok-skip-browser-warning', 'true');
        
        final response = await request.close();
        response.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
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
        }, onDone: () {
          if (mounted) Future.delayed(const Duration(seconds: 5), _startDisasterStream);
        });
      } catch (e) {
        if (mounted) Future.delayed(const Duration(seconds: 10), _startDisasterStream);
      }
    });
  }

  void _startResidentsStream() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (_activeDisaster == null || user?.barangay == null) return;

    final url = Uri.parse('${ApiConfig.baseUrl}/api/barangay/residents/events?barangay=${user!.barangay}');
    
    _residentsSseClient?.close(force: true);
    _residentsSseClient = HttpClient();
    
    Future.microtask(() async {
      try {
        final request = await _residentsSseClient!.getUrl(url);
        request.headers.set('Accept', 'text/event-stream');
        request.headers.set('Cache-Control', 'no-cache');
        request.headers.set('ngrok-skip-browser-warning', 'true');
        
        final response = await request.close();
        response.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
          if (line.trim().isEmpty) return;
          if (line.startsWith('data: ')) {
            final residentData = jsonDecode(line.substring(6));
            if (mounted) {
              setState(() {
                final index = _residents.indexWhere((r) => r['id'] == residentData['id']);
                if (index != -1) {
                  _residents[index] = residentData;
                } else {
                  _residents.add(residentData);
                }
              });
            }
          }
        }, onDone: () {
          if (mounted && _activeDisaster != null) {
            Future.delayed(const Duration(seconds: 5), _startResidentsStream);
          }
        });
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
        Uri.parse('${ApiConfig.baseUrl}/api/disaster?barangay=${user.barangay}'),
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
    if (_activeDisaster == null || user?.barangay == null) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/barangay/residents?barangay=${user!.barangay}&disasterId=${_activeDisaster!['id']}'),
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

  @override
  void dispose() {
    _disasterSseClient?.close(force: true);
    _residentsSseClient?.close(force: true);
    _scrollController.dispose();
    _scrollThrottleTimer?.cancel();
    _previewMapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    // Theme color for Responder: TEAL
    final Color primaryDashboardColor = const Color(0xFF006064);

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
      qrSize = maxQrSize - (_scrollOffset * 0.3).clamp(0, maxQrSize - finalCollapsedSize);
    }
    
    double startingTopPosition = (screenHeight * 0.50).clamp(200, 250);
    final double collapsedHeight = MediaQuery.of(context).size.height * 0.15;
    final double maxUpwardMovement = startingTopPosition - (collapsedHeight * 0.1);
    
    double qrTopPosition;
    if (_hasBeenCollapsed) {
      qrTopPosition = collapsedHeight * 0.1;
    } else {
      qrTopPosition = startingTopPosition - (_scrollOffset * 0.3).clamp(0, maxUpwardMovement);
    }

    final double maxScrollForLeftTransition = 300.0;
    final double centeredExpandedLeft = (screenWidth - qrSize) / 2;
    final double finalLeftPosition = is600PLUS ? 80.0 : 40.0;

    double qrHorizontalPosition;
    if (_hasBeenCollapsed) {
      qrHorizontalPosition = finalLeftPosition;
    } else if (_scrollOffset <= maxScrollForLeftTransition) {
      double t = _scrollOffset / maxScrollForLeftTransition;
      qrHorizontalPosition = centeredExpandedLeft * (1 - t) + finalLeftPosition * t;
    } else {
      qrHorizontalPosition = finalLeftPosition;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text('RESPONDER UNIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              final eventProvider = Provider.of<EventProvider>(context, listen: false);
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
                  child: Container(
                    height: 0,
                    color: Colors.transparent,
                  ),
                ),
                if (_selectedIndex == 0) _buildAdminMainSliver(primaryColor),
                if (_selectedIndex == 1) _buildAttendanceHistorySliver(),
                if (_selectedIndex == 2) _buildProfileSliver(user, primaryColor),
              ],
            ),
          ),
          
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
                            child: _buildAdminQRCode(user, qrSize * 0.9, primaryColor),
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
                  : Center(child: _buildAdminQRCode(user, qrSize * 0.9, primaryColor)),
            ),
          ),
          
          if (_scrollOffset <= 200 && !_hasBeenCollapsed) ...[
            Positioned(
              top: (qrTopPosition + qrSize + 20 - (_scrollOffset * 0.3).clamp(0, 40)).clamp(
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
                      Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 40),
                      Text(
                        'SWIPE UP TO MANAGE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
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
                      _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
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
                BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
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
        final visibleEvents = eventProvider.getStudentVisibleEvents();
        final isActive = _activeDisaster != null;
        final missingCount = _residents.where((r) => r['isSafe'] == false).length;

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
                  border: Border.all(color: isActive ? Colors.red.shade200 : Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(isActive ? Icons.warning_amber_rounded : Icons.shield_outlined, 
                             color: isActive ? Colors.red : Colors.green, size: 32),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isActive ? 'EMERGENCY ACTIVE' : 'SYSTEM STATUS: SAFE', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.red : Colors.green)),
                            Text(isActive ? '$missingCount residents missing.' : 'All systems monitoring active.', 
                              style: TextStyle(fontSize: 12, color: isActive ? Colors.red[700] : Colors.green[700])),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildHazardMapPreview(primaryColor),
                    ),
                    if (isActive && _residents.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Safety Progress', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('${((_residents.where((r) => r['isSafe'] == true).length / _residents.length) * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _residents.where((r) => r['isSafe'] == true).length / _residents.length,
                          backgroundColor: Colors.red.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                          minHeight: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              if (isActive && _residents.any((r) => r['isSafe'] == false)) ...[
                const SizedBox(height: 24),
                _buildRescueRequestsList(),
              ],
              
              const SizedBox(height: 24),
              const SizedBox(height: 12),

              const SizedBox(height: 24),
              Text(
                'Upcoming Events',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (visibleEvents.isEmpty)
                _buildEmptyState(Icons.event_busy, 'No upcoming events')
              else
                ...visibleEvents.map((event) => _buildEventCard(event)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsGrid(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickActionItem(
                icon: Icons.qr_code_scanner, 
                label: 'Scan QR', 
                color: Colors.blue, 
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('QR Scanner coming soon...'))
                  );
                }
              ),
              _buildQuickActionItem(
                icon: Icons.list_alt, 
                label: 'View List', 
                color: Colors.green, 
                onTap: () => Navigator.pushNamed(context, '/resident_list'),
              ),
              _buildQuickActionItem(
                icon: Icons.edit_note, 
                label: 'Edit Profile', 
                color: Colors.orange, 
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRescueRequestsList() {
    final rescueRequests = _residents.where((r) => r['isSafe'] == false).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Rescue Request List',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${rescueRequests.length} ALERT',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
              final String name = '${resident['firstName'] ?? ""} ${resident['lastName'] ?? ""}'.trim();
              
              // Handle timestamp
              String timeStr = 'N/A';
              try {
                if (resident['updatedAt'] != null) {
                  final dt = DateTime.parse(resident['updatedAt']);
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
                    )
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
                      child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name.isEmpty ? 'Unknown' : name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'GPS: $timeStr',
                      style: TextStyle(color: Colors.red.shade900, fontSize: 9, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      resident['hasResponded'] == true ? 'REQUESTED RESCUE' : 'NOT RESPONDING',
                      style: TextStyle(
                        color: resident['hasResponded'] == true ? Colors.red.shade900 : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ViewOnMapButton(residents: _residents, resident: resident, isPrimary: true),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildHazardMapPreview(Color primaryColor) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => HazardMapScreen(
          residentsToRescue: _residents.cast<Map<String, dynamic>>(),
        ),
      )),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              AbsorbPointer(
                child: FlutterMap(
                  mapController: _previewMapController,
                  options: const MapOptions(initialCenter: LatLng(14.5995, 120.9842), initialZoom: 15),
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
                    MarkerLayer(
                      markers: [
                        if (_previewLocation != null)
                          Marker(
                            point: _previewLocation!,
                            width: 30,
                            height: 30,
                            child: const Icon(Icons.my_location, color: Colors.blue, size: 20),
                          ),
                        if (_hqLocation != null)
                          Marker(
                            point: _hqLocation!,
                            width: 60,
                            height: 60,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white, width: 1),
                                  ),
                                  child: const Icon(Icons.account_balance, color: Colors.white, size: 14),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'BRGY HQ',
                                    style: TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ..._residents.map((r) {
                          final isSafe = r['isSafe'] == true;
                          if (r['latitude'] == null || r['longitude'] == null) return const Marker(point: LatLng(0,0), child: SizedBox.shrink());
                          final color = isSafe ? Colors.green : (r['hasResponded'] == true ? Colors.red : Colors.redAccent);
                          
                          return Marker(
                            point: LatLng(r['latitude'], r['longitude']),
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSafe ? Colors.green : (r['hasResponded'] == true ? Colors.red : Colors.white), 
                                shape: BoxShape.circle, 
                                border: Border.all(color: color, width: 1.5), 
                                boxShadow: [BoxShadow(blurRadius: 4, color: color.withOpacity(0.3))]
                              ),
                              child: Icon(
                                isSafe ? Icons.check : (r['hasResponded'] == true ? Icons.sos : Icons.warning), 
                                color: (isSafe || r['hasResponded'] == true) ? Colors.white : Colors.red, 
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

  Widget _buildEventCard(Event event) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.event_note, color: Colors.teal),
        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(dateFormat.format(event.startTime)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
     return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildAttendanceHistorySliver() {
    return const SliverToBoxAdapter(child: Center(child: Padding(
      padding: EdgeInsets.all(40.0),
      child: Text('Unit response logs and incident reports ready.'),
    )));
  }

  Widget _buildProfileSliver(User? user, Color color) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
           _buildProfileItem(Icons.badge, 'Full Name', user?.name ?? 'Responder'),
           _buildProfileItem(Icons.location_on, 'Assigned Barangay', user?.barangay ?? 'N/A'),
           _buildProfileItem(Icons.security, 'Access Level', 'Responder Unit'),
           const SizedBox(height: 24),
           ElevatedButton(
            onPressed: _handleLogout,
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
            child: const Text('LOGOUT TERMINAL'),
           ),
        ]),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
