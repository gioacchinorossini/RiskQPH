import 'package:flutter/material.dart';
import '../models/event.dart';

class EventProvider extends ChangeNotifier {
  final List<Event> _events = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  List<Event> getStudentVisibleEvents() {
    final now = DateTime.now();
    return _events.where((e) => e.endTime.isAfter(now)).toList();
  }

  List<Event> getPastEvents() {
    final now = DateTime.now();
    return _events.where((e) => e.endTime.isBefore(now)).toList();
  }

  Future<void> loadEvents() async {
    _isLoading = true;
    notifyListeners();
    // TODO: Fetch from API
    await Future.delayed(const Duration(milliseconds: 300));
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadEventsFromCache() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 150));
    _isLoading = false;
    notifyListeners();
  }

  void startConnectivityMonitoring() {}
}

