import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/user.dart';
import '../../models/event.dart';
import '../../models/attendance.dart';
import '../../utils/theme.dart';
import 'qr_scanner_screen.dart';
import 'offline_qr_scanner_screen.dart';
import 'event_details_screen.dart';
import '../common/calendar_events_screen.dart';

class OfficerDashboard extends StatefulWidget {
  const OfficerDashboard({super.key});

  @override
  State<OfficerDashboard> createState() => _OfficerDashboardState();
}

class _OfficerDashboardState extends State<OfficerDashboard> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Check connection status and load events accordingly
      if (authProvider.isConnected) {
        await eventProvider.loadEvents();
      } else {
        await eventProvider.loadEventsFromCache();
      }
      
      Provider.of<AttendanceProvider>(context, listen: false).loadAttendances();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _showQRScanner(),
            tooltip: 'QR Scanner',
          ),
          IconButton(
            icon: const Icon(Icons.offline_bolt),
            onPressed: () => _showOfflineQRScanner(),
            tooltip: 'Offline QR Scanner',
          ),
        ],
      ),
      body: Column(
        children: [
          // Main Content
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildEventsTab(),
                _buildAttendanceTab(),
                _buildProfileTab(user),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
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
            icon: Icon(Icons.people),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        if (eventProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final activeEvents = eventProvider.getActiveEvents();
        final pastEvents = eventProvider.getPastEvents();

        return RefreshIndicator(
          onRefresh: () async {
            // Check connection status first
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final isConnected = await authProvider.testConnection();
            
            if (isConnected) {
              // Online mode - try to fetch from server
              await eventProvider.loadEvents();
            } else {
              // Offline mode - load from cache
              await eventProvider.loadEventsFromCache();
            }
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 200,
            ),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          'Officer Dashboard',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Monitor events and track student attendance',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: InkWell(
                            onTap: () => _showQRScanner(),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner,
                                    size: 32,
                                    color: AppTheme.secondaryColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Auto Event QR Scanner',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          child: InkWell(
                            onTap: () => _showOfflineQRScanner(),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.offline_bolt,
                                    size: 32,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Offline Scanner',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CalendarEventsScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.calendar_month,
                                    size: 32,
                                    color: AppTheme.secondaryColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Calendar View',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Active Events
                  Text(
                    'Active Events',
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
                  
                  if (activeEvents.isEmpty)
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
                            'No active events',
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
                    ...activeEvents.map((event) => _buildEventCard(event, true)),

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
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...pastEvents.map((event) => _buildEventCard(event, false)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventCard(Event event, bool isActive) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showEventDetails(event),
        borderRadius: BorderRadius.circular(12),
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
                  // Status badge
                  (() {
                    final now = DateTime.now();
                    final bool isUpcoming = event.startTime.isAfter(now);
                    final bool isOngoing = event.startTime.isBefore(now) && event.endTime.isAfter(now);
                    final String statusText = isUpcoming ? 'Upcoming' : (isOngoing ? 'Ongoing' : 'Past');
                    final Color statusColor = isUpcoming
                        ? AppTheme.successColor
                        : (isOngoing ? AppTheme.warningColor : Colors.grey);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  })(),
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
              
              if (isActive) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showQRScanner(event),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan Attendance'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEventDetails(event),
                        icon: const Icon(Icons.visibility),
                        label: const Text('View Details'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceTab() {
    return Consumer<AttendanceProvider>(
      builder: (context, attendanceProvider, child) {
        final allAttendances = attendanceProvider.attendances;
        
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                      'Attendance Overview',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Track student attendance across all events',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Statistics
              _buildAttendanceStats(context, allAttendances),
              const SizedBox(height: 24),

              // Recent Attendance
              Text(
                'Recent Attendance',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              if (allAttendances.isEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No attendance records yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Attendance records will appear here after students mark their attendance',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: allAttendances.length,
                    itemBuilder: (context, index) {
                      final attendance = allAttendances[index];
                      return _buildAttendanceCard(context, attendance);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttendanceStats(BuildContext context, List<Attendance> attendances) {
    int totalAttendance = attendances.length;
    int presentCount = attendances.where((a) => a.status == 'present').length;
    int lateCount = attendances.where((a) => a.status == 'late').length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            'Total Attendance',
            totalAttendance.toString(),
            Icons.people,
            AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            'Present',
            presentCount.toString(),
            Icons.check_circle,
            AppTheme.successColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            'Late',
            lateCount.toString(),
            Icons.schedule,
            AppTheme.warningColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(BuildContext context, Attendance attendance) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final event = eventProvider.getEventById(attendance.eventId);
    final eventTitle = event?.title ?? 'Unknown event';
    
    Color statusColor;
    IconData statusIcon;
    
    switch (attendance.status) {
      case 'present':
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle;
        break;
      case 'late':
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.schedule;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(
            statusIcon,
            color: statusColor,
          ),
        ),
        title: Text(attendance.studentName),
        subtitle: Text(
          '$eventTitle • ${dateFormat.format(attendance.checkInTime)} at ${timeFormat.format(attendance.checkInTime)}',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor),
          ),
          child: Text(
            attendance.status.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab(User? user) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    Icons.security,
                    size: 40,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.name ?? 'Officer',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user?.email ?? 'officer@school.com',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Officer Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Officer Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Role', 'Officer'),
                  _buildInfoRow('Member Since', 
                    DateFormat('MMM dd, yyyy').format(user?.createdAt ?? DateTime.now())
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
                  subtitle: const Text('Scan student QR codes for attendance'),
                  onTap: () => _showQRScanner(),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('View Attendance'),
                  subtitle: const Text('Check attendance records'),
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
        ],
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
            ),
          ),
        ],
      ),
    );
  }

  void _showQRScanner([Event? event]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(selectedEvent: event),
      ),
    );
  }

  void _showOfflineQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OfflineQRScannerScreen(),
      ),
    );
  }

  void _showEventDetails(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsScreen(event: event),
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