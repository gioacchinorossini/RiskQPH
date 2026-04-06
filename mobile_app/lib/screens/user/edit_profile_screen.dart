import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _addressController;
  String? _selectedGender;
  String? _selectedBarangay;
  DateTime? _selectedBirthdate;

  List<String> _allBarangays = [];
  bool _loadingBarangays = true;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _firstNameController = TextEditingController(text: user?.firstName);
    _lastNameController = TextEditingController(text: user?.lastName);
    _middleNameController = TextEditingController(text: user?.middleName);
    _addressController = TextEditingController(text: user?.address);
    _selectedGender = user?.gender;
    _selectedBarangay = user?.barangay;
    _selectedBirthdate = user?.birthdate;
    _loadBarangays();
  }

  Future<void> _loadBarangays() async {
    try {
      setState(() => _loadingBarangays = true);
      final ByteData data = await rootBundle.load('assets/barangay.csv');
      final List<int> bytes = data.buffer.asUint8List();
      final String decoded = utf8.decode(bytes, allowMalformed: true);
      final List<String> lines = decoded.split(RegExp(r'\r?\n'));
      final List<String> result = [];
      String currentContext = ''; 
      for (var line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;
        final parts = trimmedLine.split(',');
        final name = parts[0].trim();
        if (name.isEmpty || name.toLowerCase() == 'name') continue;
        String level = '';
        if (parts.length >= 2) level = parts[1].trim().toLowerCase();
        if (level.contains('bgy')) {
          result.add(currentContext.isNotEmpty ? '$name, $currentContext' : name);
        } else if (!level.contains('reg')) {
          currentContext = name;
        }
      }
      setState(() => _allBarangays = result);
    } catch (e) {
      debugPrint('Error loading barangays: $e');
    } finally {
      if (mounted) setState(() => _loadingBarangays = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthdate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthdate) {
      setState(() => _selectedBirthdate = picked);
    }
  }

  void _showBarangayPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BarangayPicker(
        barangays: _allBarangays,
        onSelected: (val) => setState(() => _selectedBarangay = val),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      middleName: _middleNameController.text.isEmpty ? null : _middleNameController.text,
      birthdate: _selectedBirthdate?.toIso8601String().substring(0, 10),
      gender: _selectedGender,
      barangay: _selectedBarangay,
      address: _addressController.text.isEmpty ? null : _addressController.text,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Update failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(24.0),
            sliver: SliverToBoxAdapter(
              child: Consumer<AuthProvider>(
                builder: (context, auth, child) {
                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Color(0xFF1565C0),
                            child: Icon(Icons.person, size: 50, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildLabel('First Name'),
                        _buildTextField(_firstNameController, 'Enter your first name'),
                        const SizedBox(height: 16),
                        _buildLabel('Last Name'),
                        _buildTextField(_lastNameController, 'Enter your last name'),
                        const SizedBox(height: 16),
                        _buildLabel('Middle Name (Optional)'),
                        _buildTextField(_middleNameController, 'Enter your middle name', isOptional: true),
                        const SizedBox(height: 16),
                        _buildLabel('Barangay'),
                        GestureDetector(
                          onTap: _loadingBarangays ? null : _showBarangayPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                            child: Row(
                              children: [
                                Icon(Icons.location_on_outlined, color: Colors.grey[600], size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedBarangay ?? (_loadingBarangays ? 'Loading list...' : 'Select your barangay'),
                                    style: TextStyle(color: _selectedBarangay == null ? Colors.grey[500] : Colors.black, fontSize: 16),
                                  ),
                                ),
                                if (_loadingBarangays) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                else const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Gender'),
                        DropdownButtonFormField<String>(
                          value: _selectedGender,
                          decoration: InputDecoration(
                            filled: true, fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                          ),
                          items: ['Male', 'Female', 'Other'].map((String value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                          onChanged: (val) => setState(() => _selectedGender = val),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Birthdate'),
                        GestureDetector(
                          onTap: () => _selectDate(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_outlined, color: Colors.grey[600], size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedBirthdate == null 
                                    ? 'Select birthdate' 
                                    : '${_selectedBirthdate!.year}-${_selectedBirthdate!.month.toString().padLeft(2, '0')}-${_selectedBirthdate!.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(color: _selectedBirthdate == null ? Colors.grey[500] : Colors.black, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Specific Address (Optional)'),
                        _buildTextField(_addressController, 'e.g. Street, House No.', isOptional: true, maxLines: 2),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                            child: auth.isLoading 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('SAVE PROFILE CHANGES', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false, pinned: true,
      backgroundColor: const Color(0xFF0D47A1),
      elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(right: -20, bottom: -20, child: Icon(Icons.person_outline_rounded, size: 200, color: Colors.white.withOpacity(0.08))),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('IDENTIFICATION', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text('PERSONAL DATA MANAGEMENT', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 8.0, left: 4), child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)));
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool isOptional = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller, maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint, filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      ),
      validator: (value) => (!isOptional && (value == null || value.isEmpty)) ? 'Required' : null,
    );
  }
}

class _BarangayPicker extends StatefulWidget {
  final List<String> barangays;
  final Function(String) onSelected;
  const _BarangayPicker({required this.barangays, required this.onSelected});
  @override
  State<_BarangayPicker> createState() => _BarangayPickerState();
}

class _BarangayPickerState extends State<_BarangayPicker> {
  late List<String> _filtered;
  final _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _filtered = widget.barangays;
  }
  void _onSearch(String val) {
    setState(() => _filtered = widget.barangays.where((b) => b.toLowerCase().contains(val.toLowerCase())).toList());
  }
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('SELECT BARANGAY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1), letterSpacing: 0.5)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController, onChanged: _onSearch, autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF0D47A1)),
                  hintText: 'Search localization...', filled: true, fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Scrollbar(
                thickness: 6, radius: const Radius.circular(10),
                child: ListView.builder(
                  itemCount: _filtered.length, padding: const EdgeInsets.only(bottom: 32),
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF0D47A1)),
                    title: Text(_filtered[index], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    onTap: () { widget.onSelected(_filtered[index]); Navigator.pop(context); },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
