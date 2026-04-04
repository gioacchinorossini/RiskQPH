import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final qrData = user == null
        ? ''
        : base64Encode(utf8.encode(jsonEncode({'studentId': user.id})));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (user != null) ...[
              Text(
                user.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await Provider.of<AuthProvider>(context, listen: false).logout();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ] else ...[
              const Text('No user loaded'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Go to Login'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

