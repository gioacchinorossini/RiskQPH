import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _studentIdController = TextEditingController();
  String? _selectedYearLevel;
  String? _selectedDepartment;
  String? _selectedCourse;
  String? _selectedGender;
  DateTime? _selectedBirthdate;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  static final _studentIdFormatter = _StudentIdTextInputFormatter();

  final List<String> _yearLevels = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
    'Graduate',
  ];

  final List<String> _departments = [
    'BED',
    'CASE',
    'CABECS',
    'COE',
    'CHAP',
  ];

  final Map<String, String> _courses = {
    'BSA': 'Bachelor of Science in Accountancy',
    'BSAIS': 'Bachelor of Science in Accounting Information System',
    'BSBA-MM': 'Bachelor of Science in Business Administration – Marketing Management',
    'BSIT': 'Bachelor of Science in Information Technology',
    'BSTMG': 'Bachelor of Science in Tourism Management',
    'BSHM': 'Bachelor of Science in Hospitality Management',
    'BSPsych': 'Bachelor of Science in Psychology',
    'BEEd': 'Bachelor of Elementary Education (General Education)',
    'BSEd': 'Bachelor of Secondary Education (English, Math, Filipino)',
    'BCAEd': 'Bachelor of Culture and Arts Education',
    'BPEd': 'Bachelor of Physical Education',
    'TCP': 'Teacher Certificate Program',
    'BSCE': 'Bachelor of Science in Civil Engineering',
    'BSCHE': 'Bachelor of Science in Chemical Engineering',
    'BSME': 'Bachelor of Science in Mechanical Engineering',
    'BSN': 'Bachelor of Science in Nursing',
    'BSMT': 'Bachelor of Science in Medical Technology',
    'BSP': 'Bachelor of Science in Pharmacy',
  };


  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Icon(
                  Icons.person_add,
                  size: 60,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                
                Text(
                  'Sign up',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                Text(
                  'Fill in your details below to create your account',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                    hintText: 'Enter your full name',
                  ),
                  inputFormatters: [
                    // Allow letters, spaces, hyphens, apostrophes, and periods only
                    FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z .\-']")),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    final trimmed = value.trim();
                    if (trimmed.length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    if (!RegExp(r"^[A-Za-z][A-Za-z .\-']*[A-Za-z]$").hasMatch(trimmed)) {
                      return 'Use letters, spaces, - . \' only';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    hintText: 'Enter your email',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    final trimmed = value.trim();
                    if (!trimmed.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    final domainOk = RegExp(r'@csab\.edu\.ph$', caseSensitive: false).hasMatch(trimmed);
                    if (!domainOk) {
                      return 'Use your @csab.edu.ph email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Student ID Field
                TextFormField(
                  controller: _studentIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Student ID',
                    prefixIcon: Icon(Icons.badge),
                    hintText: 'NN-NNNN-NNN',
                  ),
                  maxLength: 11,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _studentIdFormatter,
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your student ID';
                    }
                    final trimmed = value.trim();
                    final pattern = RegExp(r'^\d{2}-\d{4}-\d{3}$');
                    if (!pattern.hasMatch(trimmed)) {
                      return 'Use format NN-NNNN-NNN (numbers only)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Year Level Field (Dropdown)
                DropdownButtonFormField<String>(
                  value: _selectedYearLevel,
                  items: _yearLevels
                      .map((level) => DropdownMenuItem(
                            value: level,
                            child: Text(level),
                          ))
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Year Level',
                    prefixIcon: Icon(Icons.school),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _selectedYearLevel = val;
                    });
                  },
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please select your year level';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Department Field (Dropdown)
                DropdownButtonFormField<String>(
                  value: _selectedDepartment,
                  items: _departments
                      .map((dept) => DropdownMenuItem(
                            value: dept,
                            child: Text(dept),
                          ))
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    prefixIcon: Icon(Icons.business),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _selectedDepartment = val;
                    });
                  },
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please select your department';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Course Field (Dropdown)
                DropdownButtonFormField<String>(
                  value: _selectedCourse,
                  items: _courses.entries
                      .map((entry) => DropdownMenuItem(
                            value: entry.key,
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                '${entry.key} - ${entry.value}',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ))
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Course',
                    prefixIcon: Icon(Icons.school),
                  ),
                  isExpanded: true,
                  onChanged: (val) {
                    setState(() {
                      _selectedCourse = val;
                    });
                  },
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please select your course';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Gender Field
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _selectedGender = val;
                    });
                  },
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please select your gender';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Birthdate Field
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final initial = _selectedBirthdate ?? DateTime(now.year - 18, now.month, now.day);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(1900, 1, 1),
                      lastDate: now,
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedBirthdate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Birthdate',
                      prefixIcon: Icon(Icons.cake),
                    ),
                    child: Text(
                      _selectedBirthdate != null
                          ? '${_selectedBirthdate!.year.toString().padLeft(4, '0')}-${_selectedBirthdate!.month.toString().padLeft(2, '0')}-${_selectedBirthdate!.day.toString().padLeft(2, '0')}'
                          : 'Select your birthdate',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _selectedBirthdate == null ? Colors.grey[600] : null,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  keyboardType: TextInputType.visiblePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    hintText: 'Enter your password',
                  ),
                  inputFormatters: [
                    // Prevent whitespace in passwords
                    FilteringTextInputFormatter.deny(RegExp(r"\s")),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    // Require at least one letter and one number
                    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
                    final hasDigit = RegExp(r'\d').hasMatch(value);
                    if (!(hasLetter && hasDigit)) {
                      return 'Include at least one letter and one number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  keyboardType: TextInputType.visiblePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    hintText: 'Confirm your password',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r"\s")),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Register Button
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return ElevatedButton(
                      onPressed: authProvider.isLoading ? null : _handleRegister,
                      child: authProvider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Create Account'),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Error Message
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    if (authProvider.error != null) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.errorColor),
                        ),
                        child: Text(
                          authProvider.error!,
                          style: TextStyle(color: AppTheme.errorColor),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 24),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (_selectedBirthdate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your birthdate')),
        );
        return;
      }
      if (_selectedGender == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your gender')),
        );
        return;
      }
      if (_selectedYearLevel == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your year level')),
        );
        return;
      }
      if (_selectedDepartment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your department')),
        );
        return;
      }
      if (_selectedCourse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your course')),
        );
        return;
      }
      final success = await authProvider.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _studentIdController.text.trim(),
        yearLevel: _selectedYearLevel!,
        department: _selectedDepartment!,
        course: _selectedCourse!,
        gender: _selectedGender!,
        birthdate: '${_selectedBirthdate!.year.toString().padLeft(4, '0')}-${_selectedBirthdate!.month.toString().padLeft(2, '0')}-${_selectedBirthdate!.day.toString().padLeft(2, '0')}',
      );

      if (success && mounted) {
        Navigator.pushReplacementNamed(context, '/student_dashboard');
      }
    }
  }
} 

class _StudentIdTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Keep only digits from the new input
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Limit to 9 digits (2 + 4 + 3)
    final limited = digitsOnly.length > 9 ? digitsOnly.substring(0, 9) : digitsOnly;

    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i == 2 || i == 6) {
        sb.write('-');
      }
      sb.write(limited[i]);
    }

    final formatted = sb.toString();

    // Calculate the cursor position
    int selectionIndex = formatted.length;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}