import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/event.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';

class QRCodeScreen extends StatelessWidget {
  final Event event;

  const QRCodeScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final qrPayload = jsonEncode({
      'eventId': event.id,
      'studentId': user?.id,
    });
    final qrData = base64Encode(utf8.encode(qrPayload));
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Event Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          event.location,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (user != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildUserDetailsGrid(context, user, dateFormat),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 32),

            // QR Code
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Show this QR code to mark attendance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 250,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.successColor),
                    ),
                    child: Text(
                      'Valid for this event only',
                      style: TextStyle(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildInstruction(
                      context,
                      Icons.qr_code,
                      'Show this QR code to the administrator or scanner',
                    ),
                    _buildInstruction(
                      context,
                      Icons.access_time,
                      'QR code is valid only for this specific event',
                    ),
                    _buildInstruction(
                      context,
                      Icons.security,
                      'Your attendance will be automatically recorded',
                    ),
                    _buildInstruction(
                      context,
                      Icons.info,
                      'Make sure you are at the correct location',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Warning
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warningColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: AppTheme.warningColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Do not share this QR code with others. It is unique to you and this event.',
                      style: TextStyle(
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstruction(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetailsGrid(BuildContext context, User user, DateFormat dateFormat) {
    final List<Widget> items = [];
    if (user.studentId.isNotEmpty) {
      items.add(_buildUserDetail(context, Icons.badge, 'Student ID', user.studentId));
    }
    if (user.department.isNotEmpty) {
      items.add(_buildUserDetail(context, Icons.school, 'Department', user.department));
    }
    if (user.yearLevel.isNotEmpty) {
      items.add(_buildUserDetail(context, Icons.class_, 'Year Level', user.yearLevel));
    }
    if (user.gender.isNotEmpty) {
      items.add(_buildUserDetail(context, Icons.people_alt, 'Gender', user.gender));
    }
    if (user.birthdate != null) {
      items.add(_buildUserDetail(context, Icons.cake, 'Birthdate', dateFormat.format(user.birthdate!)));
    }

    // If we have items, display them in a more flexible layout
    if (items.isNotEmpty) {
      return Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: item,
        )).toList(),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildUserDetail(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[800],
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: value),
                ],
              ),
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }
} 