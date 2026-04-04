import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../models/user.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../utils/theme.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
    _updateTime();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateTime() {
    setState(() {
      _currentTime = DateTime.now().toString();
    });
    Future.delayed(const Duration(seconds: 1), _updateTime);
  }

  Widget _buildQRCode(User? user, double size) {
    if (user == null) return Container();
    
    // Use the SAME offline QR data as OfflineQRCodeScreen
    // This ensures consistency between dashboard and offline QR
    final qrPayload = jsonEncode({
      'studentId': user.id,
    });
    final qrData = base64Encode(utf8.encode(qrPayload));
    
    return QrImageView(
      data: qrData,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.primaryColor, // Match offline QR styling
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;
        
        return Scaffold(
          body: _buildBody(user),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
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
                icon: Icon(Icons.qr_code),
                label: 'QR Code',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(User? user) {
    switch (_currentIndex) {
      case 0:
        return _buildEventsTab(user);
      case 1:
        return _buildHistoryTab(user);
      case 2:
        return _buildQRCodeTab(user);
      case 3:
        return _buildProfileTab(user);
      default:
        return _buildEventsTab(user);
    }
  }

  Widget _buildEventsTab(User? user) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        if (eventProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final visibleEvents = eventProvider.getStudentVisibleEvents();
        final pastEvents = eventProvider.getPastEvents();

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: 700.0,
              toolbarHeight: 300.0,
              floating: false,
              pinned: true,
              backgroundColor: Colors.yellow, // For visual debugging
              automaticallyImplyLeading: false,
              flexibleSpace: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double appBarHeight = constraints.maxHeight;
                  final double shrinkFactor = 
                      ((appBarHeight - 300.0) / (700.0 - 300.0))
                          .clamp(0.0, 1.0);
                  
                  return FlexibleSpaceBar(
                    expandedTitleScale: 1.0,
                    titlePadding: EdgeInsets.zero,
                    title: Container(
                      width: double.infinity,
                      height: constraints.maxHeight,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3), // For visual debugging
                        border: Border.all(color: Colors.blue, width: 3), // For visual debugging
                      ),
                      child: _buildUnifiedLayout(user, shrinkFactor),
                    ),
                  );
                },
              ),
            ),
            
            // Debug Time Display
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.blue.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DEBUG TIME: $_currentTime',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Welcome Section
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
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
            ),

            // Events content
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
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
                          const SizedBox(height: 16),
                          Text(
                            'No events available',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Check back later for new events',
                            style: TextStyle(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...visibleEvents.map((event) => _buildEventCard(event, user)),
                  
                  const SizedBox(height: 24),
                  
                  // Past Events
                  Text(
                    'Past Events',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
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
                          const SizedBox(height: 16),
                          Text(
                            'No past events',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your event history will appear here',
                            style: TextStyle(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...pastEvents.map((event) => _buildEventCard(event, user)),
                  
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUnifiedLayout(User? user, double shrinkFactor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Dynamic QR size based on container width
        // QR takes 25% of container width when expanded
        final double expandedSize = constraints.maxWidth * 0.5;
        // QR takes 10% of container width when collapsed  
        final double collapsedSize = constraints.maxWidth * 0.1;
        
        // Dynamic size calculation based on scroll position
        final double dynamicQrSize = collapsedSize + (expandedSize - collapsedSize) * shrinkFactor;
        
        // Calculate horizontal position for smooth movement
        // When expanded (shrinkFactor = 1): center of container
        // When collapsed (shrinkFactor = 0): left side with padding
        final double centerX = constraints.maxWidth / 2;
        final double leftX = 16.0; // Left padding
        final double currentX = leftX + (centerX - leftX) * shrinkFactor;
        
        return Stack(
          children: [
            // QR Code with smooth position transition
            Positioned(
              left: currentX - (dynamicQrSize / 2), // Center the QR at currentX
              top: constraints.maxHeight * 0.5, // 20% from top - easily adjustable!
              child: Container(
                width: dynamicQrSize,
                height: dynamicQrSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(dynamicQrSize * 0.1),
                  child: _buildQRCode(user, dynamicQrSize * 0.8),
                ),
              ),
            ),
            
            // User name with smooth position transition
            Positioned(
              left: currentX + (dynamicQrSize / 2) + 16, // To the right of QR
              top: constraints.maxHeight * 0.3 + (dynamicQrSize / 2) - 10, // Align with QR center
              child: Opacity(
                opacity: 1 - (shrinkFactor * 0.5), // Fade out as it expands
                child: Text(
                  user?.name ?? 'Student',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            
            // User email (only visible when expanded)
            Positioned(
              left: 0,
              right: 0,
              bottom: constraints.maxHeight * 0.2,
              child: Opacity(
                opacity: shrinkFactor,
                child: Text(
                  user?.email ?? 'student@school.com',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEventCard(Event event, User? user) {
    final bool isPast = event.endTime.isBefore(DateTime.now());
    final bool isOngoing = event.startTime.isBefore(DateTime.now()) && 
                           event.endTime.isAfter(DateTime.now());
    
    Color statusColor;
    String statusText;
    
    if (isPast) {
      statusColor = Colors.grey;
      statusText = 'Past';
    } else if (isOngoing) {
      statusColor = Colors.green;
      statusText = 'Ongoing';
    } else {
      statusColor = Colors.blue;
      statusText = 'Upcoming';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              event.description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${_formatDateTime(event.startTime)} - ${_formatDateTime(event.endTime)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  event.location ?? 'No location specified',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (!isPast) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to QR scanner or attendance marking
                    Navigator.pushNamed(context, '/qr-scanner', arguments: event);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isOngoing ? 'Mark Attendance' : 'View Details',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildHistoryTab(User? user) {
    return const Center(
      child: Text('Attendance History'),
    );
  }

  Widget _buildQRCodeTab(User? user) {
    return const Center(
      child: Text('QR Code'),
    );
  }

  Widget _buildProfileTab(User? user) {
    return const Center(
      child: Text('Profile'),
    );
  }
} 