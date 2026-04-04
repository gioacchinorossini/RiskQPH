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
    
    // Calculate responsive QR size based on screen dimensions
    final double maxQrSize = (screenHeight * 0.35).clamp(200, 300); // 35% of screen height
    final double minQrSize = 80.0; // Minimum QR size when collapsed
    
    // Calculate dynamic QR code size based on scroll offset
    final double qrSize = maxQrSize - (_scrollOffset * 0.4).clamp(0, maxQrSize - minQrSize);
    
    // Calculate flex-based positioning
    final double scrollProgress = (_scrollOffset / 200).clamp(0, 1); // 0 = expanded, 1 = collapsed
    
    // Calculate SliverAppBar height based on content
    final double expandedHeight = screenHeight * 0.8; // 80% of screen height
    final double collapsedHeight = 80.0; // Fixed collapsed height
    
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
      body: RefreshIndicator(
        onRefresh: () async {
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
            // Flexible SliverAppBar that adapts to content
            SliverAppBar(
              expandedHeight: expandedHeight,
              collapsedHeight: collapsedHeight,
              pinned: true,
              floating: false,
              backgroundColor: AppTheme.primaryColor,
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Introduction Section
                      if (scrollProgress < 0.5) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(40, 60, 40, 20),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: (1 - scrollProgress * 2).clamp(0, 1),
                            child: Column(
                              children: [
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
                                Text(
                                  'Your personal QR code is ready for attendance marking.',
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
                      ],
                      
                      // Main QR Section with Flex Layout
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: scrollProgress < 0.5 
                              ? _buildExpandedLayout(user, qrSize, scrollProgress)
                              : _buildCollapsedLayout(user, qrSize, scrollProgress),
                          ),
                        ),
                      ),
                      
                      // Swipe Up Indicator
                      if (_scrollOffset < 10) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 40),
                          child: _buildSwipeIndicator(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            
            // Content based on selected tab
            if (_selectedIndex == 0) _buildEventsSliver(),
            if (_selectedIndex == 1) _buildAttendanceHistorySliver(),
            if (_selectedIndex == 2) _buildProfileSliver(user),
          ],
        ),
      ),
      bottomNavigationBar: _scrollOffset > 50 
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
        : null, // Completely remove navigation bar when hidden
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

  // Flex-based expanded layout (QR centered with text below)
  Widget _buildExpandedLayout(User? user, double qrSize, double scrollProgress) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // QR Code Container
        Container(
          width: qrSize,
          height: qrSize,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: _buildOfflineQRCode(user, qrSize * 0.9),
          ),
        ),
        const SizedBox(height: 30),
        // Student Name
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: (1 - scrollProgress * 2).clamp(0, 1),
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
        const SizedBox(height: 8),
        // Year Level
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: (1 - scrollProgress * 2).clamp(0, 1),
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
      ],
    );
  }

  // Flex-based collapsed layout (QR on left, text on right)
  Widget _buildCollapsedLayout(User? user, double qrSize, double scrollProgress) {
    return Row(
      children: [
        // QR Code on the left
        Container(
          width: qrSize,
          height: qrSize,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: _buildOfflineQRCode(user, qrSize * 0.9),
          ),
        ),
        const SizedBox(width: 20),
        // Text on the right
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.name ?? 'Student Name',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Text(
                'Year Level: ${user?.studentId?.substring(0, 2) ?? 'N/A'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Swipe indicator widget
  Widget _buildSwipeIndicator() {
    return AnimatedOpacity(
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
          // Enhanced Animated Arrow
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
                  title: const Text('Show Offline QR Code'),
                  subtitle: const Text('Display your personal QR code'),
                  onTap: () => _showOfflineQRCode(),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('View Calendar'),
                  subtitle: const Text('Check upcoming events'),
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
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  subtitle: const Text('Sign out of your account'),
                  onTap: _handleLogout,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
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
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event, bool isActive) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryColor : Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isActive ? Icons.event : Icons.event_busy,
            color: isActive ? Colors.white : Colors.grey[600],
            size: 24,
          ),
        ),
        title: Text(
          event.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.black : Colors.grey[600],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              event.description,
              style: TextStyle(
                color: isActive ? Colors.grey[700] : Colors.grey[500],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: isActive ? AppTheme.primaryColor : Colors.grey[500],
                ),
                const SizedBox(width: 4),
                                 Text(
                   DateFormat('MMM dd, yyyy').format(event.startTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? AppTheme.primaryColor : Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: isActive ? AppTheme.primaryColor : Colors.grey[500],
                ),
                const SizedBox(width: 4),
                                 Text(
                   DateFormat('HH:mm').format(event.startTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? AppTheme.primaryColor : Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: isActive
            ? ElevatedButton(
                onPressed: () {
                  // Navigate to QR scanner or event details
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Attend'),
              )
            : null,
      ),
    );
  }

  void _showOfflineQRCode() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OfflineQRCodeScreen(),
      ),
    );
  }

  void _handleLogout() {
    Provider.of<AuthProvider>(context, listen: false).logout();
    Navigator.of(context).pushReplacementNamed('/login');
  }
} 