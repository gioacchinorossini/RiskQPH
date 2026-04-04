import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../../providers/attendance_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/event.dart';
import '../../models/user.dart';
import '../../config/api_config.dart';
import '../../utils/theme.dart';

class RFIDScannerScreen extends StatefulWidget {
  final Event? selectedEvent;

  const RFIDScannerScreen({super.key, this.selectedEvent});

  @override
  State<RFIDScannerScreen> createState() => _RFIDScannerScreenState();
}

class _RFIDScannerScreenState extends State<RFIDScannerScreen> {
  bool _isScanning = false;
  bool _isProcessing = false;
  String? _lastScannedData;
  String? _lastAction;
  String? _lastStudentName;
  String _statusMessage = 'Tap to start scanning NFC/RFID tags';
  bool _nfcAvailable = false;
  
  // State variables for continuous scanning
  bool _isCheckoutEnabled = false;
  Set<String> _recentlyScannedTags = {};
  Timer? _cleanupTimer;
  bool _showingDuplicateMessage = false;
  bool _showingSuccessMessage = false;
  String? _successStudentName;
  String? _successAction;
  bool _isScanCooldown = false;
  int _cooldownDefaultSeconds = 2;
  int _cooldownSeconds = 2;
  Timer? _cooldownTimer;

  // Event selection for offline mode
  Event? _selectedEvent;
  bool _isOfflineMode = false;
  
  // Write mode
  bool _isWriteMode = false;
  User? _selectedStudent;
  final TextEditingController _eventIdController = TextEditingController();
  List<User> _studentsList = [];
  bool _isLoadingStudents = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize selected event
    _selectedEvent = widget.selectedEvent;
    _isOfflineMode = _selectedEvent != null;
    
    // Check NFC availability
    _checkNFCAvailability();
    
    // Cleanup recently scanned tags every 60 seconds
    _cleanupTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _cleanupRecentlyScannedTags();
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _cooldownTimer?.cancel();
    _eventIdController.dispose();
    if (_isScanning) {
      NfcManager.instance.stopSession();
    }
    super.dispose();
  }

  Future<void> _checkNFCAvailability() async {
    try {
      final isAvailable = await NfcManager.instance.isAvailable();
      setState(() {
        _nfcAvailable = isAvailable;
        if (!isAvailable) {
          _statusMessage = 'NFC is not available on this device';
        }
      });
    } catch (e) {
      setState(() {
        _nfcAvailable = false;
        _statusMessage = 'Error checking NFC availability: $e';
      });
    }
  }

  void _cleanupRecentlyScannedTags() {
    setState(() {
      _recentlyScannedTags.clear();
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

  Future<void> _startNFCScan() async {
    if (!_nfcAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NFC is not available on this device'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_isScanning) {
      await NfcManager.instance.stopSession();
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scanning stopped';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = 'Hold device near NFC/RFID tag...';
    });

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          if (_isProcessing || _isScanCooldown) return;

          try {
            // Print raw tag data to console
            print('═══════════════════════════════════════');
            print('🔵 RFID TAG DETECTED');
            print('═══════════════════════════════════════');
            print('📋 Raw Tag Data:');
            print('   Tag Handle: ${tag.handle}');
            print('   Tag Data Keys: ${tag.data.keys.toList()}');
            print('   Full Tag Data: ${tag.data}');
            
            // Try to read NDEF data
            String? tagData;
            
            if (tag.data.containsKey('ndef')) {
              print('   📄 NDEF data found');
              final ndef = Ndef.from(tag);
              if (ndef != null) {
                try {
                  final ndefMessage = await ndef.read();
                  if (ndefMessage.records.isNotEmpty) {
                    final record = ndefMessage.records.first;
                    print('   📄 NDEF Record Type: ${record.typeNameFormat}');
                    print('   📄 NDEF Record Type Name: ${record.type}');
                    if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown) {
                      // For NFC Wellknown text records, the format is:
                      // Byte 0: Language code length (e.g., 2 for "en")
                      // Bytes 1-N: Language code (e.g., "en" = [101, 110])
                      // Bytes N+1-end: Actual text content (base64 encoded in this case)
                      if (record.payload.isNotEmpty) {
                        final languageCodeLength = record.payload[0] & 0x3F; // Lower 6 bits
                        print('   📄 Language Code Length: $languageCodeLength');
                        print('   📄 Raw Payload Bytes: ${record.payload}');
                        
                        if (record.payload.length > languageCodeLength + 1) {
                          // Extract text content (skip language code length byte and language code bytes)
                          final textBytes = record.payload.sublist(languageCodeLength + 1);
                          tagData = utf8.decode(textBytes);
                          print('   📄 Extracted Text Content (after skipping language code): $tagData');
                        } else {
                          // Fallback: treat entire payload as text (legacy format)
                          tagData = record.payload.map((e) => String.fromCharCode(e)).join();
                          print('   📄 Using entire payload as text (fallback): $tagData');
                        }
                      }
                    } else {
                      // For other record types, decode as UTF-8
                      tagData = utf8.decode(record.payload);
                      print('   📄 Decoded as UTF-8: $tagData');
                    }
                  }
                } catch (e) {
                  print('   ⚠️  NDEF read failed: $e');
                  // NDEF read failed, will fall back to tag ID
                }
              }
            }
            
            // If no NDEF data, use tag ID as fallback
            if (tagData == null || tagData.isEmpty) {
              print('   🏷️  No NDEF data, reading tag identifier...');
              final identifier = tag.data['nfca']?['identifier'] ?? 
                                tag.data['nfcb']?['identifier'] ?? 
                                tag.data['nfcf']?['identifier'] ?? 
                                tag.data['nfcv']?['identifier'];
              if (identifier != null) {
                tagData = identifier.map((e) => e.toRadixString(16).padLeft(2, '0')).join(':');
                print('   🏷️  Tag Identifier (Hex): $tagData');
                print('   🏷️  Tag Identifier (Raw): $identifier');
              } else {
                tagData = tag.handle.toString();
                print('   🏷️  Using Tag Handle: $tagData');
              }
            }

            if (tagData == null || tagData.isEmpty) {
              print('   ❌ ERROR: Could not read tag data');
              setState(() {
                _statusMessage = 'Could not read tag data';
              });
              return;
            }

            // At this point, tagData is guaranteed to be non-null and non-empty
            final finalTagData = tagData;
            
            print('   ✅ Final Tag Data: $finalTagData');
            print('═══════════════════════════════════════');

            // Check for duplicate tag
            if (_recentlyScannedTags.contains(finalTagData)) {
              print('   ⚠️  DUPLICATE TAG DETECTED - Ignoring scan');
              if (!_showingDuplicateMessage) {
                _showDuplicateMessage();
              }
              return;
            }

            // Clear duplicate message if showing
            if (_showingDuplicateMessage) {
              setState(() {
                _showingDuplicateMessage = false;
              });
            }

            print('   📤 Processing tag data...');
            setState(() {
              _isProcessing = true;
              _lastScannedData = finalTagData;
              _recentlyScannedTags.add(finalTagData);
            });

            await _handleTagData(finalTagData);

            if (mounted) {
              setState(() {
                _isProcessing = false;
                if (_showingDuplicateMessage) {
                  _showingDuplicateMessage = false;
                }
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _isProcessing = false;
                _statusMessage = 'Error reading tag: $e';
              });
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Error starting NFC scan: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('NFC scan error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<Event?> _showEventSelectionDialog() async {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
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
      return null;
    }

    final result = await showDialog<Event>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Select Event for Offline Mode'),
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
              Navigator.pop(context, null);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    return result;
  }

  Future<void> _loadStudents() async {
    if (_studentsList.isNotEmpty) return; // Already loaded
    
    setState(() {
      _isLoadingStudents = true;
    });

    try {
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/users/list.php');
      print('Loading students from: $uri');
      final response = await http.get(uri);
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final List<dynamic> usersList = data['users'] ?? [];
          print('Total users from API: ${usersList.length}');
          
          // Filter students - check role case-insensitively
          final studentUsers = usersList.where((u) {
            final userMap = u as Map<String, dynamic>;
            final role = userMap['role']?.toString().toLowerCase() ?? '';
            print('User: ${userMap['name']}, Role: $role');
            return role == 'student';
          }).toList();
          
          print('Filtered students: ${studentUsers.length}');
          
          // If no students found, show all users (admins may need to write any user to RFID)
          final List<dynamic> usersToShow = studentUsers.isNotEmpty ? studentUsers : usersList;
          if (studentUsers.isEmpty) {
            print('No students found with role="student", showing all users instead');
          }
          
          // Convert to User objects, handling field name differences
          final List<User> students = [];
          for (var userData in usersToShow) {
            try {
              final userMap = userData as Map<String, dynamic>;
              // Map API field names to User model field names
              final mappedUser = {
                'id': userMap['id'],
                'name': userMap['name'],
                'email': userMap['email'],
                'studentId': userMap['student_id'] ?? userMap['studentId'] ?? '',
                'yearLevel': userMap['year_level'] ?? userMap['yearLevel'] ?? '',
                'department': userMap['department'] ?? '',
                'course': userMap['course'] ?? '',
                'gender': userMap['gender'] ?? '',
                'birthdate': userMap['birthdate'],
                'role': userMap['role'],
                'createdAt': userMap['created_at'] ?? userMap['createdAt'],
                'updatedAt': userMap['updated_at'] ?? userMap['updatedAt'] ?? userMap['created_at'] ?? userMap['createdAt'],
              };
              students.add(User.fromJson(mappedUser));
            } catch (e) {
              print('Error parsing user: $e, User data: $userData');
            }
          }
          
          setState(() {
            _studentsList = students;
            _isLoadingStudents = false;
          });
          
          print('Successfully loaded ${_studentsList.length} users');
        } else {
          print('API returned success=false: ${data['message']}');
          setState(() {
            _isLoadingStudents = false;
          });
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        setState(() {
          _isLoadingStudents = false;
        });
      }
    } catch (e, stackTrace) {
      print('Error loading students: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _isLoadingStudents = false;
      });
    }
  }

  Future<void> _showStudentSelectionDialog() async {
    await _loadStudents();
    
    if (!mounted) return;

    final TextEditingController searchController = TextEditingController();
    List<User> filteredStudents = List.from(_studentsList);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
            void filterStudents(String query) {
              setDialogState(() {
                if (query.isEmpty) {
                  filteredStudents = List.from(_studentsList);
                } else {
                  filteredStudents = _studentsList.where((student) {
                    final queryLower = query.toLowerCase();
                    return student.name.toLowerCase().contains(queryLower) ||
                        student.studentId.toLowerCase().contains(queryLower) ||
                        student.email.toLowerCase().contains(queryLower);
                  }).toList();
                }
              });
            }

            return AlertDialog(
              title: const Text('Select Student'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Search',
                        hintText: 'Search by name, ID, or email',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchController.clear();
                                  filterStudents('');
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filterStudents(value);
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoadingStudents
                        ? const Center(child: CircularProgressIndicator())
                        : filteredStudents.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_outline,
                                        size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No students found',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: filteredStudents.length,
                                itemBuilder: (context, index) {
                                  final student = filteredStudents[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.primaryColor,
                                      child: Text(
                                        student.name.isNotEmpty
                                            ? student.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    title: Text(student.name),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('ID: ${student.studentId}'),
                                        if (student.email.isNotEmpty)
                                          Text('Email: ${student.email}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600])),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.pop(context, student);
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    ).then((selectedStudent) {
      if (selectedStudent != null && mounted) {
        setState(() {
          _selectedStudent = selectedStudent as User;
        });
      }
      searchController.dispose();
    });
  }

  void _showWriteDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Write Data to RFID Tag'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select student to write to RFID tag:'),
              const SizedBox(height: 16),
              // Student Selection Button
              InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  await _showStudentSelectionDialog();
                  if (_selectedStudent != null && mounted) {
                    _showWriteDataDialog(); // Reopen dialog with selected student
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: _selectedStudent != null
                            ? AppTheme.primaryColor
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedStudent?.name ?? 'Select Student',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedStudent != null
                                    ? Colors.black
                                    : Colors.grey[600],
                              ),
                            ),
                            if (_selectedStudent != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${_selectedStudent!.studentId}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_isOfflineMode) ...[
                TextField(
                  controller: _eventIdController,
                  decoration: const InputDecoration(
                    labelText: 'Event ID (Optional)',
                    hintText: 'Leave empty to write student ID only',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: If Event ID is provided, both will be written.\nIf left empty, only Student ID will be written (offline mode format).',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ] else ...[
                const Text(
                  'Offline mode: Only Student ID will be written to the tag.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isWriteMode = false;
                _selectedStudent = null;
              });
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_selectedStudent == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a student'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _startNFCWrite();
            },
            child: const Text('Start Writing'),
          ),
        ],
      ),
    );
  }

  Future<void> _startNFCWrite() async {
    if (!_nfcAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NFC is not available on this device'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a student'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final studentId = _selectedStudent!.studentId;

    setState(() {
      _isScanning = true;
      _statusMessage = 'Hold device near RFID tag to write...';
    });

    try {
      print('═══════════════════════════════════════');
      print('✍️  STARTING RFID WRITE OPERATION');
      print('═══════════════════════════════════════');
      print('📋 Data to Write:');
      print('   Student: ${_selectedStudent!.name}');
      print('   Student ID: $studentId');
      
      // Prepare data to write
      Map<String, dynamic> payload;
      String dataToWrite;
      
      if (_isOfflineMode || _eventIdController.text.trim().isEmpty) {
        // Offline mode format: only studentId
        payload = {'studentId': studentId};
        print('   📄 Format: Offline mode (studentId only)');
      } else {
        // Traditional mode: both eventId and studentId
        payload = {
          'eventId': _eventIdController.text.trim(),
          'studentId': studentId,
        };
        print('   📄 Format: Traditional mode (eventId + studentId)');
        print('   Event ID: ${payload['eventId']}');
      }
      
      // Encode as base64 JSON
      final jsonString = jsonEncode(payload);
      dataToWrite = base64Encode(utf8.encode(jsonString));
      print('   📄 JSON: $jsonString');
      print('   📄 Base64 Encoded: $dataToWrite');
      print('═══════════════════════════════════════');

      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            print('🔵 TAG DETECTED FOR WRITING');
            print('   Tag Handle: ${tag.handle}');
            
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              print('   ❌ ERROR: Tag does not support NDEF');
              if (mounted) {
                NfcManager.instance.stopSession();
                setState(() {
                  _isScanning = false;
                  _statusMessage = 'Tag does not support NDEF writing';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This tag does not support NDEF writing'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
              return;
            }

            if (!ndef.isWritable) {
              print('   ❌ ERROR: Tag is not writable');
              if (mounted) {
                NfcManager.instance.stopSession();
                setState(() {
                  _isScanning = false;
                  _statusMessage = 'Tag is not writable';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This tag is not writable'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
              return;
            }

            print('   ✅ Tag supports NDEF writing');
            
            // Check if tag has existing data
            try {
              final existingMessage = await ndef.read();
              if (existingMessage.records.isNotEmpty) {
                print('   ⚠️  WARNING: Tag contains existing data (will be overwritten)');
              }
            } catch (e) {
              print('   ℹ️  Tag appears to be empty or cannot read existing data');
            }
            
            print('   ✍️  Writing data to tag (overwriting any existing data)...');
            
            // Create NDEF message with text record
            // NOTE: This will OVERWRITE any existing data on the tag
            final ndefMessage = NdefMessage([
              NdefRecord.createText(dataToWrite),
            ]);
            
            await ndef.write(ndefMessage);
            
            print('   ✅ DATA WRITTEN SUCCESSFULLY!');
            print('═══════════════════════════════════════');
            
            if (mounted) {
              NfcManager.instance.stopSession();
              setState(() {
                _isScanning = false;
                _statusMessage = 'Data written successfully!';
              });
              
              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Data written successfully to RFID tag!\nStudent: ${_selectedStudent!.name}\nID: $studentId'),
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.successColor,
                  duration: const Duration(seconds: 4),
                ),
              );
              
              // Clear selected student and input fields
              setState(() {
                _selectedStudent = null;
              });
              _eventIdController.clear();
              
              // Optionally exit write mode
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() {
                    _statusMessage = 'Tap to start scanning NFC/RFID tags';
                  });
                }
              });
            }
          } catch (e) {
            print('   ❌ ERROR WRITING TO TAG: $e');
            print('   Error type: ${e.runtimeType}');
            if (e is PlatformException) {
              print('   Platform error code: ${e.code}');
              print('   Platform error message: ${e.message}');
              print('   Platform error details: ${e.details}');
            }
            print('═══════════════════════════════════════');
            
            if (mounted) {
              NfcManager.instance.stopSession();
              
              // Provide user-friendly error message
              String errorMessage = 'Failed to write data to tag. ';
              String detailedMessage = 'Please try again.';
              
              if (e is PlatformException) {
                final code = e.code.toLowerCase();
                final message = e.message ?? '';
                
                if (code.contains('io_exception') || code.contains('io')) {
                  errorMessage = 'Communication error with the tag. ';
                  detailedMessage = 'Make sure the tag is still near your device and try again. The tag might be locked, incompatible, or need to be formatted first.';
                } else if (code.contains('format') || code.contains('invalid')) {
                  errorMessage = 'Tag format error. ';
                  detailedMessage = 'This tag might not support the data format. Try formatting the tag first or use a different tag.';
                } else if (code.contains('read_only') || code.contains('locked')) {
                  errorMessage = 'Tag is read-only or locked. ';
                  detailedMessage = 'This tag cannot be written to. Please use a writable tag.';
                } else if (code.contains('not_enough_space') || code.contains('size')) {
                  errorMessage = 'Tag does not have enough space. ';
                  detailedMessage = 'The data is too large for this tag. Try a tag with more storage capacity.';
                } else if (message.isNotEmpty) {
                  detailedMessage = message;
                } else {
                  detailedMessage = 'Please ensure the tag is close to your device and try again.';
                }
              } else {
                detailedMessage = 'Please try again. Ensure the tag stays close to your device during writing.';
              }
              
              setState(() {
                _isScanning = false;
                _statusMessage = 'Write failed: ${errorMessage.trim()}';
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage.trim(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        detailedMessage,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.errorColor,
                  duration: const Duration(seconds: 6),
                  action: SnackBarAction(
                    label: 'OK',
                    textColor: Colors.white,
                    onPressed: () {},
                  ),
                ),
              );
            }
          }
        },
      );
    } catch (e) {
      print('   ❌ ERROR STARTING WRITE SESSION: $e');
      print('═══════════════════════════════════════');
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Error starting write: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting write operation: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _handleTagData(String tagData) async {
    print('═══════════════════════════════════════');
    print('🔵 PROCESSING RFID TAG DATA');
    print('═══════════════════════════════════════');
    print('📋 Received Tag Data: $tagData');
    
    try {
      String eventId;
      String studentId;
      
      try {
        // Try to decode as base64 JSON first
        print('   🔍 Attempting to decode as base64 JSON...');
        final decoded = utf8.decode(base64.decode(tagData));
        print('   📄 Decoded String: $decoded');
        final payload = jsonDecode(decoded) as Map<String, dynamic>;
        print('   📄 JSON Payload: $payload');
        
        if (payload.containsKey('eventId') && payload.containsKey('studentId')) {
          eventId = payload['eventId'].toString();
          studentId = payload['studentId'].toString();
          print('   ✅ Found both eventId and studentId');
          print('      Event ID: $eventId');
          print('      Student ID: $studentId');
        } else if (payload.containsKey('studentId')) {
          print('   ✅ Found studentId only');
          studentId = payload['studentId'].toString();
          print('      Student ID: $studentId');
          studentId = payload['studentId'].toString();
          
          if (_isOfflineMode) {
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
            final selectedEvent = await _showEventSelectionDialog();
            if (selectedEvent == null) {
              return;
            }
            eventId = selectedEvent.id;
          }
        } else {
          // Try to parse as plain student ID
          print('   ⚠️  No JSON structure found, treating as plain student ID');
          studentId = tagData;
          print('      Student ID: $studentId');
          
          if (_isOfflineMode) {
            print('   📍 Offline mode: Using selected event');
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
            final selectedEvent = await _showEventSelectionDialog();
            if (selectedEvent == null) {
              return;
            }
            eventId = selectedEvent.id;
          }
        }
      } catch (e) {
        // If base64 decoding fails, treat raw as student ID
        print('   ⚠️  Base64/JSON decoding failed: $e');
        print('   📍 Treating raw tag data as student ID');
        studentId = tagData;
        print('      Student ID: $studentId');
        
        if (_isOfflineMode) {
          print('   📍 Offline mode: Using selected event');
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
          final selectedEvent = await _showEventSelectionDialog();
          if (selectedEvent == null) {
            return;
          }
          eventId = selectedEvent.id;
        }
      }

      print('   ✅ Event ID determined: $eventId');
      print('   ✅ Student ID determined: $studentId');
      
      // Get current attendance status
      final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
      final currentStatus = attendanceProvider.getCurrentAttendanceStatus(eventId, studentId);
      print('   📊 Current Attendance Status: $currentStatus');
      print('   🔄 Checkout Mode: $_isCheckoutEnabled');
      
      // Check if checkout is enabled and validate student status
      if (_isCheckoutEnabled) {
        print('   🔄 Processing as CHECKOUT');
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
          _recentlyScannedTags.add(tagData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.info, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Student already checked out'),
                  ],
                ),
                backgroundColor: Colors.blue[700],
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      } else {
        // Check-in mode
        print('   🔄 Processing as CHECK-IN');
        if (currentStatus == 'checked_in') {
          print('   ⚠️  Student already checked in');
          _recentlyScannedTags.add(tagData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.info, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Student already checked in'),
                  ],
                ),
                backgroundColor: Colors.blue[700],
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      // Create QR code data for attendance
      String qrCodeDataToSend;
      if (_isOfflineMode) {
        final offlinePayload = jsonEncode({
          'studentId': studentId,
        });
        qrCodeDataToSend = base64Encode(utf8.encode(offlinePayload));
        print('   📤 Offline Mode - QR Data: $qrCodeDataToSend');
      } else {
        qrCodeDataToSend = tagData;
        print('   📤 Online Mode - QR Data: $qrCodeDataToSend');
      }

      print('   📤 Sending attendance request...');
      print('      Event ID: $eventId');
      print('      Student ID: $studentId');
      print('      QR Data: $qrCodeDataToSend');
      
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
        
        print('   ✅ ATTENDANCE SUCCESS!');
        print('      Action: $action');
        print('      Student Name: $studentName');
        print('═══════════════════════════════════════');
        
        setState(() {
          _lastAction = action;
          _lastStudentName = studentName;
        });

        _showSuccessMessage(studentName, action);
      } else {
        print('   ❌ ATTENDANCE FAILED');
        final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
        final errorMessage = attendanceProvider.error ?? 'Failed to mark attendance. Please try again.';
        
        print('      Error: $errorMessage');
        print('═══════════════════════════════════════');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      print('   ❌ EXCEPTION OCCURRED: $e');
      print('═══════════════════════════════════════');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid RFID tag data: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RFID Scanner'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isWriteMode ? Icons.edit : Icons.edit_outlined),
            onPressed: () {
              setState(() {
                _isWriteMode = !_isWriteMode;
                if (_isScanning) {
                  NfcManager.instance.stopSession();
                  _isScanning = false;
                }
              });
              if (_isWriteMode) {
                _showWriteDataDialog();
              }
            },
            tooltip: _isWriteMode ? 'Switch to Read Mode' : 'Switch to Write Mode',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
              
              if (_isOfflineMode && _selectedEvent != null) {
                await attendanceProvider.refreshAttendanceForEvent(_selectedEvent!.id);
              } else {
                await attendanceProvider.loadAttendances();
              }
              
              setState(() {
                _recentlyScannedTags.clear();
              });
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isOfflineMode 
                      ? 'Event attendance data refreshed'
                      : 'All attendance data refreshed'
                    ),
                    backgroundColor: AppTheme.successColor,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            tooltip: 'Refresh Attendance Data',
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
                      _recentlyScannedTags.clear();
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
                      Icons.credit_card,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'RFID/NFC Scanner',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isWriteMode
                          ? 'Write mode: Write data to RFID tags'
                          : (_isCheckoutEnabled 
                              ? 'Checkout mode: Students can check out'
                              : 'Check-in mode: Students can check in'),
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
                            _isScanning ? Icons.nfc : Icons.nfc_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isScanning ? 'Scanning Active' : 'Ready to Scan',
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // NFC Icon
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: _isScanning 
                              ? AppTheme.primaryColor.withOpacity(0.1)
                              : Colors.grey[200],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isScanning 
                                ? AppTheme.primaryColor
                                : Colors.grey[400]!,
                            width: 4,
                          ),
                        ),
                        child: Icon(
                          Icons.credit_card,
                          size: 100,
                          color: _isScanning 
                              ? AppTheme.primaryColor
                              : Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Status Message
                      Text(
                        _statusMessage,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _isScanning 
                              ? AppTheme.primaryColor
                              : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      
                      // Start/Stop Button
                      ElevatedButton.icon(
                        onPressed: _nfcAvailable 
                            ? (_isWriteMode ? _startNFCWrite : _startNFCScan)
                            : null,
                        icon: Icon(_isScanning 
                            ? Icons.stop 
                            : (_isWriteMode ? Icons.edit : Icons.play_arrow)),
                        label: Text(_isScanning 
                            ? 'Stop' 
                            : (_isWriteMode ? 'Start Writing' : 'Start Scanning')),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          backgroundColor: _isScanning 
                              ? AppTheme.errorColor
                              : (_isWriteMode ? AppTheme.secondaryColor : AppTheme.primaryColor),
                        ),
                      ),
                      if (_isWriteMode) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Enter data in the dialog, then tap "Start Writing" and hold device near tag',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 32),
                      
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
                                'Tag Data: ${_lastScannedData!.length > 30 ? _lastScannedData!.substring(0, 30) + '...' : _lastScannedData!}',
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
          
          // Duplicate tag warning overlay
          if (_showingDuplicateMessage)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.all(24),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.repeat,
                        color: Colors.orange[700],
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Same Tag Detected',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Waiting for different tag',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showingDuplicateMessage = false;
                          });
                        },
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Success popup overlay
          if (_showingSuccessMessage && _isScanCooldown)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.all(24),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _successAction == 'check_in' ? Icons.login : Icons.logout,
                        color: _successAction == 'check_in' 
                            ? AppTheme.successColor
                            : AppTheme.primaryColor,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _successAction == 'check_in' ? 'CHECKED IN' : 'CHECKED OUT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: _successAction == 'check_in' 
                              ? AppTheme.successColor
                              : AppTheme.primaryColor,
                        ),
                      ),
                      if (_successStudentName != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _successStudentName!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Cooldown: $_cooldownSeconds seconds',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
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
}

