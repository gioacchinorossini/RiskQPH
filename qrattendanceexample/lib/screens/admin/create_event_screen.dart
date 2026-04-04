import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../utils/theme.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  // Locations state
  List<String> _locations = [];
  String? _selectedLocation;
  bool _loadingLocations = false;
  String? _locationsError;

  // Organizers state
  List<String> _organizers = [];
  String? _selectedOrganizer;
  bool _loadingOrganizers = false;
  String? _organizersError;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _loadOrganizers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  children: [
                    Icon(
                      Icons.event,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create New Event',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add a new event for students to attend',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Event Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  prefixIcon: Icon(Icons.title),
                  hintText: 'Enter event title',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter event title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Organizer Dropdown
              DropdownButtonFormField<String>(
                value: (_selectedOrganizer != null && _selectedOrganizer!.isNotEmpty) ? _selectedOrganizer : null,
                items: _organizers
                    .map((name) => DropdownMenuItem<String>(
                          value: name,
                          child: Text(name),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedOrganizer = val;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Organizer (optional)',
                  prefixIcon: const Icon(Icons.groups),
                  suffixIcon: IconButton(
                    icon: _loadingOrganizers
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    onPressed: _loadingOrganizers ? null : _loadOrganizers,
                    tooltip: 'Reload organizers',
                  ),
                ),
                hint: const Text('Select organizer'),
              ),
              if (_organizersError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _organizersError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 16),

              // Event Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                  hintText: 'Enter event description',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter event description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Event Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on),
                  hintText: 'Enter event location',
                ),
                validator: (value) {
                  final hasTyped = value != null && value.trim().isNotEmpty;
                  final hasSelected = _selectedLocation != null && _selectedLocation!.trim().isNotEmpty;
                  if (!hasTyped && !hasSelected) {
                    return 'Please select a saved location or enter one';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: (_selectedLocation != null && _selectedLocation!.isNotEmpty) ? _selectedLocation : null,
                items: _locations
                    .map((name) => DropdownMenuItem<String>(
                          value: name,
                          child: Text(name),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedLocation = val;
                    _locationController.text = val ?? '';
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Saved Locations',
                  prefixIcon: const Icon(Icons.place),
                  suffixIcon: IconButton(
                    icon: _loadingLocations
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    onPressed: _loadingLocations ? null : _loadLocations,
                    tooltip: 'Reload locations',
                  ),
                ),
                hint: const Text('Select from saved locations'),
              ),
              if (_locationsError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _locationsError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 16),

              // Date and Time Selection
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(_selectedDate),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Start and End Time Selection
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectStartTime(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start Time',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  _startTime.format(context),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectEndTime(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_filled),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'End Time',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  _endTime.format(context),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Create Button
              Consumer<EventProvider>(
                builder: (context, eventProvider, child) {
                  return ElevatedButton(
                    onPressed: eventProvider.isLoading ? null : _createEvent,
                    child: eventProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Create Event'),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Error Message
              Consumer<EventProvider>(
                builder: (context, eventProvider, child) {
                  if (eventProvider.error != null) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.errorColor),
                      ),
                      child: Text(
                        eventProvider.error!,
                        style: TextStyle(color: AppTheme.errorColor),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
        // Ensure end time is after start time
        if (_endTime.hour < _startTime.hour || 
            (_endTime.hour == _startTime.hour && _endTime.minute <= _startTime.minute)) {
          _endTime = TimeOfDay(
            hour: _startTime.hour + 1,
            minute: _startTime.minute,
          );
        }
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null && picked != _endTime) {
      // Validate that end time is after start time
      if (picked.hour > _startTime.hour || 
          (picked.hour == _startTime.hour && picked.minute > _startTime.minute)) {
        setState(() {
          _endTime = picked;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End time must be after start time'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _createEvent() async {
    if (_formKey.currentState!.validate()) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user == null) return;

      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      final success = await Provider.of<EventProvider>(context, listen: false).createEvent(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        startTime: startDateTime,
        endTime: endDateTime,
        location: (_selectedLocation != null && _selectedLocation!.trim().isNotEmpty)
            ? _selectedLocation!.trim()
            : _locationController.text.trim(),
        createdBy: user.id,
        organizer: (_selectedOrganizer != null && _selectedOrganizer!.trim().isNotEmpty)
            ? _selectedOrganizer!.trim()
            : null,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event created successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadLocations() async {
    setState(() {
      _loadingLocations = true;
      _locationsError = null;
    });
    try {
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/locations/list.php');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body) as Map<String, dynamic>;
        final List<dynamic> list = data['locations'] ?? [];
        final names = list
            .map((e) => (e as Map<String, dynamic>)['name'] as String? ?? '')
            .where((s) => s.trim().isNotEmpty)
            .cast<String>()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        setState(() {
          _locations = names;
          // Keep selected if still present
          if (_selectedLocation != null && !_locations.contains(_selectedLocation)) {
            _selectedLocation = null;
          }
        });
      } else {
        setState(() {
          _locationsError = 'Failed to load locations';
        });
      }
    } catch (e) {
      setState(() {
        _locationsError = 'Failed to load locations: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocations = false;
        });
      }
    }
  }

  Future<void> _loadOrganizers() async {
    setState(() {
      _loadingOrganizers = true;
      _organizersError = null;
    });
    try {
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/organizers/list.php');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body) as Map<String, dynamic>;
        final List<dynamic> list = data['organizers'] ?? [];
        final names = list
            .map((e) => (e as Map<String, dynamic>)['name'] as String? ?? '')
            .where((s) => s.trim().isNotEmpty)
            .cast<String>()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        setState(() {
          _organizers = names;
          if (_selectedOrganizer != null && !_organizers.contains(_selectedOrganizer)) {
            _selectedOrganizer = null;
          }
        });
      } else {
        setState(() {
          _organizersError = 'Failed to load organizers';
        });
      }
    } catch (e) {
      setState(() {
        _organizersError = 'Failed to load organizers: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingOrganizers = false;
        });
      }
    }
  }
} 