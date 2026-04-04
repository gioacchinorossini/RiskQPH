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
import 'offline_qr_code_screen.dart';
import 'attendance_history_screen.dart';
import 'take_survey_screen.dart';
import '../common/calendar_events_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;
  Timer? _scrollThrottleTimer;
  bool _hasBeenCollapsed = false; // Track if SliverAppBar has been collapsed

  @override
  void initState() {
    super.initState();
    
    // Add throttled scroll listener for 60 FPS animations
    _scrollController.addListener(() {
      if (_scrollThrottleTimer?.isActive ?? false) return;
      
      _scrollThrottleTimer = Timer(const Duration(milliseconds: 16), () {
        if (mounted) {
          setState(() {
            _scrollOffset = _scrollController.offset;
            
            // Check if SliverAppBar has been collapsed (when scroll offset exceeds a reasonable threshold)
            // Use a much lower threshold (30% of screen height) so lock triggers earlier
            final double collapseThreshold = MediaQuery.of(context).size.height * 0.8;
            
            if (_scrollOffset >= collapseThreshold && !_hasBeenCollapsed) {
              _hasBeenCollapsed = true;
              // Automatically scroll back to the first section when lock is triggered
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _scrollController.animateTo(
                    0, // Scroll to top (first section)
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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      eventProvider.loadEvents();
      eventProvider.startConnectivityMonitoring();
      Provider.of<AttendanceProvider>(context, listen: false).loadAttendances();
    });
  }

  @override
  void dispose() {
    _scrollThrottleTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    
    // Get screen dimensions for responsive calculations
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    // Detect if we're on a tablet (width > 600px is considered tablet)
    final bool is600PLUS = screenWidth > 600;
    final bool is500PLUS = screenWidth > 500;
    final bool is400PLUS = screenWidth > 400;
    final bool is300PLUS = screenWidth > 300;
    final bool is700PLUS = screenWidth > 700;
    
    // Calculate responsive initial QR size based on SliverAppBar height
    final double sliverAppBarHeight = MediaQuery.of(context).size.height * 1.0; // 100% of screen height
    
    // Adjust QR size based on device type
    double maxQrSize;
    if (is700PLUS) {
      if (screenHeight > 800) {
        // On tablets, use 40% but with larger clamp values for better proportions
        maxQrSize = (sliverAppBarHeight * 0.40).clamp(200, 250); // 40% of SliverAppBar height, between 200-350px
      } else if (screenHeight > 400) {
        // On medium tablets, use 30%
        maxQrSize = (sliverAppBarHeight * 0.40).clamp(180, 200); // 30% of SliverAppBar height, between 180-250px
      } else {
        // On small tablets, use 25%
        maxQrSize = (sliverAppBarHeight * 0.25).clamp(150, 200); // 25% of SliverAppBar height, between 150-200px
      }
    } else if (is500PLUS) {
      // On Samsung Fold Duo, use 35% for better foldable proportions
      maxQrSize = (sliverAppBarHeight * 0.25).clamp(200, 300); // 35% of SliverAppBar height, between 180-300px
    } else if (is600PLUS) {
      // On is700PLUS, use 30% for better foldable proportions
      maxQrSize = (sliverAppBarHeight * 0.40).clamp(10, 50); // 30% of SliverAppBar height, between 180-300px
    } else if (is400PLUS) {
      // On is400PLUS, use 30% for better foldable proportions
      maxQrSize = (sliverAppBarHeight * 0.40).clamp(150, 250); // 30% of SliverAppBar height, between 180-300px
    } else if (is300PLUS) {
      // On Samsung S8 Plus, use 30% for better foldable proportions
      maxQrSize = (sliverAppBarHeight * 0.30).clamp(180, 200); // 30% of SliverAppBar height, between 180-300px
    } else {
      // On phones, use the original calculation
      maxQrSize = (sliverAppBarHeight * 0.40).clamp(150, 250); // 40% of SliverAppBar height, between 150-250px
    }
    
    // Calculate dynamic QR code size based on scroll offset with media query support
    double qrSize;

    // Calculate the final collapsed size (same for both states)
    double finalCollapsedSize;
    if (is700PLUS) {
      if (screenHeight > 700) {
        finalCollapsedSize = maxQrSize * 0.6; // 60% of max size
      } else if (screenHeight > 500) {
        finalCollapsedSize = maxQrSize * 0.3; // 30% of max size
      } else {
        finalCollapsedSize = maxQrSize * 0.5; // 50% of max size
      }
    } else if (is500PLUS) {
      finalCollapsedSize = maxQrSize * 0.4; // 40% of max size
    } else if (is400PLUS) {
      if (screenHeight > 730) {
        finalCollapsedSize = maxQrSize * 0.4; // 40% of max size
      } else if (screenHeight > 700) {
        finalCollapsedSize = maxQrSize * 0.3; // 30% of max size
      } else if (screenHeight > 600) {
        finalCollapsedSize = maxQrSize * 0.3; // 30% of max size
      } else if (screenHeight > 500) {
        finalCollapsedSize = maxQrSize * 0.3; // 30% of max size
      } else {
        finalCollapsedSize = maxQrSize * 0.4; // 40% of max size
      }
    } else if (is300PLUS) {
      finalCollapsedSize = maxQrSize * 0.4; // 40% of max size
    } else if (is700PLUS) {
      finalCollapsedSize = maxQrSize * 0.3; // 30% of max size
    } else {
      finalCollapsedSize = maxQrSize * 0.4; // 40% of max size
    }

    // Now use the same final size for both states
    if (_hasBeenCollapsed) {
      // If collapsed, use the final collapsed size
      qrSize = finalCollapsedSize;
    } else {
      // Normal shrinking behavior before collapse - shrink to the same final size
      if (is600PLUS) {
        qrSize = maxQrSize - (_scrollOffset * 0.4).clamp(0, maxQrSize - finalCollapsedSize);
      } else if (is500PLUS) {
        qrSize = maxQrSize - (_scrollOffset * 0.35).clamp(0, maxQrSize - finalCollapsedSize);
      } else if (is300PLUS) {
        qrSize = maxQrSize - (_scrollOffset * 0.3).clamp(0, maxQrSize - finalCollapsedSize);
      } else if (is700PLUS) {
        qrSize = maxQrSize - (_scrollOffset * 0.25).clamp(0, maxQrSize - finalCollapsedSize);
      } else {
        qrSize = maxQrSize - (_scrollOffset * 0.3).clamp(0, maxQrSize - finalCollapsedSize);
      }
    }
    
    // Calculate responsive starting position based on device type
    double startingTopPosition;
    if (is700PLUS) {
      if (screenHeight > 1200) {
        // Large tablets (iPad Pro, iPad Air) - allow up to 800px
        startingTopPosition = (screenHeight * 0.50).clamp(200, 400);
      } else if (screenHeight > 400) {
        startingTopPosition = (screenHeight * 0.50).clamp(200, 200);
      } else if (screenHeight > 800) {
        // Medium tablets (iPad Mini) - allow up to 600px  
        startingTopPosition = (screenHeight * 0.50).clamp(200, 200);
      } else {
        // Small tablets - allow up to 400px
        startingTopPosition = (screenHeight * 0.50).clamp(50, 50);
      }
    } else if (is500PLUS) {
      // Samsung Fold Duo - special handling for foldable
      if (screenHeight > 700) {
        // Folded (tall) - use 45% for better proportions
        startingTopPosition = (screenHeight * 0.20).clamp(150, 150);
      } else {
        // Unfolded (wide) - use 50% with medium clamp
        startingTopPosition = (screenHeight * 0.50).clamp(150, 300);
      }
    } else if (is400PLUS) {
      // Regular phones - smaller range
      startingTopPosition = (screenHeight * 0.50).clamp(200, 250);
    } else if (is300PLUS) {
      // Samsung S8 Plus - special handling for foldable
      if (screenHeight > 700) {
        // Folded (tall) - use 45% for better proportions
        startingTopPosition = (screenHeight * 0.20).clamp(150, 150);
      } else if (screenHeight > 600) {
        // Folded (tall) - use 45% for better proportions
        startingTopPosition = (screenHeight * 0.20).clamp(150, 150);
      } else if (screenHeight > 500) {
        // Unfolded (wide) - use 50% with medium clamp  
        startingTopPosition = (screenHeight * 0.50).clamp(150, 300);
      } else {
        // Unfolded (wide) - use 50% with medium clamp  
        startingTopPosition = (screenHeight * 0.50).clamp(150, 300);
      }
    } else {
      // Regular phones - smaller range
      startingTopPosition = (screenHeight * 0.50).clamp(100, 150);
    }
    
    // Calculate SliverAppBar collapsed height
    final double collapsedHeight = MediaQuery.of(context).size.height * 0.15;
    
    // Calculate how much the QR can move up (respecting SliverAppBar bounds)
    final double maxUpwardMovement = startingTopPosition - (collapsedHeight * 0.1); // Leave 10% of collapsed height for QR
    
    // Calculate dynamic top position for the QR code (stays within SliverAppBar)
    double qrTopPosition;
    if (_hasBeenCollapsed) {
      // If collapsed, use the final collapsed position
      qrTopPosition = collapsedHeight * 0.1; // 10% from top of collapsed SliverAppBar
    } else {
      // Normal movement before collapse
      qrTopPosition = startingTopPosition - (_scrollOffset * 0.3).clamp(0, maxUpwardMovement);
    }

    // Calculate hint text opacity


    // --- Horizontal positioning for the QR code ---
    // Define the maximum scroll offset for the horizontal centering transition.
    // This should be higher to make left movement slower than upward movement.
    final double maxScrollForLeftTransition = 300.0; // Increased from 100 to 300 for slower left movement

    // The starting horizontal position when fully expanded (centered)
    final double centeredExpandedLeft = (screenWidth - qrSize) / 2;

    // The final left position (keeping some distance from left edge) - adjust for device type
    final double finalLeftPosition;
    if (is600PLUS) {
      finalLeftPosition = 80.0; // More spacing on tablets
    } else if (is500PLUS) {
      finalLeftPosition = 60.0; // Medium spacing on foldable devices
    } else {
      finalLeftPosition = 40.0; // Standard spacing on phones
    }

    double qrHorizontalPosition;

    if (_hasBeenCollapsed) {
      // If collapsed, use the final left position
      qrHorizontalPosition = finalLeftPosition;
    } else if (_scrollOffset <= maxScrollForLeftTransition) {
      // Smooth interpolation between centered position and final left position
      double t = _scrollOffset / maxScrollForLeftTransition; // t goes from 0.0 to 1.0
      qrHorizontalPosition = centeredExpandedLeft * (1 - t) + finalLeftPosition * t;
    } else {
      // After the transition, use the final left position
      qrHorizontalPosition = finalLeftPosition;
    }
    // --- End horizontal positioning for the QR code ---
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.offline_bolt),
            onPressed: () => _showOfflineQRCode(),
            tooltip: 'Offline QR Code',
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              // Refresh all providers
              final eventProvider = Provider.of<EventProvider>(context, listen: false);
              final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
              await Future.wait([
                eventProvider.loadEvents(),
                attendanceProvider.loadAttendances(),
              ]);
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(), // Ensures scrolling is always enabled
              slivers: [
                // SliverAppBar with collapsible main section - stays collapsed once collapsed
                SliverAppBar(
                  expandedHeight: _hasBeenCollapsed 
                    ? MediaQuery.of(context).size.height * 0.15 // Force collapsed height
                    : MediaQuery.of(context).size.height * 1.0, // Normal expanded height
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
                
                // Blank sections to create proper spacing below SliverAppBar
                // This ensures content bumps up smoothly when collapsed
                SliverToBoxAdapter(
                  child: Container(
                    height: qrSize * 0, // Space for QR code + welcome section + extra padding
                    color: Colors.transparent,
                  ),
                ),
                
                // Content based on selected tab - using SliverList instead of IndexedStack
                if (_selectedIndex == 0) _buildEventsSliver(), 
                if (_selectedIndex == 1) _buildAttendanceHistorySliver(),
                if (_selectedIndex == 2) _buildProfileSliver(user),
              ],
            ),
          ),
          
          // Introduction Section (above QR code)
          if (_scrollOffset <= 200 && !_hasBeenCollapsed) ...[
            Positioned(
              top: qrTopPosition - (qrSize * 0.5), // Position relative to QR size and position
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: (1 - (_scrollOffset / 200)).clamp(0, 1), // Fade out as user scrolls
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: qrSize * 0.2), // Relative to QR size
                  child: Column(
                    children: [
                      // Welcome Message
                Text(
                        'Welcome',
                  style: TextStyle(
                          color: Colors.white,
                          fontSize: (qrSize * 0.10).clamp(16, 40), // Relative to QR size
                    fontWeight: FontWeight.bold,
                  ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: qrSize * 0.02), // Relative spacing
                      // Description
                      Text(
                        'Your personal QR code is ready for attendance marking. Simply present this code to event organizers.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: (qrSize * 0.06).clamp(12, 28), // Relative to QR size
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
          
          // Animated QR Code Container with Text
          Positioned(
            top: qrTopPosition,
            left: qrHorizontalPosition,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: qrSize,
              width: (_scrollOffset > 200 || _hasBeenCollapsed) ? screenWidth - (is600PLUS ? 160 : 80) : qrSize, // Expand to full width minus equal spacing (more spacing on tablets)
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
                      // QR Code Widget
                      SizedBox(
                        width: qrSize,
                        child: Center(
                          child: _buildOfflineQRCode(user, qrSize * 0.9),
                        ),
                      ),
                      // Text inside container
          Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                            Text(
                              user?.name ?? 'Student Name',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: is600PLUS ? 20 : 16, // Larger text on tablets
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.yearLevel ?? 'N/A',
                              style: TextStyle(
                                color: AppTheme.primaryColor.withOpacity(0.8),
                                fontSize: is600PLUS ? 16 : 12, // Larger text on tablets
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
                    child: _buildOfflineQRCode(user, qrSize * 0.9),
                  ),
            ),
          ),
          
          // Animated Name (only visible when not inside container)
          if (_scrollOffset <= 200 && !_hasBeenCollapsed) ...[
            Positioned(
              top: (qrTopPosition + qrSize + 20 - (_scrollOffset * 0.3).clamp(0, 40)).clamp(
                collapsedHeight * 0.1, // Minimum 10% from top of collapsed SliverAppBar
                startingTopPosition + qrSize + 20 // Maximum: starting position + QR size + margin
              ),
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: (1 - (_scrollOffset / 200)).clamp(0, 1), // Fade out as user scrolls
                child: Center(
                  child: Text(
                    user?.name ?? 'Student Name',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: is600PLUS ? 36 : 28, // Larger text on tablets
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            
            // Animated Year Level (only visible when not inside container)
            if (_scrollOffset <= 200 && !_hasBeenCollapsed) ...[
              Positioned(
                top: (qrTopPosition + qrSize + 60 - (_scrollOffset * 0.3).clamp(0, 40)).clamp(
                  collapsedHeight * 0.3, // Minimum 30% from top of collapsed SliverAppBar
                  startingTopPosition + qrSize + 60 // Maximum: starting position + QR size + margin
                ),
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: (1 - (_scrollOffset / 200)).clamp(0, 1), // Fade out as user scrolls
                  child: Center(
                                        child: Text(
                        user?.yearLevel ?? 'N/A',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: is600PLUS ? 24 : 18, // Larger text on tablets
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ),
                ),
              ),
            ],
          ],
          
          // Floating Swipe Up Indicator (positioned above everything else) - Made non-blocking
          if (_scrollOffset < 10 && !_hasBeenCollapsed) ...[
            Positioned(
              top: sliverAppBarHeight - (qrSize * 1), // Position at bottom of SliverAppBar with some padding
              left: 0,
              right: 0,
              child: IgnorePointer( // This makes the indicator non-blocking for touch events
                child: Material(
                  color: Colors.transparent,
                  elevation: 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: _scrollOffset < 10 ? 1.0 : 0.0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Enhanced Animated Arrow with pulse effect (now at top)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 1500),
                          transform: Matrix4.translationValues(
                            0, 
                            _scrollOffset < 10 ? (DateTime.now().millisecondsSinceEpoch % 3000 < 1500 ? -8 : 0) : 0, 
                            0
                          ),
                          child: Container(
                            padding: EdgeInsets.all(qrSize * 0.04), // Relative to QR size
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: Colors.white,
                              size: (qrSize * 0.15).clamp(20, 40), // Relative to QR size
                            ),
                          ),
                        ),
                        SizedBox(height: qrSize * 0.05), // Relative spacing
                        // Enhanced Text with gradient
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: qrSize * 0.08, // Relative to QR size
                            vertical: qrSize * 0.03, // Relative to QR size
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
                              fontSize: (qrSize * 0.07).clamp(10, 20), // Relative to QR size
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(height: qrSize * 0.02), // Relative spacing
                        // Subtle hint text
                        Text(
                          'Discover your events and history',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: (qrSize * 0.06).clamp(8, 16), // Relative to QR size
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
          
          // Unlock Arrow Button (only visible when collapsed)
          if (_hasBeenCollapsed) ...[
            Positioned(
              top: collapsedHeight - 40, // Position at center bottom of collapsed SliverAppBar
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
                      // Scroll back to top to show the expanded state
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
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Events',
          ),
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
        : null, // Hide navigation when expanded and not scrolled
    );
  }

  Widget _buildOfflineQRCode(User? user, double size) {
    if (user == null) return Container();
    
    // Generate offline QR code data (same as OfflineQRCodeScreen)
    final qrPayload = jsonEncode({
      'studentId': user.id,
    });
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
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 16), // Extra top padding to avoid rounded corners
          sliver: SliverList(
            delegate: SliverChildListDelegate([
                  // Welcome Section
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Check Events!',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check your upcoming events and mark your attendance',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Available Events
                  Text(
                    'Available Events',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                          Icon(
                            Icons.event_busy,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                                                  Text(
                          'No available events',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
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

                  // Past Events
                  Text(
                    'Past Events',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                          Icon(
                            Icons.history,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No past events',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
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
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16), // Extra top padding to avoid rounded corners
      sliver: const AttendanceHistoryScreen(),
    );
  }

  Widget _buildProfileSliver(User? user) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16), // Extra top padding to avoid rounded corners
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Profile Header
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

          // Student Info
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
                  _buildInfoRow('Member Since', 
                    user?.createdAt != null 
                      ? DateFormat('MMM dd, yyyy').format(user!.createdAt)
                      : 'N/A'
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner),
                  title: const Text('Scan QR Code'),
                  subtitle: const Text('Mark attendance for an event'),
                  onTap: () {
                    // Navigate to QR scanner
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.offline_bolt),
                  title: const Text('Offline QR Code'),
                  subtitle: const Text('Generate universal QR code for offline scanning'),
                  onTap: () => _showOfflineQRCode(),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Calendar View'),
                  subtitle: const Text('View events in calendar format'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CalendarEventsScreen(),
          ),
        );
      },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Attendance History'),
                  subtitle: const Text('View your attendance records'),
                  onTap: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  subtitle: const Text('Sign out of your account'),
                  onTap: _handleLogout,
                ),
              ],
            ),
          ),
          // Add bottom padding to prevent content from being cut off
          const SizedBox(height: 24),
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
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) + 2,
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
                        padding: const EdgeInsets.only(left: 28), // icon(20) + spacer(8)
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final TextStyle titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) + 2,
                                  height: 1.15,
                                  letterSpacing: 0.2,
                                ) ?? const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.15);
                            final TextPainter textPainter = TextPainter(
                              text: TextSpan(text: event.title, style: titleStyle),
                              maxLines: 2,
                              ellipsis: '…',
                              textDirection: Directionality.of(context),
                            )..layout(maxWidth: constraints.maxWidth);
                            final double underlineWidth = textPainter.size.width;
                            return Container(
                              width: underlineWidth,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          },
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showQRCode(event),
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Get QR Code'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showOfflineQRCode(),
                      icon: const Icon(Icons.offline_bolt),
                      label: const Text('Offline Mode'),
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
              // Load surveys then let the user pick one if multiple
              await surveyProvider.loadSurveysForEvent(event.id, userId: userId);
              final surveys = surveyProvider.surveysForEvent(event.id).where((s) => s.isActive).toList();
              if (surveys.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No survey available for this event.')));
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
                          children: surveys.map((s) => ListTile(
                            title: Text(s.title),
                            subtitle: s.hasSubmitted ? const Text('Already submitted') : null,
                            trailing: s.hasSubmitted ? const Icon(Icons.check, color: AppTheme.successColor) : null,
                            onTap: () => Navigator.of(ctx).pop(s),
                          )).toList(),
                        ),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                      ],
                    );
                  },
                );
              }
              if (selected == null) return;
              final Survey chosen = selected;
              if (chosen.hasSubmitted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already submitted this survey.')));
                return;
              }
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TakeSurveyScreen(surveyId: chosen.id, eventTitle: event.title),
                ),
              );
              if (result == true && mounted) {
                // refresh list to reflect hasSubmitted
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
      return AppTheme.successColor; // Upcoming
    } else if (event.startTime.isBefore(now) && event.endTime.isAfter(now)) {
      return AppTheme.warningColor; // Ongoing
    } else {
      return Colors.grey; // Past
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
      MaterialPageRoute(
        builder: (context) => QRCodeScreen(event: event),
      ),
    );
  }

  void _showOfflineQRCode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OfflineQRCodeScreen(),
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
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }
} 