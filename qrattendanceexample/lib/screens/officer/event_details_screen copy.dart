import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../../models/attendance.dart';
import '../../providers/attendance_provider.dart';
import '../../utils/theme.dart';
import 'qr_scanner_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final Event event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure we load enriched attendance (with department) for this event
      Provider.of<AttendanceProvider>(context, listen: false)
          .refreshAttendanceForEvent(widget.event.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _showQRScanner(),
            tooltip: 'Scan QR Code',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Header
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
                  Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 32,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          event.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    event.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Event Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Event Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.calendar_today,
                      'Date',
                      dateFormat.format(event.startTime),
                    ),
                    _buildInfoRow(
                      Icons.access_time,
                      'Time',
                      '${timeFormat.format(event.startTime)} - ${timeFormat.format(event.endTime)}',
                    ),
                    _buildInfoRow(
                      Icons.location_on,
                      'Location',
                      event.location,
                    ),
                    _buildInfoRow(
                      Icons.create,
                      'Created',
                      dateFormat.format(event.createdAt),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Attendance Statistics
            Consumer<AttendanceProvider>(
              builder: (context, attendanceProvider, child) {
                final attendances = attendanceProvider.getAttendancesByEvent(event.id);
                final totalAttendance = attendances.length;
                final presentCount = attendances.where((a) => a.status == 'present').length;
                final lateCount = attendances.where((a) => a.status == 'late').length;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Statistics',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Total',
                                totalAttendance.toString(),
                                Icons.people,
                                AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Present',
                                presentCount.toString(),
                                Icons.check_circle,
                                AppTheme.successColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Late',
                                lateCount.toString(),
                                Icons.schedule,
                                AppTheme.warningColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Attendance by Department with Bar Chart
            Consumer<AttendanceProvider>(
              builder: (context, attendanceProvider, child) {
                final attendances = attendanceProvider.getAttendancesByEvent(event.id);
                final Map<String, int> deptCounts = {};
                for (final a in attendances) {
                  final key = (a.department == null || (a.department ?? '').trim().isEmpty)
                      ? 'Unknown'
                      : a.department!.trim();
                  deptCounts.update(key, (value) => value + 1, ifAbsent: () => 1);
                }

                final entries = deptCounts.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                if (entries.isEmpty) {
                  return const SizedBox.shrink();
                }

                final int maxCount = entries.first.value;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance by Department',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        ...entries.map((e) => _buildDeptBarRow(
                              label: e.key,
                              value: e.value,
                              maxValue: maxCount,
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Attendance List
            Consumer<AttendanceProvider>(
              builder: (context, attendanceProvider, child) {
                final attendances = attendanceProvider.getAttendancesByEvent(event.id);
                
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Attendance List',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${attendances.length} students',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        if (attendances.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No attendance records yet',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Students will appear here after they mark their attendance',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          ...attendances.map((attendance) => _buildAttendanceItem(attendance)),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showQRScanner(),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan QR Code'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceItem(Attendance attendance) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');
    
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.1),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attendance.studentName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${dateFormat.format(attendance.checkInTime)} at ${timeFormat.format(attendance.checkInTime)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
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
              attendance.status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(selectedEvent: widget.event),
      ),
    );
  }

  Widget _buildDeptBarRow({required String label, required int value, required int maxValue}) {
    final Color barColor = AppTheme.primaryColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double ratio = maxValue == 0 ? 0 : (value / maxValue);
                final double barWidth = constraints.maxWidth * ratio.clamp(0.0, 1.0);
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    Container(
                      width: barWidth,
                      height: 18,
                      decoration: BoxDecoration(
                        color: barColor.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 36,
            child: Text(
              value.toString(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
} 