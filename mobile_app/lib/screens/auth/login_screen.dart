import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // QUICK LOGIN FOR DEV
  final List<Map<String, String>> _quickLogins = [
    {
      'label': 'Resident (Juan)',
      'email': 'resident@test.com',
      'pass': 'gwapoko4321',
    },
    {
      'label': 'Barangay Head (Admin)',
      'email': 'head@test.com',
      'pass': 'gwapoko4321',
    },
    {
      'label': 'Emergency Responder',
      'email': 'responder@test.com',
      'pass': 'gwapoko4321',
    },
    {
      'label': 'Longnoxian 4 (HEAD)',
      'email': 'longnoxian4@gmail.com',
      'pass': 'gwapoko4321',
    },
    {
      'label': 'Longnoxian 5 (RESIDENT)',
      'email': 'longnoxian5@gmail.com',
      'pass': 'gwapoko4321',
    },
    {
      'label': 'Longnoxian 6 (RESPONDER)',
      'email': 'longnoxian6@gmail.com',
      'pass': 'gwapoko4321',
    },
    {
      'label': 'Longnoxian 7 (RESIDENT)',
      'email': 'longnoxian7@gmail.com',
      'pass': 'gwapoko4321',
    },
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'RiskQPH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.secondaryColor,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 56,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sign in',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Use the account your barangay recognizes.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                    ),
                    const SizedBox(height: 24),
                    Material(
                      elevation: 1,
                      borderRadius: BorderRadius.circular(16),
                      color: Theme.of(context).colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.warningColor.withOpacity(0.35),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Map<String, String>>(
                                  hint: const Text('Quick dev login'),
                                  isExpanded: true,
                                  icon: Icon(
                                    Icons.bolt,
                                    color: AppTheme.warningColor,
                                  ),
                                  items: _quickLogins.map((login) {
                                    return DropdownMenuItem(
                                      value: login,
                                      child: Text(
                                        login['label']!,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _emailController.text = val['email']!;
                                        _passwordController.text = val['pass']!;
                                      });
                                      _handleLogin();
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter your email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter your password';
                                }
                                if (value.length < 6) {
                                  return 'At least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            Consumer<AuthProvider>(
                              builder: (context, authProvider, child) {
                                return FilledButton(
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : _handleLogin,
                                  child: authProvider.isLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Sign in'),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Consumer<AuthProvider>(
                              builder: (context, authProvider, child) {
                                if (authProvider.error != null) {
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.errorColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppTheme.errorColor.withOpacity(0.4),
                                      ),
                                    ),
                                    child: Text(
                                      authProvider.error!,
                                      style: const TextStyle(
                                        color: AppTheme.errorColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'New resident? ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          child: const Text('Create account'),
                        ),
                      ],
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

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        final user = authProvider.currentUser;
        if (user != null) {
          final role = user.role.toString();
          if (role.contains('barangay_head')) {
            Navigator.pushNamedAndRemoveUntil(context, '/barangay_head_dashboard', (route) => false);
          } else if (role.contains('responder')) {
            Navigator.pushNamedAndRemoveUntil(context, '/responder_dashboard', (route) => false);
          } else {
            Navigator.pushNamedAndRemoveUntil(context, '/user_dashboard', (route) => false);
          }
        }
      }
    }
  }
}
