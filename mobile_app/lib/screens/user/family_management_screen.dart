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
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF006064),
                  strokeWidth: 3,
                ),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: Colors.red[700])),
                  ],
                ),
              ),
            )
          else if (_members.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 220,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildMemberCard(_members[index]),
                  childCount: _members.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(30)),
        child: FloatingActionButton.extended(
          onPressed: _showAddMemberSheet,
          icon: const Icon(Icons.person_add_rounded, color: Colors.white),
          label: const Text(
            'ADD MEMBERS',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF006064),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: const BorderSide(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF004D40),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _fetchMembers,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF004D40), Color(0xFF006064)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  Icons.family_restroom_rounded,
                  size: 200,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FAMILY CIRCLE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'KEEP YOUR LOVED ONES SAFE',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
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
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
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

      if (response.statusCode == 201) {
        if (mounted) Navigator.pop(context, true);
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
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
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
              padding: const EdgeInsets.all(32),
              child: _buildCurrentStepView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildSelectionView();
      case 1:
        return _buildManualView();
      case 2:
        return _buildLinkedView();
      case 3:
        return _buildQRView();
      default:
        return _buildSelectionView();
    }
  }

  Widget _buildSelectionView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add Family Member',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose how you want to add a member to your family circle.',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 32),
        _buildSelectionCard(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Scan QR Code',
          subtitle: "Instantly link a family member's existing account.",
          color: Colors.purple,
          onTap: () => setState(() => _currentStep = 3),
        ),
        const SizedBox(height: 16),
        _buildSelectionCard(
          icon: Icons.link_rounded,
          title: 'Search & Link Account',
          subtitle: 'Search for their account using ID or Email.',
          color: Colors.blue,
          onTap: () => _showSearchDialog(),
        ),
        const SizedBox(height: 16),
        _buildSelectionCard(
          icon: Icons.edit_note_rounded,
          title: 'Manual Entry',
          subtitle: 'Add a member who doesn\'t have an account yet.',
          color: Colors.teal,
          onTap: () => setState(() => _currentStep = 1),
        ),
      ],
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('SEARCH USER'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Enter User ID or Email',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = _searchController.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(context);
                _searchUser(val);
              }
            },
            child: const Text('SEARCH'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildManualView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _currentStep = 0),
                icon: const Icon(Icons.arrow_back),
              ),
              const Text(
                'Manual Entry',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(labelText: 'First Name'),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(labelText: 'Last Name'),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _relationshipController,
            decoration: const InputDecoration(
              labelText: 'Relationship (e.g. Son, Daughter, Spouse)',
            ),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: ['Male', 'Female', 'Other']
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _medicalNotesController,
            decoration: const InputDecoration(
              labelText: 'Medical Notes (Optional)',
              hintText: 'e.g. Allergies, disabilities, or blood type',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitManual,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006064),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('ADD MEMBER'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedView() {
    if (_foundUser == null) return const Text('No user found');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _currentStep = 0),
              icon: const Icon(Icons.arrow_back),
            ),
            const Text(
              'Link Account',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.blue.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                '${_foundUser!['firstName']} ${_foundUser!['lastName']}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'ID: ${_foundUser!['id']}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'CONFIRM RELATIONSHIP',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _relationshipController,
          decoration: const InputDecoration(
            hintText: 'e.g. Brother, Sister, Mother',
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitLinked,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('LINK TO FAMILY'),
          ),
        ),
      ],
    );
  }

  Widget _buildQRView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _currentStep = 0),
              icon: const Icon(Icons.arrow_back),
            ),
            const Text(
              'Scan QR Code',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 32),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 1,
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String? code = barcodes.first.rawValue;
                  if (code != null) {
                    _searchUser(code);
                  }
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: Text(
            'Keep your family member\'s professional QR code inside the frame to link.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}
