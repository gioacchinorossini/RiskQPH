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
    
    // Calculate responsive initial QR size based on SliverAppBar height
    final double sliverAppBarHeight = MediaQuery.of(context).size.height * 1.0; // 100% of screen height
    final double maxQrSize = (sliverAppBarHeight * 0.40).clamp(150, 250); // 40% of SliverAppBar height, between 150-250px
    
    // Calculate dynamic QR code size based on scroll offset
    final double qrSize = maxQrSize - (_scrollOffset * 0.3).clamp(0, maxQrSize * 0.6);

    // Calculate responsive starting position (15% of screen height, min 120px, max 180px)
    final double startingTopPosition = (screenHeight * 0.50).clamp(200, 250);
    
    // Calculate SliverAppBar collapsed height
    final double collapsedHeight = MediaQuery.of(context).size.height * 0.15;
    
    // Calculate how much the QR can move up (respecting SliverAppBar bounds)
    final double maxUpwardMovement = startingTopPosition - (collapsedHeight * 0.1); // Leave 30% of collapsed height for QR
    
    // Calculate dynamic top position for the QR code (stays within SliverAppBar)
    final double qrTopPosition = startingTopPosition - (_scrollOffset * 0.5).clamp(0, maxUpwardMovement);

    // Calculate hint text opacity


    // --- Horizontal positioning for the QR code ---
    // Define the maximum scroll offset for the horizontal centering transition.
    // This should be higher to make left movement slower than upward movement.
    final double maxScrollForLeftTransition = 300.0; // Increased from 100 to 300 for slower left movement

    // The starting horizontal position when fully expanded (centered)
    final double centeredExpandedLeft = (screenWidth - qrSize) / 2;

    // The final left position (keeping some distance from left edge)
    final double finalLeftPosition = 40.0;

    double qrHorizontalPosition;

    if (_scrollOffset <= maxScrollForLeftTransition) {
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
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CalendarEventsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
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
              slivers: [
                // SliverAppBar with collapsible main section
                SliverAppBar(
                  expandedHeight: MediaQuery.of(context).size.height * 1.0, // 100% of screen height
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
                
                // Content based on selected tab - using SliverList instead of IndexedStack
                if (_selectedIndex == 0) _buildEventsSliver(),
                if (_selectedIndex == 1) _buildAttendanceHistorySliver(),
                if (_selectedIndex == 2) _buildProfileSliver(user),
              ],
            ),
          ),
          
          // Introduction Section (above QR code)
          if (_scrollOffset <= 200) ...[
            Positioned(
              top: qrTopPosition - 150, // Position above the QR code with more gap
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: (1 - (_scrollOffset / 200)).clamp(0, 1), // Fade out as user scrolls
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      // Welcome Message
                      Text(
                        'Welcome to Your Dashboard',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Description
                      Text(
                        'Your personal QR code is ready for attendance marking. Simply present this code to event organizers.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
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
              width: _scrollOffset > 200 ? screenWidth - 80 : qrSize, // Expand to full width minus equal spacing (20px left + 20px right)
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
              child: _scrollOffset > 200 
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
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Year Level: ${user?.studentId?.substring(0, 2) ?? 'N/A'}',
                              style: TextStyle(
                                color: AppTheme.primaryColor.withOpacity(0.8),
                                fontSize: 12,
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
          if (_scrollOffset <= 200) ...[
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            
            // Animated Year Level (only visible when not inside container)
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
                    'Year Level: ${user?.studentId?.substring(0, 2) ?? 'N/A'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
          
          // Enhanced Swipe Up Indicator (in content area)
          if (_scrollOffset < 10) ...[
            Positioned(
              bottom: 1, // Position above the navigation bar area
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _scrollOffset < 10 ? 1.0 : 0.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Enhanced Text with gradient
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtle hint text
                    Text(
                      'Discover your events and history',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Enhanced Animated Arrow with pulse effect (now at bottom)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 1500),
                      transform: Matrix4.translationValues(
                        0, 
                        _scrollOffset < 10 ? (DateTime.now().millisecondsSinceEpoch % 3000 < 1500 ? -8 : 0) : 0, 
                        0
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

        ],
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: Offset(0, _scrollOffset > 50 ? 0 : 1), // Slide up from bottom (1 = hidden, 0 = visible)
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _scrollOffset > 50 ? 1.0 : 0.0,
          child: BottomNavigationBar(
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
          ),
        ),
      ),
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
                      'Welcome back!',
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
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
              if (selected!.hasSubmitted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already submitted this survey.')));
                return;
              }
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TakeSurveyScreen(surveyId: selected!.id, eventTitle: event.title),
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