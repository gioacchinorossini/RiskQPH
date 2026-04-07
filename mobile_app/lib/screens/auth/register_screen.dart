import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _addressController = TextEditingController();

  List<String> _barangays = [];
  String? _selectedBarangay;
  bool _loadingBarangays = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadBarangays();
  }

  Future<void> _loadBarangays() async {
    setState(() {
      _loadingBarangays = true;
    });
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/barangay/list');
      final response = await http.get(
        uri,
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['barangays'] as List<dynamic>?) ?? [];
        setState(() {
          _barangays = list.map((e) => e.toString()).toList();
          _loadingBarangays = false;
        });
      } else {
        setState(() {
          _loadingBarangays = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadingBarangays = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.black45,
                          size: 20,
                        ),
                      ),
                      const Text(
                        'BACK TO LOGIN',
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Join your community’s disaster response network.',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 48),

                  // Registration Card
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTextField(
                            controller: _firstNameController,
                            label: 'First Name',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _lastNameController,
                            label: 'Last Name',
                            icon: Icons.badge_outlined,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _addressController,
                            label: 'Home Address',
                            icon: Icons.home_outlined,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 20),

                          // Barangay Picker
                          const Text(
                            'BARANGAY',
                            style: TextStyle(
                              color: Colors.black45,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildBarangayDropdown(),

                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 24),

                          _buildTextField(
                            controller: _emailController,
                            label: 'Account Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Account Password',
                            icon: Icons.lock_outline,
                            isPassword: true,
                          ),

                          const SizedBox(height: 32),

                          Consumer<AuthProvider>(
                            builder: (context, auth, _) => ElevatedButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                elevation: 0,
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'REGISTER ACCOUNT',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        fontSize: 12,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildErrorDisplay(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && _obscurePassword,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            hintText: 'Enter $label',
            hintStyle: TextStyle(
              color: Colors.black.withOpacity(0.3),
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: Colors.black45, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.black45,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red.shade200),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
            ),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildBarangayDropdown() {
    return InkWell(
      onTap: _loadingBarangays ? null : _showBarangayPicker,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_city_outlined, color: Colors.black45, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedBarangay ?? 'Select Barangay',
                style: TextStyle(
                  color: _selectedBarangay != null ? Colors.black : Colors.black38,
                  fontSize: 14,
                  fontWeight: _selectedBarangay != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            if (_loadingBarangays)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              )
            else
              const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.black45,
              ),
          ],
        ),
      ),
    );
  }

  void _showBarangayPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'SELECT BARANGAY',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _barangays.length,
                itemBuilder: (context, index) {
                  final b = _barangays[index];
                  final isSelected = _selectedBarangay == b;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      tileColor: isSelected ? AppTheme.primaryColor.withOpacity(0.05) : Colors.grey.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? AppTheme.primaryColor.withOpacity(0.2) : Colors.transparent,
                        ),
                      ),
                      title: Text(
                        b,
                        style: TextStyle(
                          color: isSelected ? AppTheme.primaryColor : const Color(0xFF1E293B),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 20) : null,
                      onTap: () {
                        setState(() => _selectedBarangay = b);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorDisplay() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.error != null) {
          return Text(
            auth.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Future<void> _handleRegister() async {
    if (_selectedBarangay == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a barangay')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      barangay: _selectedBarangay,
      address: _addressController.text.trim(),
      requestBarangayVerification: true,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Verification pending.')),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/user_dashboard',
        (route) => false,
      );
    }
  }
}
