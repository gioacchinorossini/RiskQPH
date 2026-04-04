import 'package:flutter/material.dart';

class AttendanceProvider extends ChangeNotifier {
  Future<void> loadAttendances() async {
    await Future.delayed(const Duration(milliseconds: 150));
  }
}

