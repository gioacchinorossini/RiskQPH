import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/survey.dart';
import '../../providers/survey_provider.dart';
import '../../models/user.dart';
import '../../models/event.dart';
import '../../utils/theme.dart';
import 'qr_code_screen.dart';
import 'attendance_history_screen.dart';
import 'take_survey_screen.dart';
import 'family_management_screen.dart';
import '../common/hazard_map_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'edit_profile_screen.dart';
import '../../widgets/safety_overlay.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

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
  Timer? _disasterCheckTimer;
  Map<String, dynamic>? _activeDisaster;
  bool _isSafeReported = false;
  bool _isCheckingSafety = false;

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
      _startDisasterCheck();
    });
  }

  void _startDisasterCheck() {
    _disasterCheckTimer?.cancel();
    _disasterCheckTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) _checkDisaster();
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
        if (data['disaster'] != null) {
          if (mounted) {
            setState(() {
              _activeDisaster = data['disaster'];
            });
            _checkIfAlreadySafe(user.id, data['disaster']['id']);
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

  Future<void> _checkIfAlreadySafe(String userId, String disasterId) async {
    if (_isSafeReported || _isCheckingSafety) return;
    _isCheckingSafety = true;
    try {
      // We'll use the residents API or a specific safety check API
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/barangay/residents?barangay=${Provider.of<AuthProvider>(context, listen: false).currentUser?.barangay}&disasterId=$disasterId'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final residents = data['residents'] as List;
        final me = residents.firstWhere((r) => r['id'] == userId, orElse: () => null);
        if (me != null && me['isSafe'] == true) {
          if (mounted) setState(() => _isSafeReported = true);
        }
      }
    } catch (e) {
      debugPrint('Error checking safety status: $e');
    } finally {
      _isCheckingSafety = false;
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildMainContent(user),
          if (_activeDisaster != null && !_isSafeReported && user?.role == UserRole.resident)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SafetyOverlay(
                    userId: user!.id,
                    disasterId: _activeDisaster!['id'],
                    disasterType: _activeDisaster!['type'] ?? 'Emergency',
                    onMarkedSafe: () {
                      setState(() => _isSafeReported = true);
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildMainContent(User? user) {
    // Moved the original Scaffold body content here
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    // ... (rest of the size logic)
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
    } else if (is700PLUS) {
      finalCollapsedSize = maxQrSize * 0.3;
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
      } else if (screenHeight > 800) {
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
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text('RiskQPH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              final isConnected = await authProvider.testConnection();
              final eventProvider = Provider.of<EventProvider>(
                context,
                listen: false,
              );
              final attendanceProvider = Provider.of<AttendanceProvider>(
                context,
                listen: false,
              );
              if (isConnected) {
                await Future.wait([
                  eventProvider.loadEvents(),
                  attendanceProvider.loadAttendances(),
                ]);
              } else {
                await Future.wait([
                  eventProvider.loadEventsFromCache(),
                  attendanceProvider.loadAttendances(),
                ]);
              }
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
                  backgroundColor: AppTheme.primaryColor,
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
                    height: qrSize * 0,
                    color: Colors.transparent,
                  ),
                ),
                if (_selectedIndex == 0) _buildEventsSliver(),
                if (_selectedIndex == 1) _buildAttendanceHistorySliver(),
                if (_selectedIndex == 2) _buildProfileSliver(user),
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
                        'Your personal QR code is ready for attendance marking. Simply present this code to event organizers.',
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
                                  color: AppTheme.primaryColor,
                                  fontSize: is600PLUS ? 20 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.barangay != null ? 'Brgy. ${user!.barangay}' : 'N/A',
                                style: TextStyle(
                                  color: AppTheme.primaryColor.withOpacity(0.8),
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
            if (_scrollOffset <= 200 && !_hasBeenCollapsed) ...[
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
          ],
          if (_scrollOffset < 10 && !_hasBeenCollapsed) ...[
            Positioned(
              top: sliverAppBarHeight - (qrSize * 1),
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Material(
                  color: Colors.transparent,
                  elevation: 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: _scrollOffset < 10 ? 1.0 : 0.0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 1500),
                          transform: Matrix4.translationValues(
                            0,
                            _scrollOffset < 10
                                ? (DateTime.now().millisecondsSinceEpoch %
                                              3000 <
                                          1500
                                      ? -8
                                      : 0)
                                : 0,
                            0,
                          ),
                          child: Container(
                            padding: EdgeInsets.all(qrSize * 0.04),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: Colors.white,
                              size: (qrSize * 0.15).clamp(20, 40),
                            ),
                          ),
                        ),
                        SizedBox(height: qrSize * 0.05),
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
                            'Swipe up to explore',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: (qrSize * 0.07).clamp(10, 20),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(height: qrSize * 0.02),
                        Text(
                          'Discover your events and history',
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
                      setState(() {
                        _hasBeenCollapsed = false;
                      });
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.primaryColor,
                        size: 24,
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
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'History',
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

  Widget _buildEventsSliver() {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        if (eventProvider.isLoading) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final visibleEvents = eventProvider.getStudentVisibleEvents();
        final pastEvents = eventProvider.getPastEvents();
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Consumer<AuthProvider>(
                builder: (context, auth, child) {
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 0),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickActionItem(
                          icon: Icons.report_problem_outlined,
                          label: 'Report',
                          color: Colors.red,
                          onTap: () {},
                        ),
                        _buildQuickActionItem(
                          icon: Icons.emergency_outlined,
                          label: 'Emergency',
                          color: Colors.orange,
                          onTap: () {},
                        ),
                        _buildQuickActionItem(
                          icon: Icons.edit_note,
                          label: 'Edit Profile',
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickActionItem(
                          icon: Icons.qr_code_scanner,
                          label: 'QR Scan',
                          color: Colors.purple,
                          onTap: () {},
                        ),
                        _buildQuickActionItem(
                          icon: Icons.history_outlined,
                          label: 'History',
                          color: Colors.teal,
                          onTap: () {
                            setState(() {
                              _selectedIndex = 1;
                            });
                          },
                        ),
                        _buildQuickActionItem(
                          icon: Icons.person_add_outlined,
                          label: 'Add Family',
                          color: Colors.indigo,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const FamilyManagementScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Live Hazard Monitoring',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HazardMapScreen()),
                  );
                },
                child: AspectRatio(
                  aspectRatio: 1,
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
                                      child: const Icon(
                                        Icons.person_pin_circle,
                                        color: Colors.blueAccent,
                                        size: 30,
                                      ),
                                    ),
                                  // Add the main hazard markers for the preview
                                  Marker(
                                    point: const LatLng(14.5995, 120.9842),
                                    width: 30,
                                    height: 30,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                  Marker(
                                    point: const LatLng(10.3157, 123.8854),
                                    width: 30,
                                    height: 30,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                  ),
                                  Marker(
                                    point: const LatLng(7.0736, 125.6128),
                                    width: 30,
                                    height: 30,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.5),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hazard Tracking Active',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Tap to expand full map',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              CircleAvatar(
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.fullscreen,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 15,
                          right: 15,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
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
              ),
              const SizedBox(height: 32),
              const SizedBox(height: 24),
              Text(
                'Available Events',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                'Upcoming and ongoing events (sorted by latest created)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              if (visibleEvents.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No available events',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pull down to refresh and check for new events',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...visibleEvents.map((event) => _buildEventCard(event, true)),
              const SizedBox(height: 24),
              Text(
                'Past Events',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                'Sorted by latest created',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              if (pastEvents.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No past events',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pull down to refresh and check for new events',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...pastEvents.map((event) => _buildEventCard(event, false)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceHistorySliver() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      sliver: const AttendanceHistoryScreen(),
    );
  }

  Widget _buildProfileSliver(User? user) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.name ?? 'Student',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                Text(
                  user?.email ?? 'student@school.com',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Student ID', user?.studentId ?? 'N/A'),
                  _buildInfoRow('Role', 'Student'),
                  _buildInfoRow(
                    'Member Since',
                    user?.createdAt != null
                        ? DateFormat('MMM dd, yyyy').format(user!.createdAt)
                        : 'N/A',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: _handleLogout,
            ),
          ),
          const SizedBox(height: 48),
        ]),
      ),
    );
  }

  Widget _buildEventCard(Event event, bool isUpcoming) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.event,
                            size: 20,
                            color: AppTheme.secondaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              event.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize:
                                        (Theme.of(
                                              context,
                                            ).textTheme.titleMedium?.fontSize ??
                                            16) +
                                        2,
                                    height: 1.15,
                                    letterSpacing: 0.2,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Container(
                          width: double.infinity,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getEventStatusColor(event),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getEventStatusText(event),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  dateFormat.format(event.startTime),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${timeFormat.format(event.startTime)} - ${timeFormat.format(event.endTime)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  event.location,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.create, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Text(
                  'Created: ${dateFormat.format(event.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            if (_isEventActive(event)) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showQRCode(event),
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Get QR Code'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildSurveyButton(event),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSurveyButton(Event event) {
    return Consumer2<AuthProvider, SurveyProvider>(
      builder: (context, auth, surveyProvider, child) {
        final userId = auth.currentUser?.id;
        if (userId == null || userId.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await surveyProvider.loadSurveysForEvent(
                event.id,
                userId: userId,
              );
              final surveys = surveyProvider
                  .surveysForEvent(event.id)
                  .where((s) => s.isActive)
                  .toList();
              if (surveys.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No survey available for this event.'),
                  ),
                );
                return;
              }
              Survey? selected;
              if (surveys.length == 1) {
                selected = surveys.first;
              } else {
                selected = await showDialog<Survey>(
                  context: context,
                  builder: (ctx) {
                    return AlertDialog(
                      title: const Text('Choose a survey'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView(
                          shrinkWrap: true,
                          children: surveys
                              .map(
                                (s) => ListTile(
                                  title: Text(s.title),
                                  subtitle: s.hasSubmitted
                                      ? const Text('Already submitted')
                                      : null,
                                  trailing: s.hasSubmitted
                                      ? const Icon(
                                          Icons.check,
                                          color: AppTheme.successColor,
                                        )
                                      : null,
                                  onTap: () => Navigator.of(ctx).pop(s),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                      ],
                    );
                  },
                );
              }
              if (selected == null) return;
              final Survey chosen = selected;
              if (chosen.hasSubmitted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You already submitted this survey.'),
                  ),
                );
                return;
              }
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TakeSurveyScreen(
                    surveyId: chosen.id,
                    eventTitle: event.title,
                  ),
                ),
              );
              if (result == true && mounted) {
                await surveyProvider.loadSurveysForEvent(event.id);
              }
            },
            icon: const Icon(Icons.assignment),
            label: const Text('Take Survey'),
          ),
        );
      },
    );
  }

  Color _getEventStatusColor(Event event) {
    final now = DateTime.now();
    if (event.startTime.isAfter(now)) {
      return AppTheme.successColor;
    } else if (event.startTime.isBefore(now) && event.endTime.isAfter(now)) {
      return AppTheme.warningColor;
    } else {
      return Colors.grey;
    }
  }

  String _getEventStatusText(Event event) {
    final now = DateTime.now();
    if (event.startTime.isAfter(now)) {
      return 'Upcoming';
    } else if (event.startTime.isBefore(now) && event.endTime.isAfter(now)) {
      return 'Ongoing';
    } else {
      return 'Past';
    }
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

  bool _isEventActive(Event event) {
    final now = DateTime.now();
    return event.isActive &&
        (event.startTime.isAfter(now) ||
            (event.startTime.isBefore(now) && event.endTime.isAfter(now)));
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  void _showQRCode(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QRCodeScreen(event: event)),
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
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
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
        Uri.parse('${ApiConfig.baseUrl}/api/barangay/residents?barangay=${widget.barangay}&disasterId=${widget.disasterId}'),
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
        bottom: _isLoading ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator()) : null,
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : DefaultTabController(
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
            backgroundColor: isMissing ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
            child: Icon(
              isMissing ? Icons.person_off : Icons.check_circle,
              color: isMissing ? Colors.red : Colors.green,
            ),
          ),
          title: Text('${r['firstName']} ${r['lastName']}'),
          subtitle: isMissing 
            ? const Text('Last seen: Unknown', style: TextStyle(color: Colors.red))
            : Text('Marked safe: ${r['safetyStatus'][0]['updatedAt'] != null ? DateFormat('hh:mm a').format(DateTime.parse(r['safetyStatus'][0]['updatedAt'])) : 'N/A'}'),
        );
      },
    );
  }
}
