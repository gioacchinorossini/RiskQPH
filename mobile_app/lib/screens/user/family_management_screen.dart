import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../providers/auth_provider.dart';
import '../../config/api_config.dart';
import '../../models/family_member.dart';
import '../../utils/theme.dart';

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

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/family?headId=${user.id}'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> membersJson = data['members'] as List;
        setState(() {
          _members = membersJson.map((m) => FamilyMember.fromJson(m)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load family members';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Family Members'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                            final member = _members[index];
                            return _buildMemberCard(member);
                          },
                        ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Family'),
        backgroundColor: AppTheme.primaryColor,
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
            'No family members added yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your household members to keep track of them during emergencies.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(FamilyMember member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          child: Icon(
            member.relationship.toLowerCase().contains('spouse')
                ? Icons.favorite
                : member.relationship.toLowerCase().contains('child')
                    ? Icons.child_care
                    : Icons.person,
            color: AppTheme.primaryColor,
          ),
        ),
        title: Text(
          member.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${member.relationship} \u2022 ${member.gender ?? 'N/A'}'),
            if (member.medicalNotes != null && member.medicalNotes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                   const Icon(Icons.medical_services, size: 12, color: Colors.redAccent),
                   const SizedBox(width: 4),
                   Expanded(
                     child: Text(
                        member.medicalNotes!,
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                        overflow: TextOverflow.ellipsis,
                     ),
                   ),
                ],
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.grey),
          onPressed: () => _confirmDelete(member),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Are you sure you want to remove ${member.firstName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
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
  bool _isManual = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // Manual Fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _medicalNotesController = TextEditingController();
  String? _gender = 'Male';

  // Search Fields
  final _searchController = TextEditingController();
  Map<String, dynamic>? _foundUser;

  Future<void> _searchUser() async {
    if (_searchController.text.isEmpty) return;
    setState(() { _isLoading = true; _foundUser = null; });
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/search_user?id=${_searchController.text}'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() { _foundUser = data['user']; _isLoading = false; });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found')));
        setState(() { _isLoading = false; });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _submit() async {
    if (_isManual && !_formKey.currentState!.validate()) return;
    if (!_isManual && _foundUser == null) return;

    setState(() { _isLoading = true; });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final head = auth.currentUser;
    if (head == null) return;

    try {
      final body = {
        'headId': head.id,
        'firstName': _isManual ? _firstNameController.text : _foundUser!['firstName'],
        'lastName': _isManual ? _lastNameController.text : _foundUser!['lastName'],
        'relationship': _relationshipController.text.isEmpty ? 'Member' : _relationshipController.text,
        'gender': _isManual ? _gender : _foundUser!['gender'],
        'medicalNotes': _medicalNotesController.text,
        'userId': _isManual ? null : _foundUser!['id'],
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
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add member')));
        setState(() { _isLoading = false; });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Add Family Member', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Manual Info'), icon: Icon(Icons.edit)),
                  ButtonSegment(value: false, label: Text('Linked User'), icon: Icon(Icons.person_search)),
                ],
                selected: {_isManual},
                onSelectionChanged: (set) => setState(() => _isManual = set.first),
                style: SegmentedButton.styleFrom(
                   selectedBackgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                   selectedForegroundColor: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              if (_isManual) _buildManualForm() else _buildSearchForm(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isManual ? 'Add Member' : 'Link Family member', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(_firstNameController, 'First Name', Icons.person_outline),
          const SizedBox(height: 16),
          _buildTextField(_lastNameController, 'Last Name', Icons.person_outline),
          const SizedBox(height: 16),
          _buildTextField(_relationshipController, 'Relationship (e.g. Spouse, Son)', Icons.favorite_border),
          const SizedBox(height: 16),
          _buildTextField(_medicalNotesController, 'Medical Notes / Allergies', Icons.medical_services_outlined, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildSearchForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(_searchController, 'Enter User ID or email', Icons.search),
            ),
            const SizedBox(width: 8),
            Container(
              height: 56,
              child: IconButton.filled(
                onPressed: _isLoading ? null : _searchUser,
                style: IconButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ],
        ),
        if (_foundUser != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.done, color: Colors.white)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_foundUser!['firstName']} ${_foundUser!['lastName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Barangay: ${_foundUser!['barangay'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(_relationshipController, 'Relationship', Icons.favorite_border),
        ],
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
    );
  }
}
