import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/auth_provider.dart';
import '../../config/api_config.dart';
import '../../models/family_member.dart';
import '../../widgets/view_on_map_button.dart';

class FamilyManagementScreen extends StatefulWidget {
  const FamilyManagementScreen({super.key});

  @override
  State<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends State<FamilyManagementScreen> {
  List<FamilyMember> _members = [];
  bool _isLoading = true;
  String? _error;

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
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/family?headId=${user.id}'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> membersJson = data['members'] as List;
        if (mounted) {
          setState(() {
            _members = membersJson.map((m) => FamilyMember.fromJson(m)).toList();
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
      appBar: AppBar(
        title: const Text('FAMILY DIRECTORY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF006064),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMembers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF006064)))
          : RefreshIndicator(
              onRefresh: _fetchMembers,
              child: _error != null
                  ? Center(child: Text(_error!))
                  : _members.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _members.length,
                          itemBuilder: (context, index) {
                            return _buildMemberCard(_members[index]);
                          },
                        ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberSheet,
        icon: const Icon(Icons.add),
        label: const Text('ADD FAMILY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        backgroundColor: const Color(0xFF006064),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.family_restroom, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'NO FAMILY CONNECTED',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.grey[400], letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            'Link family accounts for instant synchronization.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(FamilyMember member) {
    final bool hasLocation = member.latitude != null && member.longitude != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF006064).withOpacity(0.1),
              child: Icon(_getMemberIcon(member), color: const Color(0xFF006064)),
            ),
            title: Text(
              member.fullName.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: -0.2),
            ),
            subtitle: Text(member.relationship.toUpperCase(), style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              onPressed: () => _confirmDelete(member),
            ),
          ),
          if (hasLocation)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   ViewOnMapButton(
                     locationData: {
                       'id': member.userId,
                       'latitude': member.latitude,
                       'longitude': member.longitude,
                     },
                     label: "VIEW LOCATION",
                     isPrimary: false,
                   ),
                ],
              ),
            )
          else if (member.userId != null)
             const Padding(
               padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
               child: Text('OFFLINE / LOCATION NOT SHARED', 
                style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
             ),
        ],
      ),
    );
  }

  IconData _getMemberIcon(FamilyMember member) {
    final rel = member.relationship.toLowerCase();
    if (rel.contains('spouse')) return Icons.favorite;
    if (rel.contains('child') || rel.contains('son') || rel.contains('daughter')) return Icons.child_care;
    return Icons.person;
  }

  Future<void> _confirmDelete(FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('REMOVE FAMILY?'),
        content: Text('Do you want to disconnect ${member.firstName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('REMOVE', style: TextStyle(color: Colors.red))),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    if (mounted) setState(() { _isLoading = true; _foundUser = null; });
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found')));
        if (mounted) setState(() { _isLoading = false; });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _submitLinked() async {
    if (_foundUser == null) return;
    if (mounted) setState(() { _isLoading = true; });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    try {
      final body = {
        'headId': user.id,
        'firstName': _foundUser!['firstName'],
        'lastName': _foundUser!['lastName'],
        'relationship': _relationshipController.text.isEmpty ? 'Family Member' : _relationshipController.text,
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed to link')));
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error linking member')));
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitManual() async {
    if (!_formKey.currentState!.validate()) return;
    if (mounted) setState(() { _isLoading = true; });
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
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
          const Text('LINK FAMILY MEMBER', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text('Sync accounts instantly to coordinate safety during disasters.', 
            style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 32),
          _buildSelectOption(Icons.qr_code_scanner, 'SCAN PROFILE QR', 'Instantly link via user QR code', 
            () => setState(() => _currentStep = 3)),
          _buildSelectOption(Icons.person_search, 'SEARCH USER ID', 'Link via System ID or Email', 
            () => setState(() => _currentStep = 2)),
          _buildSelectOption(Icons.edit_note, 'MANUAL ENTRY', 'Add member without an account', 
            () => setState(() => _currentStep = 1)),
        ],
      ),
    );
  }

  Widget _buildSelectOption(IconData icon, String title, String subtitle, VoidCallback onTap) {
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
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.2)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold)),
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
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _currentStep = 0)),
              const Text('DIRECT ADDITION', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1))
            ]),
            const SizedBox(height: 24),
            _buildTextField(_firstNameController, 'FIRST NAME'),
            const SizedBox(height: 16),
            _buildTextField(_lastNameController, 'LAST NAME'),
            const SizedBox(height: 16),
            _buildTextField(_relationshipController, 'RELATIONSHIP'),
            const SizedBox(height: 16),
            _buildTextField(_medicalNotesController, 'MEDICAL NOTES (OPTIONAL)'),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitManual,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006064), 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('ADD MEMBER', style: TextStyle(fontWeight: FontWeight.bold)),
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
          Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _currentStep = 0)),
            const Text('SYSTEM SEARCH', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1))
          ]),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          if (_foundUser != null) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF006064).withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF006064).withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: const Color(0xFF006064).withOpacity(0.1), child: const Icon(Icons.person, color: Color(0xFF006064))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_foundUser!['firstName']} ${_foundUser!['lastName']}'.toUpperCase(), 
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        Text('JURISDICTION: ${_foundUser!['barangay']?.toUpperCase() ?? 'N/A'}', 
                          style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold)),
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
                 labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
                child: const Text('LINK INSTANTLY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildQRScanner() {
    return Column(
      children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _currentStep = 0)),
          const Text('QR PROFILE SCAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1))
        ]),
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
                      final data = jsonDecode(utf8.decode(base64Decode(rawValue)));
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
          child: Text('Scan the QR code from their mobile profile to link. System synchronization is instant.', 
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }
}
