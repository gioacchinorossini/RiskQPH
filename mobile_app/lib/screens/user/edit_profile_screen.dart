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
      
      // Using load() instead of loadString() to handle encoding issues gracefully
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
        if (parts.length >= 2) {
          level = parts[1].trim().toLowerCase();
        }
        
        if (level.contains('bgy')) {
          result.add(currentContext.isNotEmpty ? '$name, $currentContext' : name);
        } else {
          // If not a barangay, it's a context (City, Mun, Prov, etc.)
          if (!level.contains('reg')) {
            currentContext = name;
          }
        }
      }

      debugPrint('Successfully loaded ${result.length} barangays from CSV');

      setState(() {
        _allBarangays = result;
      });
    } catch (e) {
      debugPrint('Error loading barangays: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingBarangays = false);
      }
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
      setState(() {
        _selectedBirthdate = picked;
      });
    }
  }

  void _showBarangayPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BarangayPicker(
        barangays: _allBarangays,
        onSelected: (val) {
          setState(() {
            _selectedBarangay = val;
          });
        },
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Update failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Aesthetic choice
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blueAccent,
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
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: Colors.grey[600], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedBarangay ?? (_loadingBarangays ? 'Loading list...' : 'Select your barangay'),
                              style: TextStyle(
                                color: _selectedBarangay == null ? Colors.grey[500] : Colors.black,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (_loadingBarangays) 
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildLabel('Gender'),
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    items: ['Male', 'Female', 'Other'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedGender = val),
                  ),

                  const SizedBox(height: 16),
                  _buildLabel('Birthdate'),
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, color: Colors.grey[600], size: 20),
                          const SizedBox(width: 12),
                          Text(
                            _selectedBirthdate == null 
                              ? 'Select birthdate' 
                              : '${_selectedBirthdate!.year}-${_selectedBirthdate!.month.toString().padLeft(2, '0')}-${_selectedBirthdate!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: _selectedBirthdate == null ? Colors.grey[500] : Colors.black,
                              fontSize: 16,
                            ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: auth.isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool isOptional = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      validator: (value) {
        if (!isOptional && (value == null || value.isEmpty)) {
          return 'This field is required';
        }
        return null;
      },
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
    debugPrint('Picker received ${widget.barangays.length} barangays');
    _filtered = widget.barangays;
  }

  void _onSearch(String val) {
    setState(() {
      _filtered = widget.barangays
          .where((b) => b.toLowerCase().contains(val.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
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
            const SizedBox(height: 16),
            const Text('Select Barangay', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                  suffixIcon: _searchController.text.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear), 
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        }
                      ) 
                    : null,
                  hintText: 'Search barangay or city...',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_filtered.length < widget.barangays.length)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Showing ${_filtered.length} results', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No barangays found.\nTry a different search term.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : Scrollbar(
                      thickness: 6,
                      radius: const Radius.circular(10),
                      child: ListView.builder(
                        itemCount: _filtered.length,
                        padding: const EdgeInsets.only(bottom: 32),
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const Icon(Icons.location_on_outlined, size: 20, color: Colors.blueAccent),
                            title: Text(_filtered[index], style: const TextStyle(fontSize: 16)),
                            onTap: () {
                              widget.onSelected(_filtered[index]);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
