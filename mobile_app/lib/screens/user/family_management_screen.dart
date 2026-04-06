import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/auth_provider.dart';
import '../../config/api_config.dart';
import '../../models/family_member.dart';
import '../../widgets/view_on_map_button.dart';
import '../../widgets/member_status_icon.dart';

class FamilyManagementScreen extends StatefulWidget {
  const FamilyManagementScreen({super.key});

  @override
  State<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends State<FamilyManagementScreen> {
  List<FamilyMember> _members = [];
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _activeDisaster;
  List<Map<String, dynamic>> _filteredResidents = [];

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      if (user.barangay != null) {
        final dResp = await http.get(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/disaster?barangay=${user.barangay}',
          ),
          headers: {'ngrok-skip-browser-warning': 'true'},
        );
        if (dResp.statusCode == 200) {
          final dData = jsonDecode(dResp.body);
          if (mounted) setState(() => _activeDisaster = dData['disaster']);
        }
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/family?headId=${user.id}'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      // Fetch residents to match status (just like HazardMapScreen)
      List<dynamic> allResidents = [];
      if (user.barangay != null) {
        final resResp = await http.get(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/barangay/residents?barangay=${user.barangay}${_activeDisaster != null ? '&disasterId=${_activeDisaster!['id']}' : ''}',
          ),
          headers: {'ngrok-skip-browser-warning': 'true'},
        );
        if (resResp.statusCode == 200) {
          final resData = jsonDecode(resResp.body);
          allResidents = resData['residents'] ?? [];
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> membersJson = data['members'] as List;
        if (mounted) {
          setState(() {
            final fetchedMembers = membersJson
                .map((m) => FamilyMember.fromJson(m))
                .toList();
            _filteredResidents = allResidents
                .map((r) => Map<String, dynamic>.from(r))
                .toList();

            // Self-referential member for the head of family
            final residentMe = _filteredResidents
                .where((r) => r['id'].toString() == user.id.toString())
                .firstOrNull;

            final me = FamilyMember(
              id: 'self_${user.id}',
              userId: user.id,
              headId: user.id,
              firstName: user.firstName ?? 'You',
              lastName: user.lastName ?? '',
              relationship: 'Self',
              createdAt: user.createdAt,
              updatedAt: user.updatedAt,
              latitude: (residentMe?['latitude'] as num?)?.toDouble(),
              longitude: (residentMe?['longitude'] as num?)?.toDouble(),
              isSafe: residentMe?['isSafe'] == true,
            );

            _members = [me, ...fetchedMembers];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load family members';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showAddMemberSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddMemberBottomSheet(),
    ).then((value) {
      if (value == true) _fetchMembers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F4),
      appBar: AppBar(
        title: const Text(
          'Family',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 1.5,
            color: Color(0xFF004D40),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF006064),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.sync_rounded),
              onPressed: _fetchMembers,
              tooltip: 'Sync Family',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF006064),
                strokeWidth: 3,
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchMembers,
              color: const Color(0xFF006064),
              child: _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ],
                      ),
                    )
                  : _members.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderSection(),
                          const SizedBox(height: 24),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  mainAxisExtent: 220,
                                ),
                            itemCount: _members.length,
                            itemBuilder: (context, index) {
                              return _buildMemberCard(_members[index]);
                            },
                          ),
                          const SizedBox(height: 80), // Space for FAB
                        ],
                      ),
                    ),
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(30)),
        child: FloatingActionButton.extended(
          onPressed: _showAddMemberSheet,
          icon: const Icon(Icons.person_add_rounded, color: Colors.white),
          label: const Text(
            'Add Members',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF006064),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF006064)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keep your family safe',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Linked members will appear on your map during emergencies.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatsChip(
                Icons.people_outline,
                '${_members.length} Members',
              ),
              const SizedBox(width: 12),
              _buildStatsChip(
                Icons.location_on_outlined,
                '${_members.where((m) => m.latitude != null).length} Tracked',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.family_restroom_rounded,
                size: 80,
                color: const Color(0xFF006064).withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'YOUR CIRCLE IS EMPTY',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF004D40),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Protect your loved ones by linking their accounts or adding them manually for visual tracking during disasters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showAddMemberSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('ADD FIRST MEMBER'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006064),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(FamilyMember member) {
    // SYNC: Lookup resident record for SOS status
    final resident = _filteredResidents
        .where((r) => r['id'].toString() == member.userId?.toString())
        .firstOrNull;
    final bool isSafe = resident != null
        ? (resident['isSafe'] == true)
        : (member.isSafe ?? false);
    final bool hasSOS = resident != null
        ? (resident['hasResponded'] == true)
        : false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showMemberOptions(member),
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            alignment: Alignment.center,
            children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                MemberStatusBubble(
                  isSafe: isSafe,
                  hasSOS: hasSOS,
                  isEmergencyActive: _activeDisaster != null,
                  isOnline: member.latitude != null,
                  fallbackColor: Colors.grey,
                ),
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    MemberMarker(
                      relationship: member.relationship,
                      isSafe: isSafe,
                      hasSOS: hasSOS,
                      isEmergencyActive: _activeDisaster != null,
                      isOnline: member.latitude != null,
                      size: 24,
                      activeColor: const Color(0xFF006064),
                    ),
                    if (member.relationship == 'Self' ||
                        member.userId != null)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: member.latitude != null
                                ? Colors.green
                                : Colors.grey[400],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${member.firstName} ${member.lastName}'.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.2,
                    color: Color(0xFF263238),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  member.relationship.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                if (member.latitude != null && member.longitude != null)
                  ViewOnMapButton(
                    locationData: {
                      'id': member.userId,
                      'latitude': member.latitude,
                      'longitude': member.longitude,
                    },
                    label: "TRACK",
                    isPrimary: true,
                  ),
              ],
            ),
          ),
          if (member.relationship != 'Self')
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: Colors.grey[400],
                  size: 20,
                ),
                onPressed: () => _showMemberOptions(member),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showMemberOptions(FamilyMember member) {
    final resident = _filteredResidents
        .where((r) => r['id'].toString() == member.userId?.toString())
        .firstOrNull;

    final String name = '${member.firstName} ${member.lastName}'.trim();
    final String rel = member.relationship.toUpperCase();
    final String? ecName = resident?['evacuationCenterName']?.toString();
    final bool registered = ecName != null && ecName.isNotEmpty;

    String lastUp = 'Unknown';
    if (resident != null && resident['updatedAt'] != null) {
      try {
        final dt = DateTime.parse(resident['updatedAt']);
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 60) {
          lastUp = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          lastUp = '${diff.inHours}h ago';
        } else {
          lastUp = '${diff.inDays}d ago';
        }
      } catch (_) {}
    }

    final String coords =
        member.latitude != null && member.longitude != null
            ? '${member.latitude!.toStringAsFixed(6)}, ${member.longitude!.toStringAsFixed(6)}'
            : 'Not available';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    MemberMarker(
                      relationship: member.relationship,
                      isSafe: resident?['isSafe'] == true,
                      hasSOS: resident?['hasResponded'] == true,
                      isEmergencyActive: _activeDisaster != null,
                      isOnline: member.latitude != null,
                      size: 24,
                      activeColor: const Color(0xFF006064),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            rel,
                            style: TextStyle(
                              color: Colors.grey[600],
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
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  registered ? Icons.shield : Icons.shield_outlined,
                  color: registered ? Colors.teal : Colors.grey,
                ),
                title: Text(
                  registered
                      ? 'Registered at evacuation center'
                      : 'Evacuation center',
                ),
                subtitle: Text(
                  registered
                      ? ecName
                      : 'Not currently registered at an evacuation center.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Last updated'),
                subtitle: Text(lastUp),
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Coordinates'),
                subtitle: SelectableText(coords),
              ),
              if (member.medicalNotes != null && member.medicalNotes!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.medical_services_outlined),
                  title: const Text('Medical Notes'),
                  subtitle: Text(member.medicalNotes!),
                ),
              if (member.relationship != 'Self') ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remove from Family Circle',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(member);
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _confirmDelete(FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('REMOVE FAMILY?'),
        content: Text(
          'Do you want to disconnect ${member.firstName}? Their location will no longer be visible on your map.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'REMOVE MEMBER',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await http.delete(
          Uri.parse('${ApiConfig.baseUrl}/api/family?id=${member.id}'),
          headers: {'ngrok-skip-browser-warning': 'true'},
        );
        if (response.statusCode == 200) {
          _fetchMembers();
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _AddMemberBottomSheet extends StatefulWidget {
  const _AddMemberBottomSheet();

  @override
  State<_AddMemberBottomSheet> createState() => _AddMemberBottomSheetState();
}

class _AddMemberBottomSheetState extends State<_AddMemberBottomSheet> {
  int _currentStep = 0; // 0: Selection, 1: Manual, 2: Linked, 3: QR
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _medicalNotesController = TextEditingController();
  String? _gender = 'Male';

  final _searchController = TextEditingController();
  Map<String, dynamic>? _foundUser;

  Future<void> _searchUser(String userIdOrEmail) async {
    if (mounted)
      setState(() {
        _isLoading = true;
        _foundUser = null;
      });
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/search_user?id=$userIdOrEmail'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _foundUser = data['user'];
            _isLoading = false;
            _currentStep = 2; // Jump to Linked view
          });
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not found')));
        if (mounted)
          setState(() {
            _isLoading = false;
          });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  Future<void> _submitLinked() async {
    if (_foundUser == null) return;
    if (mounted)
      setState(() {
        _isLoading = true;
      });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    try {
      final body = {
        'headId': user.id,
        'firstName': _foundUser!['firstName'],
        'lastName': _foundUser!['lastName'],
        'relationship': _relationshipController.text.isEmpty
            ? 'Family Member'
            : _relationshipController.text,
        'gender': _foundUser!['gender'],
        'userId': _foundUser!['id'],
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/family'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) Navigator.pop(context, true);
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to link')),
        );
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error linking member')));
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitManual() async {
    if (!_formKey.currentState!.validate()) return;
    if (mounted)
      setState(() {
        _isLoading = true;
      });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    try {
      final body = {
        'headId': user.id,
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'relationship': _relationshipController.text,
        'gender': _gender,
        'medicalNotes': _medicalNotesController.text,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/family'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (_currentStep == 0) _buildSelectionButtons(),
                  if (_currentStep == 1) _buildManualForm(),
                  if (_currentStep == 2) _buildLinkedForm(),
                  if (_currentStep == 3) _buildQRScanner(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionButtons() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LINK FAMILY MEMBER',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sync accounts instantly to coordinate safety during disasters.',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          _buildSelectOption(
            Icons.qr_code_scanner,
            'SCAN PROFILE QR',
            'Instantly link via user QR code',
            () => setState(() => _currentStep = 3),
          ),
          _buildSelectOption(
            Icons.person_search,
            'SEARCH USER ID',
            'Link via System ID or Email',
            () => setState(() => _currentStep = 2),
          ),
          _buildSelectOption(
            Icons.edit_note,
            'MANUAL ENTRY',
            'Add member without an account',
            () => setState(() => _currentStep = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFFF8F9FA),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF006064).withOpacity(0.1),
              child: Icon(icon, color: const Color(0xFF006064)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildManualForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _currentStep = 0),
                ),
                const Text(
                  'DIRECT ADDITION',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildTextField(_firstNameController, 'FIRST NAME'),
            const SizedBox(height: 16),
            _buildTextField(_lastNameController, 'LAST NAME'),
            const SizedBox(height: 16),
            _buildTextField(_relationshipController, 'RELATIONSHIP'),
            const SizedBox(height: 16),
            _buildTextField(
              _medicalNotesController,
              'MEDICAL NOTES (OPTIONAL)',
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitManual,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006064),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'ADD MEMBER',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _currentStep = 0),
              ),
              const Text(
                'SYSTEM SEARCH',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'USER ID OR EMAIL',
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => _searchUser(_searchController.text),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (_foundUser != null) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF006064).withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF006064).withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF006064).withOpacity(0.1),
                    child: const Icon(Icons.person, color: Color(0xFF006064)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_foundUser!['firstName']} ${_foundUser!['lastName']}'
                              .toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'JURISDICTION: ${_foundUser!['barangay']?.toUpperCase() ?? 'N/A'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _relationshipController,
              decoration: InputDecoration(
                labelText: 'RELATIONSHIP (E.G. SPOUSE)',
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitLinked,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006064),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'LINK INSTANTLY',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQRScanner() {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _currentStep = 0),
            ),
            const Text(
              'QR PROFILE SCAN',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        Container(
          height: 300,
          margin: const EdgeInsets.all(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final rawValue = barcode.rawValue;
                  if (rawValue != null) {
                    try {
                      final data = jsonDecode(
                        utf8.decode(base64Decode(rawValue)),
                      );
                      if (data['studentId'] != null) {
                        _searchUser(data['studentId']);
                      }
                    } catch (e) {
                      debugPrint('Invalid QR: $e');
                    }
                  }
                }
              },
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Scan the QR code from their mobile profile to link. System synchronization is instant.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }
}
