import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../providers/attendance_provider.dart';
import '../../providers/event_provider.dart';
// import '../../providers/auth_provider.dart';
import '../../models/event.dart';
import '../../utils/theme.dart';

class OfflineQRScannerScreen extends StatefulWidget {
  final Event? selectedEvent;

  const OfflineQRScannerScreen({super.key, this.selectedEvent});

  @override
  State<OfflineQRScannerScreen> createState() => _OfflineQRScannerScreenState();
}

class _OfflineQRScannerScreenState extends State<OfflineQRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
    detectionSpeed: DetectionSpeed.normal,
    formats: [BarcodeFormat.qrCode],
  );
  
  bool _isProcessing = false;
  String? _lastScannedData;
  String? _lastAction;
  String? _lastStudentName;
  
  
  // Offline scanning state
  Event? _selectedEvent;
  bool _isCheckoutEnabled = false;
  Set<String> _recentlyScannedQRCodes = {};
  Timer? _cleanupTimer;
  bool _showingDuplicateMessage = false;
  bool _showingSuccessMessage = false;
  String? _successStudentName;
  String? _successAction;
  bool _isScanCooldown = false;
  int _cooldownDefaultSeconds = 2;
  int _cooldownSeconds = 2;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    
    // Initialize selected event
    _selectedEvent = widget.selectedEvent;
    
    // Cleanup recently scanned codes every 60 seconds
    _cleanupTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _cleanupRecentlyScannedCodes();
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _cooldownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
  

  void _cleanupRecentlyScannedCodes() {
    setState(() {
      _recentlyScannedQRCodes.clear();
    });
  }

  void _showDuplicateMessage() {
    if (_isScanCooldown) return;
    if (_showingDuplicateMessage) return;
    
    setState(() {
      _showingDuplicateMessage = true;
    });
  }

  void _showSuccessMessage(String studentName, String action) {
    setState(() {
      _showingSuccessMessage = true;
      _successStudentName = studentName;
      _successAction = action;
    });
    
    _startScanCooldown();
  }

  void _startScanCooldown() {
    setState(() {
      _isScanCooldown = true;
      _cooldownSeconds = _cooldownDefaultSeconds;
    });
    
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _cooldownSeconds--;
        });
        
        if (_cooldownSeconds <= 0) {
          timer.cancel();
          setState(() {
            _isScanCooldown = false;
            _cooldownSeconds = _cooldownDefaultSeconds;
            _showingSuccessMessage = false;
            _successStudentName = null;
            _successAction = null;
          });
        }
      }
    });
  }

  void _showEventSelector() {
    showDialog(
      context: context,
      builder: (context) => _EventSelectorDialog(
        currentEvent: _selectedEvent,
        onEventSelected: (event) {
          setState(() {
            _selectedEvent = event;
            _recentlyScannedQRCodes.clear();
            _showingDuplicateMessage = false;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline QR Scanner'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.event),
            onPressed: _showEventSelector,
            tooltip: 'Select Event',
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  Icons.logout,
                  color: _isCheckoutEnabled ? Colors.white : Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _isCheckoutEnabled,
                  onChanged: (value) {
                    setState(() {
                      _isCheckoutEnabled = value;
                      _showingDuplicateMessage = false;
                      _recentlyScannedQRCodes.clear();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value ? 'Checkout mode ENABLED' : 'Checkout mode DISABLED',
                        ),
                        backgroundColor: value ? AppTheme.primaryColor : Colors.grey,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  activeColor: Colors.white,
                  activeTrackColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              
              // Event Selection Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Offline QR Scanner',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedEvent != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Event: ${_selectedEvent!.title}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('MMM dd, yyyy HH:mm').format(_selectedEvent!.startTime),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning,
                              color: Colors.orange[300],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'No Event Selected',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _isCheckoutEnabled 
                          ? 'Checkout mode: Students can check out'
                          : 'Check-in mode: Students can check in',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.offline_bolt,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Offline Mode Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Scanner Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Event selection prompt if no event selected
                      if (_selectedEvent == null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 48,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Please Select an Event',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You need to select an event before scanning QR codes',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.orange[600]),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _showEventSelector,
                                icon: const Icon(Icons.event),
                                label: const Text('Select Event'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[700],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        // Real Scanner
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                MobileScanner(
                                  controller: _controller,
                                  onDetect: (capture) async {
                                    if (_isProcessing || _isScanCooldown || _selectedEvent == null) return;
                                    
                                    final barcodes = capture.barcodes;
                                    if (barcodes.isEmpty) return;
                                    final raw = barcodes.first.rawValue;
                                    if (raw == null || raw.isEmpty) return;
                                    
                                    // Check for duplicate QR code
                                    if (_recentlyScannedQRCodes.contains(raw)) {
                                      if (!_showingDuplicateMessage) {
                                        _showDuplicateMessage();
                                      }
                                      return;
                                    }
                                    
                                    // New QR code detected - clear duplicate message
                                    if (_showingDuplicateMessage) {
                                      setState(() {
                                        _showingDuplicateMessage = false;
                                      });
                                    }
                                    
                                    setState(() { 
                                      _isProcessing = true; 
                                      _lastScannedData = raw;
                                      _recentlyScannedQRCodes.add(raw);
                                    });
                                    
                                    await _handleDecoded(raw);
                                    
                                    if (mounted) {
                                      setState(() {
                                        _isProcessing = false;
                                        if (_showingDuplicateMessage) {
                                          _showingDuplicateMessage = false;
                                        }
                                      });
                                    }
                                  },
                                ),
                                
                                // Floating cooldown control
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: _CooldownFloatingControl(
                                    seconds: _cooldownDefaultSeconds,
                                    onIncrease: () {
                                      setState(() {
                                        if (_cooldownDefaultSeconds < 10) {
                                          _cooldownDefaultSeconds++;
                                        }
                                      });
                                    },
                                    onDecrease: () {
                                      setState(() {
                                        if (_cooldownDefaultSeconds > 1) {
                                          _cooldownDefaultSeconds--;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Camera controls
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _controller.toggleTorch(),
                                icon: const Icon(Icons.flash_on),
                                label: const Text('Toggle Torch'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _controller.switchCamera(),
                                icon: const Icon(Icons.cameraswitch),
                                label: const Text('Switch Camera'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Last scan result
                        if (_lastScannedData != null && _lastAction != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _lastAction == 'check_in' 
                                  ? AppTheme.successColor.withOpacity(0.1)
                                  : AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _lastAction == 'check_in' 
                                    ? AppTheme.successColor
                                    : AppTheme.primaryColor,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _lastAction == 'check_in' 
                                          ? Icons.login 
                                          : Icons.logout,
                                      color: _lastAction == 'check_in' 
                                          ? AppTheme.successColor
                                          : AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _lastAction == 'check_in' ? 'CHECKED IN' : 'CHECKED OUT',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _lastAction == 'check_in' 
                                            ? AppTheme.successColor
                                            : AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_lastStudentName != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Student: $_lastStudentName',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'QR Data: ${_lastScannedData!.substring(0, 20)}...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Duplicate QR code warning popup overlay
          if (_showingDuplicateMessage)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.orange[700]!.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.repeat,
                          color: Colors.orange[700],
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Same QR Code',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Waiting for different student',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      _ThreeDotsLoading(color: Colors.orange),
                      const SizedBox(height: 32),
                      Container(
                        width: 120,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.orange[700],
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _showingDuplicateMessage = false;
                            });
                          },
                          child: const Text(
                            'Dismiss',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
          // Success popup overlay with cooldown
          if (_showingSuccessMessage && _isScanCooldown)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  width: 280,
                  height: 320,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: (_successAction == 'check_in' ? AppTheme.successColor : AppTheme.primaryColor).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _successAction == 'check_in' ? Icons.login : Icons.logout,
                          color: _successAction == 'check_in' ? AppTheme.successColor : AppTheme.primaryColor,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _successAction == 'check_in' ? 'CHECKED IN' : 'CHECKED OUT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _successAction == 'check_in' ? AppTheme.successColor : AppTheme.primaryColor,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_successStudentName != null) ...[
                        Text(
                          _successStudentName!,
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        'Successfully ${_successAction == 'check_in' ? 'checked in' : 'checked out'}!',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue[200]!,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.timer,
                                  color: Colors.blue[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Scan Cooldown',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_cooldownSeconds seconds remaining',
                              style: TextStyle(
                                color: Colors.blue[600],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleDecoded(String raw) async {
    try {
      // For offline mode, QR codes only need student ID
      // The event ID comes from the selected event
      String studentId;
      
      try {
        // Try to decode as base64 JSON first (for backward compatibility)
        final decoded = utf8.decode(base64.decode(raw));
        final payload = jsonDecode(decoded) as Map<String, dynamic>;
        
        if (payload.containsKey('eventId') && payload.containsKey('studentId')) {
          // Full QR code with event ID - use student ID only
          studentId = payload['studentId'].toString();
        } else if (payload.containsKey('studentId')) {
          // QR code with only student ID
          studentId = payload['studentId'].toString();
        } else {
          // Try to parse as plain student ID
          studentId = raw;
        }
      } catch (e) {
        // If base64 decoding fails, treat raw as student ID
        studentId = raw;
      }

      if (_selectedEvent == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No event selected. Please select an event first.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      final eventId = _selectedEvent!.id;

      // Get current attendance status
      final currentStatus = Provider.of<AttendanceProvider>(context, listen: false)
          .getCurrentAttendanceStatus(eventId, studentId);
      
      // Check if checkout is enabled and validate student status
      if (_isCheckoutEnabled) {
        if (currentStatus == 'not_checked_in') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Student not checked in - cannot check out'),
                  ],
                ),
                backgroundColor: Colors.orange[700],
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        } else if (currentStatus == 'checked_out') {
          _recentlyScannedQRCodes.add(raw);
          if (mounted) {
            _showAlreadyProcessedMessage('Student', 'checked out');
          }
          return;
        }
      } else {
        // Check-in mode - check if student is already checked in
        if (currentStatus == 'checked_in') {
          _recentlyScannedQRCodes.add(raw);
          if (mounted) {
            _showAlreadyProcessedMessage('Student', 'checked in');
          }
          return;
        }
      }

      // Create QR code data with event ID for backend compatibility
      final qrCodeData = base64Encode(utf8.encode(jsonEncode({
        'eventId': eventId,
        'studentId': studentId,
      })));

      final result = await Provider.of<AttendanceProvider>(context, listen: false)
          .markAttendance(
            eventId: eventId,
            studentId: studentId,
            studentName: 'Student',
            qrCodeData: qrCodeData,
          );

      if (!mounted) return;
      
      if (result != null && result['success'] == true) {
        final action = result['action'] as String;
        final attendance = result['attendance'];
        final studentName = attendance.studentName;
        
        setState(() {
          _lastAction = action;
          _lastStudentName = studentName;
        });

        _showSuccessMessage(studentName, action);
      } else {
        final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
        final errorMessage = attendanceProvider.error ?? 'Failed to mark attendance. Please try again.';
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR code'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showAlreadyProcessedMessage(String studentName, String status) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 8),
            Text('$studentName already $status'),
          ],
        ),
        backgroundColor: Colors.blue[700],
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// Event Selector Dialog
class _EventSelectorDialog extends StatelessWidget {
  final Event? currentEvent;
  final Function(Event) onEventSelected;

  const _EventSelectorDialog({
    required this.currentEvent,
    required this.onEventSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Select Event for Offline Scanning',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Choose an event to scan QR codes for:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Consumer<EventProvider>(
                builder: (context, eventProvider, child) {
                  if (eventProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final events = eventProvider.events;
                  if (events.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No events available',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final isSelected = currentEvent?.id == event.id;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : null,
                        child: ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryColor : Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.event,
                              color: isSelected ? Colors.white : Colors.grey[600],
                            ),
                          ),
                          title: Text(
                            event.title,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppTheme.primaryColor : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('MMM dd, yyyy HH:mm').format(event.startTime),
                                style: TextStyle(
                                  color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
                                ),
                              ),
                              Text(
                                event.location,
                                style: TextStyle(
                                  color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          trailing: isSelected 
                              ? Icon(Icons.check_circle, color: AppTheme.primaryColor)
                              : null,
                          onTap: () => onEventSelected(event),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper classes (same as in main QR scanner)
class _CooldownFloatingControl extends StatefulWidget {
  final int seconds;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const _CooldownFloatingControl({
    required this.seconds,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  State<_CooldownFloatingControl> createState() => _CooldownFloatingControlState();
}

class _CooldownFloatingControlState extends State<_CooldownFloatingControl> {
  Offset _offset = const Offset(0, 0);

  @override
  Widget build(BuildContext context) {
    return Draggable(
      feedback: _buildControl(context, isFeedback: true),
      childWhenDragging: const SizedBox.shrink(),
      onDragEnd: (details) {
        setState(() {
          _offset = details.offset;
        });
      },
      child: _buildControl(context, offset: _offset),
    );
  }

  Widget _buildControl(BuildContext context, {Offset? offset, bool isFeedback = false}) {
    final control = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            '${widget.seconds}s',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          _RoundIconButton(icon: Icons.remove, onTap: widget.onDecrease),
          const SizedBox(width: 6),
          _RoundIconButton(icon: Icons.add, onTap: widget.onIncrease),
        ],
      ),
    );

    if (isFeedback) return control;

    return Transform.translate(
      offset: offset ?? Offset.zero,
      child: control,
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white24,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _ThreeDotsLoading extends StatefulWidget {
  final Color color;
  const _ThreeDotsLoading({required this.color});

  @override
  State<_ThreeDotsLoading> createState() => _ThreeDotsLoadingState();
}

class _ThreeDotsLoadingState extends State<_ThreeDotsLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim1;
  late final Animation<double> _anim2;
  late final Animation<double> _anim3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _anim1 = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeInOut)),
    );
    _anim2 = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8, curve: Curves.easeInOut)),
    );
    _anim3 = Tween<double>(begin: 0.3, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeInOut)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(_anim1),
          const SizedBox(width: 6),
          _buildDot(_anim2),
          const SizedBox(width: 6),
          _buildDot(_anim3),
        ],
      ),
    );
  }

  Widget _buildDot(Animation<double> anim) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        return Opacity(
          opacity: anim.value,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
} 