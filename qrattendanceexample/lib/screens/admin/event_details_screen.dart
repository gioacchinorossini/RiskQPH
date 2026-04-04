import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../../models/attendance.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';
import 'create_survey_screen.dart';

class EventDetailsScreen extends StatelessWidget {
  final Event event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        elevation: 0,
      ),
      body: Consumer<AttendanceProvider>(
        builder: (context, attendanceProvider, child) {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          final bool isAdmin = auth.currentUser?.role == UserRole.admin;
          final eventAttendances = attendanceProvider.getAttendancesByEvent(event.id);
          final stats = attendanceProvider.getAttendanceStatsForEvent(event.id);
          
          return SingleChildScrollView(
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
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
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
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          context,
                          Icons.calendar_today,
                          'Date',
                          DateFormat('EEEE, MMMM dd, yyyy').format(event.startTime),
                        ),
                        _buildInfoRow(
                          context,
                          Icons.access_time,
                          'Start Time',
                          DateFormat('HH:mm').format(event.startTime),
                        ),
                        _buildInfoRow(
                          context,
                          Icons.access_time_filled,
                          'End Time',
                          DateFormat('HH:mm').format(event.endTime),
                        ),
                        _buildInfoRow(
                          context,
                          Icons.location_on,
                          'Location',
                          event.location,
                        ),
                        _buildInfoRow(
                          context,
                          Icons.person,
                          'Created By',
                          'Administrator',
                        ),
                        _buildInfoRow(
                          context,
                          Icons.info,
                          'Status',
                          event.isActive ? 'Active' : 'Inactive',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (isAdmin)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final created = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CreateSurveyScreen(event: event),
                          ),
                        );
                        if (created == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Survey created successfully'),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.assignment_add),
                      label: const Text('Create Survey for this Event'),
                    ),
                  ),
                if (isAdmin) const SizedBox(height: 24),

                // Attendance Statistics
                Text(
                  'Attendance Statistics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Total',
                        eventAttendances.length.toString(),
                        Icons.people,
                        AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Present',
                        stats['present'].toString(),
                        Icons.check_circle,
                        AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Late',
                        stats['late'].toString(),
                        Icons.schedule,
                        AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Left Early',
                        stats['left_early'].toString(),
                        Icons.exit_to_app,
                        AppTheme.warningColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Absent',
                        stats['absent'].toString(),
                        Icons.cancel,
                        AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(), // Empty space for alignment
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Attendance by Department
                Text(
                  'Attendance by Department',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: Provider.of<AttendanceProvider>(context, listen: false)
                      .fetchDepartmentCounts(event.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ));
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Failed to load department counts', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      );
                    }
                    final raw = snapshot.data ?? [];
                    // Normalize into a map for quick lookup
                    final Map<String, int> counts = {};
                    for (final row in raw) {
                      final dep = (row['department'] ?? 'Unknown').toString();
                      final val = row['attended'] is int ? row['attended'] as int : int.tryParse('${row['attended']}') ?? 0;
                      counts[dep] = val;
                    }

                    // Fixed department order and color palette
                    const List<String> departments = ['BED', 'CASE', 'CABECS', 'COE', 'CHAP'];
                    final Map<String, Color> colors = {
                      'BED': const Color(0xffe74a3b),
                      'CASE': const Color(0xff1cc88a),
                      'CABECS': const Color(0xfff6c23e),
                      'COE': const Color(0xffff8c00),
                      'CHAP': const Color(0xffff6ea8),
                    };

                    // Build the display list including zero-count departments
                    final List<Map<String, dynamic>> display = [
                      for (final d in departments)
                        {
                          'department': d,
                          'attended': counts[d] ?? 0,
                        }
                    ];

                    // Optionally append other departments not in the fixed list
                    for (final entry in counts.entries) {
                      if (!departments.contains(entry.key)) {
                        display.add({'department': entry.key, 'attended': entry.value});
                      }
                    }

                    // Determine max for bar scaling
                    final max = display.map((m) => m['attended'] as int).fold<int>(0, (p, c) => c > p ? c : p);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final row in display)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        '${row['department']}',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final count = row['attended'] as int;
                                          final ratio = max == 0 ? 0.0 : (count / max);
                                          final barWidth = constraints.maxWidth * ratio;
                                          return Stack(
                                            children: [
                                              Container(
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius: BorderRadius.circular(7),
                                                ),
                                              ),
                                              Container(
                                                width: barWidth,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: (colors[row['department']] ?? AppTheme.primaryColor).withOpacity(0.9),
                                                  borderRadius: BorderRadius.circular(7),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 36,
                                      child: Text(
                                        '${row['attended']}',
                                        textAlign: TextAlign.right,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Attendance List
                Text(
                  'Attendance Records',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                if (eventAttendances.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
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
                        const SizedBox(height: 16),
                        Text(
                          'No attendance records',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Students will appear here after marking attendance',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ...eventAttendances.map((attendance) => _buildAttendanceCard(context, attendance)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final timeFormat = DateFormat('HH:mm');
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (attendance.status) {
      case 'present':
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle;
        statusText = 'PRESENT';
        break;
      case 'late':
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.schedule;
        statusText = 'LATE';
        break;
      case 'left_early':
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.exit_to_app;
        statusText = 'LEFT EARLY';
        break;
      case 'absent':
        statusColor = AppTheme.errorColor;
        statusIcon = Icons.cancel;
        statusText = 'ABSENT';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        statusText = 'UNKNOWN';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attendance.studentName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.login,
                            size: 16,
                            color: AppTheme.successColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'In: ${timeFormat.format(attendance.checkInTime)}',
                            style: TextStyle(
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (attendance.checkOutTime != null) ...[
                            const SizedBox(width: 16),
                            Icon(
                              Icons.logout,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Out: ${timeFormat.format(attendance.checkOutTime!)}',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Badge with Edit Button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Edit Status Button
                    GestureDetector(
                      onTap: () => _showStatusEditDialog(context, attendance),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primaryColor),
                        ),
                        child: Icon(
                          Icons.edit,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusEditDialog(BuildContext context, Attendance attendance) {
    String selectedStatus = attendance.status;
    String? notes = attendance.notes;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.edit,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  const Text('Edit Attendance Status'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student: ${attendance.studentName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Status Selection
                  Text(
                    'Status:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildStatusChip(
                        context,
                        'present',
                        'Present',
                        AppTheme.successColor,
                        selectedStatus,
                        (status) => setState(() => selectedStatus = status),
                      ),
                      _buildStatusChip(
                        context,
                        'late',
                        'Late',
                        AppTheme.warningColor,
                        selectedStatus,
                        (status) => setState(() => selectedStatus = status),
                      ),
                      _buildStatusChip(
                        context,
                        'left_early',
                        'Left Early',
                        AppTheme.warningColor,
                        selectedStatus,
                        (status) => setState(() => selectedStatus = status),
                      ),
                      _buildStatusChip(
                        context,
                        'absent',
                        'Absent',
                        AppTheme.errorColor,
                        selectedStatus,
                        (status) => setState(() => selectedStatus = status),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Notes Field
                  Text(
                    'Notes (Optional):',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Add notes about this status change...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    controller: TextEditingController(text: notes ?? ''),
                    onChanged: (value) => notes = value,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return const AlertDialog(
                          content: Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 16),
                              Text('Updating status...'),
                            ],
                          ),
                        );
                      },
                    );

                    try {
                      // Update the attendance status
                      final updatedAttendance = attendance.copyWith(
                        status: selectedStatus,
                        notes: (notes?.isEmpty ?? true) ? null : notes,
                      );

                      // Update through provider
                      final success = await Provider.of<AttendanceProvider>(
                        context,
                        listen: false,
                      ).updateAttendance(updatedAttendance);

                      // Close loading dialog
                      Navigator.of(context).pop();

                      if (success) {
                        // Close edit dialog
                        Navigator.of(context).pop();
                        
                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Status updated to: ${selectedStatus.toUpperCase()}'),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                      } else {
                        // Show error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to update status'),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                      }
                    } catch (e) {
                      // Close loading dialog
                      Navigator.of(context).pop();
                      
                      // Show error message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppTheme.errorColor,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChip(
    BuildContext context,
    String status,
    String label,
    Color color,
    String selectedStatus,
    Function(String) onStatusSelected,
  ) {
    final isSelected = status == selectedStatus;
    
    return GestureDetector(
      onTap: () => onStatusSelected(status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
} 