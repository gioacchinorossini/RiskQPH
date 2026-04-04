import 'package:flutter/material.dart';

class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate([
        const SizedBox(height: 16),
        const Text(
          'Attendance History (placeholder)',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 400),
      ]),
    );
  }
}

