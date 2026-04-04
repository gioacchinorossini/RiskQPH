import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../providers/attendance_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/event.dart';
import '../../utils/theme.dart';

class QRScannerScreen extends StatefulWidget {
  final Event? selectedEvent;

  const QRScannerScreen({super.key, this.selectedEvent});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
    detectionSpeed: DetectionSpeed.normal, // Changed to normal for continuous scanning
    formats: [BarcodeFormat.qrCode],
  );
  bool _isProcessing = false;
  String? _lastScannedData;
  String? _lastAction;
  String? _lastStudentName;
  
  
  // New state variables for continuous scanning
  bool _isCheckoutEnabled = false;
  Set<String> _recentlyScannedQRCodes = {};
  Timer? _cleanupTimer;
  Timer? _duplicateMessageTimer;
  bool _showingDuplicateMessage = false;
  bool _showingSuccessMessage = false;
  String? _successStudentName;
  String? _successAction;
  bool _isScanCooldown = false;
  int _cooldownDefaultSeconds = 2; // default cooldown duration (seconds)
  int _cooldownSeconds = 2;
  Timer? _cooldownTimer;

  // Event selection for offline mode
  Event? _selectedEvent;
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize selected event
    _selectedEvent = widget.selectedEvent;
    _isOfflineMode = _selectedEvent != null;
    
    // Cleanup recently scanned codes every 60 seconds (less frequent since we're using smart detection)
    _cleanupTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _cleanupRecentlyScannedCodes();
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _duplicateMessageTimer?.cancel();
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
    if (_isScanCooldown) return; // suppress during cooldown
    if (_showingDuplicateMessage) return;
    
    setState(() {
      _showingDuplicateMessage = true;
    });
    
    // Don't auto-reset the flag - let it stay until a new QR is detected
    // The flag will be cleared when a new QR code is detected
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

  void _showSuccessMessage(String studentName, String action) {
    setState(() {
      _showingSuccessMessage = true;
      _successStudentName = studentName;
      _successAction = action;
    });
    
    // Start cooldown immediately with success message
    _startScanCooldown();
  }

  void _startScanCooldown() {
    setState(() {
      _isScanCooldown = true;
      // reset to current default every time cooldown starts
      _cooldownSeconds = _cooldownDefaultSeconds;
    });
    
    // Start countdown timer
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
            // Also clear success message when cooldown ends
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
            _isOfflineMode = true;
            // Clear recent scans when event changes
            _recentlyScannedQRCodes.clear();
            _showingDuplicateMessage = false;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<Event?> _showEventSelectionDialog() async {
    // Pause scanner during dialog
    await _controller.stop();
    
    // Load events first (outside of build context)
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Check connection status and load events accordingly
    if (authProvider.isConnected) {
      await eventProvider.loadEvents();
    } else {
      await eventProvider.loadEventsFromCache();
    }
    final events = eventProvider.events;
    
    if (events.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No events available. Please create an event first.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      // Resume scanner if no events available
      await _controller.start();
      return null;
    }

    final result = await showDialog<Event>(
      context: context,
      barrierDismissible: false, // User must select an event or cancel
      builder: (context) => AlertDialog(
        title: const Text('Select Event for Offline QR Code'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return ListTile(
                leading: const Icon(Icons.event),
                title: Text(event.title),
                subtitle: Text(
                  '${DateFormat('MMM dd, yyyy HH:mm').format(event.startTime)} - ${DateFormat('HH:mm').format(event.endTime)}',
                ),
                onTap: () {
                  Navigator.pop(context, event);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, null); // Cancel
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    // Resume scanner after dialog closes
    await _controller.start();
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner'),
        elevation: 0,
        actions: [
          // Refresh attendance data button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
              
              if (_isOfflineMode && _selectedEvent != null) {
                // Offline mode: refresh specific event
                await attendanceProvider.refreshAttendanceForEvent(_selectedEvent!.id);
              } else {
                // Auto event mode: refresh all attendance data
                await attendanceProvider.loadAttendances();
              }
              
              // Clear recently scanned QR codes to allow re-scanning after refresh
              setState(() {
                _recentlyScannedQRCodes.clear();
              });
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isOfflineMode 
                      ? 'Event attendance data refreshed - QR codes cleared'
                      : 'All attendance data refreshed - QR codes cleared'
                    ),
                    backgroundColor: AppTheme.successColor,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            tooltip: 'Refresh Attendance Data',
          ),
          // Event selector button
          IconButton(
            icon: const Icon(Icons.event),
            onPressed: _showEventSelector,
            tooltip: 'Select Event',
          ),
          // Checkout toggle button
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
                      // Clear duplicate state and recent scans when toggled
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
          // Header
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
                  'QR Scanner',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                        Icons.sync,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Continuous Scanning Active',
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

                  
                  // Real Scanner
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          MobileScanner(
                        controller: _controller,
                        onDetect: (capture) async {
                              if (_isProcessing || _isScanCooldown) return;
                          final barcodes = capture.barcodes;
                          if (barcodes.isEmpty) return;
                          final raw = barcodes.first.rawValue;
                          if (raw == null || raw.isEmpty) return;
                              
                              // Check for duplicate QR code (only for immediate duplicates)
                              if (_recentlyScannedQRCodes.contains(raw)) {
                                // Show duplicate message only if not already showing
                                if (!_showingDuplicateMessage) {
                                  _showDuplicateMessage();
                                }
                                return;
                              }
                              
                              // New QR code detected - clear any duplicate message state
                              if (_showingDuplicateMessage) {
                                setState(() {
                                  _showingDuplicateMessage = false;
                                });
                                _duplicateMessageTimer?.cancel();
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
                                  // Clear duplicate popup if showing before starting cooldown
                                  if (_showingDuplicateMessage) {
                                    _showingDuplicateMessage = false;
                                  }
                                });
                                // Cooldown will be started by _showSuccessMessage
                              }
                            },
                          ),
                          

                          
                          // Floating cooldown control (draggable) on the side
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

                  // Torch toggle
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
                      // Icon with background circle
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
                      
                      // Title
                      Text(
                        'Same QR Code',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Subtitle
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
                      
                      // Dismiss button
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
                      // Success icon with background circle
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
                      
                      // Title
                      Text(
                        _successAction == 'check_in' ? 'CHECKED IN' : 'CHECKED OUT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _successAction == 'check_in' ? AppTheme.successColor : AppTheme.primaryColor,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Student name
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
                      
                      // Success subtitle
                      Text(
                        'Successfully ${_successAction == 'check_in' ? 'checked in' : 'checked out'}!',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Cooldown section
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
      String eventId;
      String studentId;
      
      try {
        // Try to decode as base64 JSON first
        final decoded = utf8.decode(base64.decode(raw));
        final payload = jsonDecode(decoded) as Map<String, dynamic>;
        
        if (payload.containsKey('eventId') && payload.containsKey('studentId')) {
          // Traditional QR code with both eventId and studentId
          eventId = payload['eventId'].toString();
          studentId = payload['studentId'].toString();
        } else if (payload.containsKey('studentId')) {
          // Offline QR code with only studentId
          studentId = payload['studentId'].toString();
          
          if (_isOfflineMode) {
            // Offline mode: use selected event
            if (_selectedEvent == null) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No event selected for offline mode. Please select an event first.'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
              return;
            }
            eventId = _selectedEvent!.id;
          } else {
            // Auto event mode: show event selection popup
            final selectedEvent = await _showEventSelectionDialog();
            if (selectedEvent == null) {
              // User cancelled event selection
              return;
            }
            eventId = selectedEvent.id;
          }
        } else {
          // Try to parse as plain student ID for offline mode
          studentId = raw;
          
          if (_isOfflineMode) {
            // Offline mode: use selected event
            if (_selectedEvent == null) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No event selected for offline mode. Please select an event first.'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
              return;
            }
            eventId = _selectedEvent!.id;
          } else {
            // Auto event mode: show event selection popup
            final selectedEvent = await _showEventSelectionDialog();
            if (selectedEvent == null) {
              // User cancelled event selection
              return;
            }
            eventId = selectedEvent.id;
          }
        }
      } catch (e) {
        // If base64 decoding fails, treat raw as student ID for offline mode
        studentId = raw;
        
        if (_isOfflineMode) {
          // Offline mode: use selected event
          if (_selectedEvent == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No event selected for offline mode. Please select an event first.'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
            return;
          }
          eventId = _selectedEvent!.id;
        } else {
          // Auto event mode: show event selection popup
          final selectedEvent = await _showEventSelectionDialog();
          if (selectedEvent == null) {
            // User cancelled event selection
            return;
          }
          eventId = selectedEvent.id;
        }
      }

      // Get current attendance status first
      final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
      final currentStatus = attendanceProvider.getCurrentAttendanceStatus(eventId, studentId);
      
      // Check if checkout is enabled and validate student status
      if (_isCheckoutEnabled) {
        if (currentStatus == 'not_checked_in') {
          // Student not checked in, but checkout mode is enabled
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
          // Student already checked out - add to recently scanned to prevent immediate re-scan
          _recentlyScannedQRCodes.add(raw);
          if (mounted) {
            _showAlreadyProcessedMessage('Student', 'checked out');
          }
          return;
        }
      } else {
        // Check-in mode - check if student is already checked in
        if (currentStatus == 'checked_in') {
          // Student already checked in - add to recently scanned to prevent immediate re-scan
          _recentlyScannedQRCodes.add(raw);
          if (mounted) {
            _showAlreadyProcessedMessage('Student', 'checked in');
          }
          return;
        }
      }

      // For offline mode, we need to create proper QR code data with studentId
      String qrCodeDataToSend;
      if (_isOfflineMode) {
        // Create QR code data with only studentId for offline mode
        final offlinePayload = jsonEncode({
          'studentId': studentId,
        });
        qrCodeDataToSend = base64Encode(utf8.encode(offlinePayload));
        
        // Debug info
        if (mounted) {
          print('Offline Mode: Event ID = $eventId, Student ID = $studentId');
          print('Offline QR Data: $qrCodeDataToSend');
        }
      } else {
        // Use original QR code data for traditional mode
        qrCodeDataToSend = raw;
        
        // Debug info
        if (mounted) {
          print('Traditional Mode: Using original QR data');
        }
      }

      final result = await Provider.of<AttendanceProvider>(context, listen: false)
          .markAttendance(
            eventId: eventId,
            studentId: studentId,
            studentName: 'Student',
            qrCodeData: qrCodeDataToSend,
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

        // Kept for future UI enhancements; currently not used
        
        // Show success popup instead of SnackBar
        _showSuccessMessage(studentName, action);
      } else {
        // Check for restriction error messages
        final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
        final errorMessage = attendanceProvider.error ?? 'Failed to mark attendance. Please try again.';
        
        // Check if it's a restriction error
        bool isRestrictionError = false;
        String restrictionType = '';
        String restrictionValue = '';
        
        if (errorMessage.contains('restricted to department:')) {
          isRestrictionError = true;
          restrictionType = 'department';
          restrictionValue = errorMessage.split('restricted to department:').last.trim();
        } else if (errorMessage.contains('restricted to year level:')) {
          isRestrictionError = true;
          restrictionType = 'year level';
          restrictionValue = errorMessage.split('restricted to year level:').last.trim();
        }
        
        if (isRestrictionError) {
          // Show restriction error with special styling
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.block, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Access Restricted',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This event is restricted to $restrictionType: $restrictionValue',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              backgroundColor: Colors.orange[700],
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          // Show regular error
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
                  'Select Event for Offline Mode',
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
              'Choose an event to scan offline QR codes for:',
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
    _anim3 = Tween<double>(begin: 0.3, end: 1.0).animate(
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