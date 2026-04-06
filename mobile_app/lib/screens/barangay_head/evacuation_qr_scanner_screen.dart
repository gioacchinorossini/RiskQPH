import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

/// Same payload as resident offline QR: base64(jsonEncode({ 'studentId': user.id })).
String? decodeResidentUserIdFromQrRaw(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64Decode(trimmed));
    final payload = jsonDecode(decoded);
    if (payload is Map && payload['studentId'] != null) {
      final id = payload['studentId'].toString().trim();
      if (id.isNotEmpty) return id;
    }
  } catch (_) {}
  return null;
}

/// Barangay head: pick evacuation center first (like offline event in qrattendanceexample),
/// then continuous QR scan to register residents at that center.
class EvacuationQrScannerScreen extends StatefulWidget {
  const EvacuationQrScannerScreen({super.key});

  @override
  State<EvacuationQrScannerScreen> createState() =>
      _EvacuationQrScannerScreenState();
}

class _EvacuationQrScannerScreenState extends State<EvacuationQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    /// Must be false: we only [start] after [MobileScanner] is mounted (see
    /// [_showCenterPickerDialog]). Starting while the preview is not in the
    /// tree yields a blank/black camera on many devices.
    autoStart: false,
    facing: CameraFacing.back,
    torchEnabled: false,
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;
  final Set<String> _recentlyScanned = {};
  Timer? _cleanupTimer;
  Timer? _cooldownTimer;

  bool _showingDuplicateMessage = false;
  bool _showingSuccessMessage = false;
  String? _successResidentName;
  bool _isScanCooldown = false;
  int _cooldownDefaultSeconds = 2;
  int _cooldownSeconds = 2;

  List<dynamic> _centers = [];
  bool _loadingCenters = true;
  Map<String, dynamic>? _selectedCenter;

  String? _lastScannedRaw;
  String? _lastRegisteredName;

  static const Color _headRed = Color(0xFF8E0000);

  @override
  void initState() {
    super.initState();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() => _recentlyScanned.clear());
    });
    _loadCenters();
  }

  Future<void> _loadCenters() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user?.barangay == null) {
      setState(() => _loadingCenters = false);
      return;
    }
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/evacuation-center?barangay=${Uri.encodeQueryComponent(user!.barangay!)}',
        ),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _centers = data['centers'] as List<dynamic>? ?? [];
          _loadingCenters = false;
        });
        if (mounted && _centers.isNotEmpty && _selectedCenter == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showCenterPickerDialog(isInitial: true);
          });
        }
      } else {
        setState(() => _loadingCenters = false);
      }
    } catch (_) {
      setState(() => _loadingCenters = false);
    }
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _cooldownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showDuplicateMessage() {
    if (_isScanCooldown) return;
    if (_showingDuplicateMessage) return;
    setState(() => _showingDuplicateMessage = true);
  }

  void _showSuccessMessage(String residentName) {
    setState(() {
      _showingSuccessMessage = true;
      _successResidentName = residentName;
    });
    _startScanCooldown();
  }

  void _startScanCooldown() {
    _cooldownTimer?.cancel();
    setState(() {
      _isScanCooldown = true;
      _cooldownSeconds = _cooldownDefaultSeconds;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldownSeconds--);
      if (_cooldownSeconds <= 0) {
        t.cancel();
        setState(() {
          _isScanCooldown = false;
          _cooldownSeconds = _cooldownDefaultSeconds;
          _showingSuccessMessage = false;
          _successResidentName = null;
        });
      }
    });
  }

  /// Starts the camera after [MobileScanner] is in the tree.
  Future<void> _ensureScannerStarted() async {
    if (!mounted) return;
    try {
      await _controller.start();
    } catch (e) {
      debugPrint('EvacuationQrScanner: start failed: $e');
    }
  }

  Future<void> _showCenterPickerDialog({bool isInitial = false}) async {
    // Only stop if the preview was actually showing (avoids odd controller state on first open).
    if (_selectedCenter != null) {
      await _controller.stop();
    }
    if (!mounted) return;

    if (_centers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No evacuation centers — add them under Evacuation'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: !isInitial,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.maps_home_work, color: _headRed),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isInitial
                    ? 'Select evacuation center'
                    : 'Change evacuation center',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isInitial
                    ? 'Choose where scanned residents will be registered. You can change this anytime.'
                    : 'All new scans will go to the center you pick.',
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _centers.length,
                  itemBuilder: (context, index) {
                    final c = _centers[index] as Map<String, dynamic>;
                    final id = c['id'] as String;
                    final name = c['name']?.toString() ?? id;
                    final count = c['_count']?['evacuees'] ?? 0;
                    final cap = c['capacity'];
                    return ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(name),
                      subtitle: Text(
                        'Occupancy: $count / ${cap ?? '—'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () => Navigator.pop(ctx, c),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (!isInitial)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          if (isInitial)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later'),
            ),
        ],
      ),
    );

    if (!mounted) return;

    if (picked != null) {
      setState(() {
        _selectedCenter = picked;
        _recentlyScanned.clear();
        _showingDuplicateMessage = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _ensureScannerStarted();
      });
    } else if (_selectedCenter != null) {
      // Cancel / Later while a center was already chosen — resume preview.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _ensureScannerStarted();
      });
    }
  }

  Future<void> _handleRaw(String raw) async {
    if (_selectedCenter == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select an evacuation center first'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
      return;
    }

    final userId = decodeResidentUserIdFromQrRaw(raw);
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not a valid resident QR code'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    if (_recentlyScanned.contains(raw)) {
      if (!_showingDuplicateMessage) _showDuplicateMessage();
      return;
    }

    if (_showingDuplicateMessage) {
      setState(() => _showingDuplicateMessage = false);
    }

    if (!mounted) return;
    final headUser = context.read<AuthProvider>().currentUser;
    if (headUser == null) return;

    setState(() {
      _recentlyScanned.add(raw);
      _lastScannedRaw = raw;
    });

    bool registeredOk = false;
    int? registerStatusCode;

    try {
      final profileRes = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/profile?id=${Uri.encodeQueryComponent(userId)}',
        ),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (profileRes.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not load profile for this QR'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      final data = jsonDecode(profileRes.body) as Map<String, dynamic>;
      final u = data['user'] as Map<String, dynamic>;
      final role = (u['role'] ?? '').toString();
      if (role != 'resident') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Use a resident’s personal QR from their app'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      final headBg = (headUser.barangay ?? '').trim();
      final resBg = (u['barangay'] ?? '').toString().trim();
      if (headBg.isEmpty || resBg.isEmpty || headBg != resBg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                resBg.isEmpty
                    ? 'Resident has no barangay on file'
                    : 'Resident is not in your barangay ($resBg)',
              ),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      final firstName = (u['firstName'] ?? '').toString();
      final lastName = (u['lastName'] ?? '').toString();
      final displayName = '$firstName $lastName'.trim();
      final centerId = _selectedCenter!['id'] as String;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/evacuation-center/register'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'evacuationCenterId': centerId,
          'firstName': firstName.isEmpty ? 'Resident' : firstName,
          'lastName': lastName.isEmpty ? 'Unknown' : lastName,
          'middleName': u['middleName'],
          'gender': u['gender'],
          'medicalNotes': 'Registered via QR scan',
          'addedById': headUser.id,
          'registeredUserId': userId,
        }),
      );

      registerStatusCode = response.statusCode;

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        registeredOk = true;
        setState(() {
          _lastRegisteredName =
              displayName.isEmpty ? 'Resident' : displayName;
        });
        _showSuccessMessage(
          displayName.isEmpty ? 'Resident' : displayName,
        );
      } else if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Already registered at this center'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        _startScanCooldown();
      } else {
        String msg = 'Registration failed';
        try {
          final err = jsonDecode(response.body) as Map<String, dynamic>;
          if (err['message'] is String) msg = err['message'] as String;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted &&
          !registeredOk &&
          registerStatusCode != 409) {
        setState(() => _recentlyScanned.remove(raw));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evacuation QR scan'),
        backgroundColor: _headRed,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Clear scan memory',
            onPressed: () {
              setState(() {
                _recentlyScanned.clear();
                _showingDuplicateMessage = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Scan memory cleared — same QR can be read again'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.maps_home_work_outlined),
            tooltip: 'Select center',
            onPressed: () => _showCenterPickerDialog(isInitial: false),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_headRed, Color(0xFFB71C1C)],
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_scanner,
                        size: 44, color: Colors.white),
                    const SizedBox(height: 10),
                    Text(
                      'Continuous evacuation check-in',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_loadingCenters)
                      const Text(
                        'Loading centers…',
                        style: TextStyle(color: Colors.white70),
                      )
                    else if (_centers.isEmpty)
                      const Text(
                        'No evacuation centers — add them under Evacuation',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      )
                    else if (_selectedCenter == null)
                      const Text(
                        'Select an evacuation center to start scanning',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.place,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _selectedCenter!['name']?.toString() ??
                                    'Center',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.sync,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Continuous scanning active',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_selectedCenter != null &&
                                  !_loadingCenters &&
                                  _centers.isNotEmpty)
                                MobileScanner(
                                  key: ValueKey(
                                    _selectedCenter!['id']?.toString() ?? 'scan',
                                  ),
                                  controller: _controller,
                                  onDetect: (capture) async {
                                    if (_isProcessing || _isScanCooldown) {
                                      return;
                                    }
                                    final barcodes = capture.barcodes;
                                    if (barcodes.isEmpty) return;
                                    final raw = barcodes.first.rawValue;
                                    if (raw == null || raw.isEmpty) return;

                                    setState(() => _isProcessing = true);
                                    await _handleRaw(raw);
                                    if (mounted) {
                                      setState(() => _isProcessing = false);
                                    }
                                  },
                                )
                              else
                                Container(
                                  color: Colors.grey.shade300,
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.maps_home_work_outlined,
                                              size: 56,
                                              color: Colors.grey.shade600),
                                          const SizedBox(height: 16),
                                          Text(
                                            _loadingCenters
                                                ? 'Loading…'
                                                : _centers.isEmpty
                                                    ? 'Create centers first'
                                                    : 'Choose a center to open the camera',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (!_loadingCenters &&
                                              _centers.isNotEmpty &&
                                              _selectedCenter == null) ...[
                                            const SizedBox(height: 20),
                                            FilledButton.icon(
                                              onPressed: () =>
                                                  _showCenterPickerDialog(
                                                      isInitial: false),
                                              icon: const Icon(
                                                  Icons.location_on),
                                              label: const Text(
                                                  'Select evacuation center'),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              if (_isProcessing &&
                                  _selectedCenter != null)
                                Container(
                                  color: Colors.black26,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white),
                                  ),
                                ),
                              if (_selectedCenter != null &&
                                  _centers.isNotEmpty)
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
                      if (_selectedCenter != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _controller.toggleTorch(),
                                icon: const Icon(Icons.flash_on),
                                label: const Text('Torch'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _controller.switchCamera(),
                                icon: const Icon(Icons.cameraswitch),
                                label: const Text('Flip'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_lastScannedRaw != null &&
                            _lastRegisteredName != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withValues(
                                  alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppTheme.successColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        color: AppTheme.successColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      'LAST REGISTERED',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.successColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _lastRegisteredName!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
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
          if (_showingDuplicateMessage)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.repeat,
                            color: Colors.orange.shade800, size: 40),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Same QR code',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Waiting for a different resident',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      _ThreeDotsLoading(color: Colors.orange.shade700),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            setState(() => _showingDuplicateMessage = false);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                          ),
                          child: const Text('Dismiss'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_showingSuccessMessage && _isScanCooldown)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.how_to_reg,
                            color: AppTheme.successColor, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'REGISTERED',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successColor,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_successResidentName != null)
                        Text(
                          _successResidentName!,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Added at this evacuation center',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.timer,
                                    color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Scan cooldown',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_cooldownSeconds seconds remaining',
                              style: TextStyle(
                                color: Colors.blue.shade600,
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
  State<_CooldownFloatingControl> createState() =>
      _CooldownFloatingControlState();
}

class _CooldownFloatingControlState extends State<_CooldownFloatingControl> {
  Offset _offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Draggable(
      feedback: _buildControl(isFeedback: true),
      childWhenDragging: const SizedBox.shrink(),
      onDragEnd: (details) {
        setState(() => _offset = details.offset);
      },
      child: Transform.translate(
        offset: _offset,
        child: _buildControl(),
      ),
    );
  }

  Widget _buildControl({bool isFeedback = false}) {
    final control = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            '${widget.seconds}s',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          _RoundIconButton(icon: Icons.remove, onTap: widget.onDecrease),
          const SizedBox(width: 6),
          _RoundIconButton(icon: Icons.add, onTap: widget.onIncrease),
        ],
      ),
    );
    return isFeedback ? Material(color: Colors.transparent, child: control) : control;
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
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(0.0),
          const SizedBox(width: 6),
          _dot(0.2),
          const SizedBox(width: 6),
          _dot(0.4),
        ],
      ),
    );
  }

  Widget _dot(double start) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = (_c.value + start) % 1.0;
        final opacity = 0.3 + 0.7 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
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
